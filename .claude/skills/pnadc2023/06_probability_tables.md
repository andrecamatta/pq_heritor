# Metodologia para Tabelas de Probabilidade - PNADC 2023

## Visão Geral

Tabelas de probabilidade são cruciais para modelos demográficos. Esta skill ensina como gerar tabelas segregadas por **idade** e **sexo** usando pesos amostrais do PNADC 2023.

## Tipos de Tabelas

### 1. Tabela de Conjugalidade
**P(tem_cônjuge | idade, sexo)**

### 2. Tabela de Fertilidade
**P(tem_filho | idade, sexo)**

### 3. Tabela de Age Gap
**E[idade_cônjuge - idade_responsável | idade, sexo]**

### 4. Tabela de Idade do Filho Mais Novo
**E[idade_filho_mais_novo | idade_responsável, sexo]**

## Princípios Fundamentais

### Uso de Pesos Amostrais

**SEMPRE usar V1032** (peso com calibração Censo 2022):

```julia
# ✓ Correto: usar peso
n_com_conjuge_ponderado = sum(p.peso for p in pessoas if tem_conjuge(p))
n_total_ponderado = sum(p.peso for p in pessoas)
prob = n_com_conjuge_ponderado / n_total_ponderado

# ✗ Errado: contar pessoas sem peso
n_com_conjuge = count(p -> tem_conjuge(p), pessoas)
prob = n_com_conjuge / length(pessoas)  # ERRADO!
```

### Segregação por Idade e Sexo

```julia
# Estrutura básica
contadores = Dict{Tuple{Int, Int}, Tuple{Float64, Float64}}()
# (idade, sexo) => (n_evento, n_total)

for p in pessoas
    key = (p.idade, p.sexo)
    evento_ocorreu = avalia_evento(p)

    if haskey(contadores, key)
        n_evento, n_total = contadores[key]
        contadores[key] = (
            n_evento + (evento_ocorreu ? p.peso : 0.0),
            n_total + p.peso
        )
    else
        contadores[key] = (
            evento_ocorreu ? p.peso : 0.0,
            p.peso
        )
    end
end

# Calcular probabilidades
for ((idade, sexo), (n_evento, n_total)) in contadores
    prob = n_evento / n_total
    # Armazenar...
end
```

## Tabela 1: Conjugalidade

### Metodologia

**Evento**: Pessoa está em união (V2005 = 02 ou 03)
**População**: Todos (com filtro de domicílio único responsável)

```julia
function tabela_conjugalidade(pessoas::Vector{Pessoa})
    using DataFrames

    # 1. Filtrar domicílios com único responsável
    resp_por_dom = Dict{String, Int}()
    for p in pessoas
        if p.condicao_dom == 1
            resp_por_dom[p.domicilio_id] = get(resp_por_dom, p.domicilio_id, 0) + 1
        end
    end

    dominios_validos = Set(k for (k, v) in resp_por_dom if v == 1)
    pessoas_filtradas = filter(p -> p.domicilio_id ∈ dominios_validos, pessoas)

    # 2. Acumular contadores ponderados
    contadores = Dict{Tuple{Int, Int}, Tuple{Float64, Float64}}()

    for p in pessoas_filtradas
        key = (p.idade, p.sexo)
        em_uniao = (p.condicao_dom in [2, 3])  # É cônjuge

        if haskey(contadores, key)
            n_conj, n_tot = contadores[key]
            contadores[key] = (
                n_conj + (em_uniao ? p.peso : 0.0),
                n_tot + p.peso
            )
        else
            contadores[key] = (
                em_uniao ? p.peso : 0.0,
                p.peso
            )
        end
    end

    # 3. Criar DataFrame
    df = DataFrame(
        idade = Int[],
        mulher = Union{Float64, Missing}[],
        homem = Union{Float64, Missing}[],
        n_mulher = Union{Float64, Missing}[],
        n_homem = Union{Float64, Missing}[]
    )

    # Listar todas as idades observadas
    idades = sort(unique([k[1] for k in keys(contadores)]))

    for idade in idades
        # Mulheres (sexo=2)
        key_f = (idade, 2)
        prob_f = missing
        n_f = missing
        if haskey(contadores, key_f)
            n_conj, n_tot = contadores[key_f]
            prob_f = n_conj / n_tot
            n_f = n_tot
        end

        # Homens (sexo=1)
        key_m = (idade, 1)
        prob_m = missing
        n_m = missing
        if haskey(contadores, key_m)
            n_conj, n_tot = contadores[key_m]
            prob_m = n_conj / n_tot
            n_m = n_tot
        end

        push!(df, (idade, prob_f, prob_m, n_f, n_m))
    end

    return df
end
```

### Formato de Output

```csv
idade,mulher,homem,n_mulher,n_homem
18,0.023,0.015,123456.7,118234.5
19,0.034,0.019,125678.3,120123.8
20,0.048,0.027,127890.1,122345.9
...
```

**Colunas:**
- `idade`: Idade em anos
- `mulher`: P(tem_cônjuge | idade, sexo=F)
- `homem`: P(tem_cônjuge | idade, sexo=M)
- `n_mulher`: População ponderada de mulheres nesta idade
- `n_homem`: População ponderada de homens nesta idade

## Tabela 2: Fertilidade (Probabilidade de Ter Filho)

### Metodologia

**Evento**: Responsável/cônjuge tem pelo menos um filho no domicílio
**População**: Responsáveis e cônjuges

```julia
function tabela_fertilidade(pessoas::Vector{Pessoa})
    using DataFrames

    # 1. Identificar filhos por domicílio
    filhos_por_dom = Dict{String, Vector{Pessoa}}()
    for p in pessoas
        if p.condicao_dom in [4, 5, 6]  # Filho
            if !haskey(filhos_por_dom, p.domicilio_id)
                filhos_por_dom[p.domicilio_id] = Pessoa[]
            end
            push!(filhos_por_dom[p.domicilio_id], p)
        end
    end

    # 2. Acumular para responsáveis e cônjuges
    contadores = Dict{Tuple{Int, Int}, Tuple{Float64, Float64}}()

    for p in pessoas
        # Apenas responsáveis (01) e cônjuges (02, 03)
        if p.condicao_dom in [1, 2, 3]
            key = (p.idade, p.sexo)
            tem_filho = haskey(filhos_por_dom, p.domicilio_id) &&
                       !isempty(filhos_por_dom[p.domicilio_id])

            if haskey(contadores, key)
                n_com, n_tot = contadores[key]
                contadores[key] = (
                    n_com + (tem_filho ? p.peso : 0.0),
                    n_tot + p.peso
                )
            else
                contadores[key] = (
                    tem_filho ? p.peso : 0.0,
                    p.peso
                )
            end
        end
    end

    # 3. Criar DataFrame
    df = DataFrame(
        idade = Int[],
        mulher = Union{Float64, Missing}[],
        homem = Union{Float64, Missing}[]
    )

    idades = sort(unique([k[1] for k in keys(contadores)]))

    for idade in idades
        prob_f = missing
        if haskey(contadores, (idade, 2))
            n_com, n_tot = contadores[(idade, 2)]
            prob_f = n_com / n_tot
        end

        prob_m = missing
        if haskey(contadores, (idade, 1))
            n_com, n_tot = contadores[(idade, 1)]
            prob_m = n_com / n_tot
        end

        push!(df, (idade, prob_f, prob_m))
    end

    return df
end
```

## Tabela 3: Age Gap (Diferença de Idade entre Cônjuges)

### Metodologia

**Métrica**: idade_responsável - idade_cônjuge (média ponderada)
**População**: Casais (responsável + cônjuge no mesmo domicílio)

```julia
function tabela_age_gap(pessoas::Vector{Pessoa})
    using DataFrames, Statistics

    # 1. Identificar casais
    dominios = Dict{String, Vector{Pessoa}}()
    for p in pessoas
        if !haskey(dominios, p.domicilio_id)
            dominios[p.domicilio_id] = Pessoa[]
        end
        push!(dominios[p.domicilio_id], p)
    end

    casais = []
    for (dom_id, membros) in dominios
        resp_idx = findfirst(p -> p.condicao_dom == 1, membros)
        conj_idx = findfirst(p -> p.condicao_dom in [2, 3], membros)

        if resp_idx !== nothing && conj_idx !== nothing
            resp = membros[resp_idx]
            conj = membros[conj_idx]
            age_gap = resp.idade - conj.idade
            push!(casais, (resp.idade, resp.sexo, age_gap, resp.peso))
        end
    end

    # 2. Agregar por (idade_resp, sexo_resp)
    contadores = Dict{Tuple{Int, Int}, Vector{Tuple{Float64, Float64}}}()
    # (idade, sexo) => [(age_gap, peso), ...]

    for (idade, sexo, gap, peso) in casais
        key = (idade, sexo)
        if !haskey(contadores, key)
            contadores[key] = []
        end
        push!(contadores[key], (gap, peso))
    end

    # 3. Calcular média ponderada
    df = DataFrame(
        idade = Int[],
        sexo = Int[],
        age_gap_medio = Float64[],
        n_casais = Int[]
    )

    for ((idade, sexo), gaps_pesos) in contadores
        # Média ponderada
        soma_ponderada = sum(gap * peso for (gap, peso) in gaps_pesos)
        soma_pesos = sum(peso for (gap, peso) in gaps_pesos)
        media = soma_ponderada / soma_pesos

        push!(df, (idade, sexo, media, length(gaps_pesos)))
    end

    return df
end
```

### Formato de Output

```csv
idade,sexo,age_gap_medio,n_casais
20,1,2.3,1234
20,2,-1.5,1456
21,1,2.5,1345
...
```

**Interpretação:**
- `age_gap_medio > 0`: Responsável mais velho que cônjuge
- `age_gap_medio < 0`: Responsável mais jovem que cônjuge
- Por convenção: homens geralmente têm gap positivo, mulheres gap negativo

## Tabela 4: Idade do Filho Mais Novo

### Metodologia

**Métrica**: min(idades_filhos) (média ponderada por idade do responsável)
**População**: Responsáveis com pelo menos um filho

```julia
function tabela_idade_filho_mais_novo(pessoas::Vector{Pessoa})
    using DataFrames, Statistics

    # 1. Identificar filhos por domicílio
    filhos_por_dom = Dict{String, Vector{Pessoa}}()
    for p in pessoas
        if p.condicao_dom in [4, 5, 6]
            if !haskey(filhos_por_dom, p.domicilio_id)
                filhos_por_dom[p.domicilio_id] = Pessoa[]
            end
            push!(filhos_por_dom[p.domicilio_id], p)
        end
    end

    # 2. Para cada responsável, calcular idade do filho mais novo
    dados = []
    for p in pessoas
        if p.condicao_dom == 1  # Responsável
            if haskey(filhos_por_dom, p.domicilio_id) &&
               !isempty(filhos_por_dom[p.domicilio_id])

                idade_min = minimum(f.idade for f in filhos_por_dom[p.domicilio_id])
                push!(dados, (p.idade, p.sexo, idade_min, p.peso))
            end
        end
    end

    # 3. Agregar por (idade_resp, sexo_resp)
    contadores = Dict{Tuple{Int, Int}, Vector{Tuple{Float64, Float64}}}()

    for (idade, sexo, idade_filho, peso) in dados
        key = (idade, sexo)
        if !haskey(contadores, key)
            contadores[key] = []
        end
        push!(contadores[key], (idade_filho, peso))
    end

    # 4. Calcular média ponderada
    df = DataFrame(
        idade = Int[],
        mulher = Union{Float64, Missing}[],
        homem = Union{Float64, Missing}[]
    )

    idades = sort(unique([k[1] for k in keys(contadores)]))

    for idade in idades
        # Mulheres
        media_f = missing
        if haskey(contadores, (idade, 2))
            idades_pesos = contadores[(idade, 2)]
            soma_pond = sum(id * peso for (id, peso) in idades_pesos)
            soma_pesos = sum(peso for (id, peso) in idades_pesos)
            media_f = soma_pond / soma_pesos
        end

        # Homens
        media_m = missing
        if haskey(contadores, (idade, 1))
            idades_pesos = contadores[(idade, 1)]
            soma_pond = sum(id * peso for (id, peso) in idades_pesos)
            soma_pesos = sum(peso for (id, peso) in idades_pesos)
            media_m = soma_pond / soma_pesos
        end

        push!(df, (idade, media_f, media_m))
    end

    return df
end
```

## Pipeline Completo: Gerar Todas as Tabelas

```julia
using DataFrames, CSV

function gerar_todas_tabelas(pessoas::Vector{Pessoa}; output_dir="output/")
    mkpath(output_dir)

    println("="^70)
    println("GERANDO TABELAS DE PROBABILIDADE - PNADC 2023")
    println("="^70)

    # 1. Conjugalidade
    println("\n[1/4] Tabela de conjugalidade...")
    df_conj = tabela_conjugalidade(pessoas)
    CSV.write(joinpath(output_dir, "prob_conjugalidade_2023.csv"), df_conj)
    println("✓ Salva: prob_conjugalidade_2023.csv ($(nrow(df_conj)) linhas)")

    # 2. Fertilidade
    println("\n[2/4] Tabela de fertilidade...")
    df_fert = tabela_fertilidade(pessoas)
    CSV.write(joinpath(output_dir, "prob_fertilidade_2023.csv"), df_fert)
    println("✓ Salva: prob_fertilidade_2023.csv ($(nrow(df_fert)) linhas)")

    # 3. Age Gap
    println("\n[3/4] Tabela de age gap...")
    df_gap = tabela_age_gap(pessoas)
    CSV.write(joinpath(output_dir, "age_gap_medio_2023.csv"), df_gap)
    println("✓ Salva: age_gap_medio_2023.csv ($(nrow(df_gap)) linhas)")

    # 4. Idade do filho mais novo
    println("\n[4/4] Tabela de idade do filho mais novo...")
    df_filho = tabela_idade_filho_mais_novo(pessoas)
    CSV.write(joinpath(output_dir, "idade_filho_mais_novo_2023.csv"), df_filho)
    println("✓ Salva: idade_filho_mais_novo_2023.csv ($(nrow(df_filho)) linhas)")

    println("\n" * "="^70)
    println("✓ Todas as tabelas geradas com sucesso!")
    println("="^70)

    return (conj=df_conj, fert=df_fert, gap=df_gap, filho=df_filho)
end
```

## Validações Recomendadas

### 1. Verificar Soma de Pesos
```julia
# Peso total deve ser próximo da população brasileira
peso_total = sum(p.peso for p in pessoas)
println("Peso total: $(round(Int, peso_total)) pessoas")
# Esperado: ~203 milhões (população do Brasil em 2023)
```

### 2. Verificar Distribuição por Sexo
```julia
peso_f = sum(p.peso for p in filter(p -> p.sexo == 2, pessoas))
peso_m = sum(p.peso for p in filter(p -> p.sexo == 1, pessoas))
pct_f = peso_f / (peso_f + peso_m) * 100
println("Mulheres: $(round(pct_f, digits=1))%")
# Esperado: ~51-52% mulheres
```

### 3. Verificar Probabilidades Válidas
```julia
# Todas as probabilidades devem estar em [0, 1]
for row in eachrow(df_conjugalidade)
    if !ismissing(row.mulher) && (row.mulher < 0 || row.mulher > 1)
        println("⚠️  Probabilidade inválida: $(row)")
    end
end
```

## Tratamento de Missing

```julia
# Algumas idades podem não ter observações para um sexo
# Usar missing ao invés de 0

# Exemplo: interpolar valores missing (opcional)
using Interpolations

function interpolar_missing(df::DataFrame, col::Symbol)
    idades = df.idade
    valores = df[!, col]

    # Indices não-missing
    idx_validos = findall(!ismissing, valores)

    if length(idx_validos) < 2
        return valores  # Não dá pra interpolar
    end

    # Interpolar
    itp = LinearInterpolation(
        idades[idx_validos],
        Float64[valores[i] for i in idx_validos]
    )

    # Substituir missing
    valores_interp = copy(valores)
    for i in 1:length(valores)
        if ismissing(valores[i])
            idade = idades[i]
            if minimum(idades[idx_validos]) <= idade <= maximum(idades[idx_validos])
                valores_interp[i] = itp(idade)
            end
        end
    end

    return valores_interp
end
```

## Próximos Passos

Com as tabelas prontas:
1. **Análise de age gap**: [07_age_gap_analysis.md](07_age_gap_analysis.md)
2. **Integrar com modelos**: [08_integration_models.md](08_integration_models.md)
3. **Exemplos completos**: [09_examples.md](09_examples.md)
