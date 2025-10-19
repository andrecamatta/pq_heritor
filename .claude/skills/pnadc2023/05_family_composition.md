# Análise de Composição Familiar - PNADC 2023

## Visão Geral

A composição familiar no PNADC 2023 é identificada através da variável **V2005** (Condição no domicílio), que indica a relação de cada pessoa com o responsável do domicílio.

## Variável Principal: V2005

**Posição**: 92 (2 caracteres)
**Tipo**: String

### Códigos Completos

| Código | Significado | Categoria |
|--------|-------------|-----------|
| **01** | Pessoa responsável pelo domicílio | Responsável |
| **02** | Cônjuge ou companheiro(a) de sexo diferente | Cônjuge |
| **03** | Cônjuge ou companheiro(a) do mesmo sexo | Cônjuge |
| **04** | Filho(a) do responsável e do cônjuge | Filho |
| **05** | Filho(a) somente do responsável | Filho |
| **06** | Enteado(a) | Filho |
| **07** | Genro ou nora | Parente |
| **08** | Pai, mãe, padrasto ou madrasta | Parente |
| **09** | Sogro(a) | Parente |
| **10** | Neto(a) ou bisneto(a) | Parente |
| **11** | Irmão ou irmã | Parente |
| **12** | Avô ou avó | Parente |
| **13** | Outro parente | Parente |
| **14** | Agregado(a) | Não-parente |
| **15** | Convivente | Não-parente |
| **16** | Pensionista | Não-parente |
| **17** | Empregado(a) doméstico(a) | Não-parente |
| **18** | Parente do(a) empregado(a) doméstico(a) | Não-parente |

## Análises Principais

### 1. Identificar Quem Tem Cônjuge

#### Por Domicílio
```julia
function identificar_conjuges(pessoas::Vector{Pessoa})
    """
    Identifica responsáveis que têm cônjuge.
    Retorna dicionário: domicilio_id => (responsavel, conjuge)
    """
    casais = Dict{String, Tuple{Pessoa, Pessoa}}()

    # Agrupar por domicílio
    dominios = Dict{String, Vector{Pessoa}}()
    for p in pessoas
        if !haskey(dominios, p.domicilio_id)
            dominios[p.domicilio_id] = Pessoa[]
        end
        push!(dominios[p.domicilio_id], p)
    end

    # Identificar casais
    for (dom_id, membros) in dominios
        # Encontrar responsável
        resp = findfirst(p -> p.condicao_dom == 1, membros)
        if resp === nothing
            continue
        end

        # Encontrar cônjuge (V2005 = 02 ou 03)
        conj = findfirst(p -> p.condicao_dom in [2, 3], membros)
        if conj === nothing
            continue
        end

        casais[dom_id] = (membros[resp], membros[conj])
    end

    return casais
end
```

#### Por Indivíduo (Probabilidade)
```julia
function prob_ter_conjuge_por_idade_sexo(pessoas::Vector{Pessoa})
    """
    Calcula P(tem_conjuge | idade, sexo) usando pesos amostrais.
    """
    using DataFrames

    # Filtrar domicílios com único responsável
    resp_por_dom = Dict{String, Int}()
    for p in pessoas
        if p.condicao_dom == 1
            resp_por_dom[p.domicilio_id] = get(resp_por_dom, p.domicilio_id, 0) + 1
        end
    end

    dominios_validos = Set(k for (k, v) in resp_por_dom if v == 1)
    pessoas_filtradas = filter(p -> p.domicilio_id ∈ dominios_validos, pessoas)

    # Acumular contadores ponderados por (idade, sexo)
    contadores = Dict{Tuple{Int, Int}, Tuple{Float64, Float64}}()  # (idade, sexo) => (n_conjuges, n_total)

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

    # Converter para DataFrame
    result = DataFrame(
        idade = Int[],
        sexo = Int[],
        prob_conjuge = Float64[],
        n_ponderado = Float64[]
    )

    for ((idade, sexo), (n_conj, n_tot)) in contadores
        push!(result, (idade, sexo, n_conj / n_tot, n_tot))
    end

    return result
end
```

### 2. Identificar Filhos

#### Todos os Filhos por Domicílio
```julia
function identificar_filhos_por_domicilio(pessoas::Vector{Pessoa})
    """
    Identifica todos os filhos por domicílio.
    Retorna Dict: domicilio_id => [filhos...]
    """
    filhos_por_dom = Dict{String, Vector{Pessoa}}()

    for p in pessoas
        # V2005 = 04, 05 ou 06 (filho, filho somente do responsável, enteado)
        if p.condicao_dom in [4, 5, 6]
            if !haskey(filhos_por_dom, p.domicilio_id)
                filhos_por_dom[p.domicilio_id] = Pessoa[]
            end
            push!(filhos_por_dom[p.domicilio_id], p)
        end
    end

    return filhos_por_dom
end
```

#### Probabilidade de Ter Pelo Menos Um Filho
```julia
function prob_ter_filho_por_idade_sexo(pessoas::Vector{Pessoa})
    """
    Calcula P(tem >= 1 filho | idade, sexo).
    Considera apenas responsáveis e cônjuges como "pais potenciais".
    """
    using DataFrames

    # Identificar filhos por domicílio
    filhos_por_dom = identificar_filhos_por_domicilio(pessoas)

    # Acumular contadores para responsáveis e cônjuges
    contadores = Dict{Tuple{Int, Int}, Tuple{Float64, Float64}}()

    for p in pessoas
        # Apenas responsáveis (01) e cônjuges (02, 03)
        if p.condicao_dom in [1, 2, 3]
            key = (p.idade, p.sexo)
            tem_filho = haskey(filhos_por_dom, p.domicilio_id) &&
                       !isempty(filhos_por_dom[p.domicilio_id])

            if haskey(contadores, key)
                n_com_filho, n_tot = contadores[key]
                contadores[key] = (
                    n_com_filho + (tem_filho ? p.peso : 0.0),
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

    # Converter para DataFrame
    result = DataFrame(
        idade = Int[],
        sexo = Int[],
        prob_filho = Float64[],
        n_ponderado = Float64[]
    )

    for ((idade, sexo), (n_com, n_tot)) in contadores
        push!(result, (idade, sexo, n_com / n_tot, n_tot))
    end

    return result
end
```

### 3. Idade do Filho Mais Novo

```julia
function idade_filho_mais_novo_por_responsavel(pessoas::Vector{Pessoa})
    """
    Calcula a idade do filho mais novo para cada responsável.
    Retorna DataFrame com idade_resp, sexo_resp, idade_filho_mais_novo.
    """
    using DataFrames

    # Identificar filhos por domicílio
    filhos_por_dom = identificar_filhos_por_domicilio(pessoas)

    # Para cada responsável, calcular idade do filho mais novo
    result = DataFrame(
        domicilio_id = String[],
        idade_resp = Int[],
        sexo_resp = Int[],
        idade_filho_mais_novo = Int[],
        n_filhos = Int[],
        peso = Float64[]
    )

    # Agrupar por domicílio
    dominios = Dict{String, Vector{Pessoa}}()
    for p in pessoas
        if !haskey(dominios, p.domicilio_id)
            dominios[p.domicilio_id] = Pessoa[]
        end
        push!(dominios[p.domicilio_id], p)
    end

    for (dom_id, membros) in dominios
        # Encontrar responsável
        resp_idx = findfirst(p -> p.condicao_dom == 1, membros)
        if resp_idx === nothing
            continue
        end
        resp = membros[resp_idx]

        # Verificar se tem filhos
        if !haskey(filhos_por_dom, dom_id) || isempty(filhos_por_dom[dom_id])
            continue
        end

        # Idade do filho mais novo
        filhos = filhos_por_dom[dom_id]
        idade_min = minimum(f.idade for f in filhos)

        push!(result, (
            dom_id,
            resp.idade,
            resp.sexo,
            idade_min,
            length(filhos),
            resp.peso
        ))
    end

    return result
end
```

### 4. Número de Filhos por Faixa Etária

```julia
function distribuicao_filhos_por_idade(pessoas::Vector{Pessoa})
    """
    Distribuição de filhos menores de 18 anos por idade do responsável.
    """
    using DataFrames

    # Identificar filhos por domicílio
    filhos_por_dom = identificar_filhos_por_domicilio(pessoas)

    # Filtrar filhos < 18 anos
    filhos_menores = Dict{String, Vector{Pessoa}}()
    for (dom_id, filhos) in filhos_por_dom
        menores = filter(f -> f.idade < 18, filhos)
        if !isempty(menores)
            filhos_menores[dom_id] = menores
        end
    end

    # Para cada responsável, contar filhos < 18
    contadores = Dict{Tuple{Int, Int, Int}, Float64}()  # (idade, sexo, n_filhos) => peso_total

    for p in pessoas
        if p.condicao_dom == 1  # Responsável
            n_filhos = haskey(filhos_menores, p.domicilio_id) ?
                       length(filhos_menores[p.domicilio_id]) : 0

            key = (p.idade, p.sexo, n_filhos)
            contadores[key] = get(contadores, key, 0.0) + p.peso
        end
    end

    # Converter para DataFrame
    result = DataFrame(
        idade = Int[],
        sexo = Int[],
        n_filhos_menores = Int[],
        peso_total = Float64[]
    )

    for ((idade, sexo, n_filhos), peso) in contadores
        push!(result, (idade, sexo, n_filhos, peso))
    end

    return result
end
```

## Filtro Importante: Domicílios com Único Responsável

### Por Que Filtrar?

**Usado no projeto em**: `conjugality/01_pnadc2023_empirical_conjugality.jl`

```julia
# Contar responsáveis por domicílio
resp_por_dom = Dict{String, Int}()
for p in pessoas
    if p.condicao_dom == 1
        resp_por_dom[p.domicilio_id] = get(resp_por_dom, p.domicilio_id, 0) + 1
    end
end

# Filtrar domicílios com exatamente 1 responsável
dominios_validos = Set(k for (k, v) in resp_por_dom if v == 1)
pessoas_filtradas = filter(p -> p.domicilio_id ∈ dominios_validos, pessoas)
```

**Motivo:**
- Evita ambiguidade no pareamento cônjuge-responsável
- Garante que V2005=02/03 se refere ao cônjuge do único responsável
- Usado em análises de conjugalidade

## Casos Especiais

### Domicílios Multigeracionais

```julia
# Identificar domicílios com 3+ gerações
function identificar_multigeracionais(pessoas::Vector{Pessoa})
    # Agrupar por domicílio
    dominios = Dict{String, Vector{Pessoa}}()
    for p in pessoas
        if !haskey(dominios, p.domicilio_id)
            dominios[p.domicilio_id] = Pessoa[]
        end
        push!(dominios[p.domicilio_id], p)
    end

    multigeracionais = Dict{String, Vector{Pessoa}}()

    for (dom_id, membros) in dominios
        # Verificar se tem: responsável + filho + neto
        tem_resp = any(p -> p.condicao_dom == 1, membros)
        tem_filho = any(p -> p.condicao_dom in [4, 5, 6], membros)
        tem_neto = any(p -> p.condicao_dom == 10, membros)

        if tem_resp && tem_filho && tem_neto
            multigeracionais[dom_id] = membros
        end
    end

    return multigeracionais
end
```

### Casais do Mesmo Sexo

```julia
# V2005 = 03
casais_mesmo_sexo = filter(p -> p.condicao_dom == 3, pessoas)
```

### Famílias Monoparentais

```julia
# Responsável com filhos, sem cônjuge
function identificar_monoparentais(pessoas::Vector{Pessoa})
    filhos_por_dom = identificar_filhos_por_domicilio(pessoas)

    # Agrupar por domicílio
    dominios = Dict{String, Vector{Pessoa}}()
    for p in pessoas
        if !haskey(dominios, p.domicilio_id)
            dominios[p.domicilio_id] = Pessoa[]
        end
        push!(dominios[p.domicilio_id], p)
    end

    monoparentais = Dict{String, Tuple{Pessoa, Vector{Pessoa}}}()

    for (dom_id, membros) in dominios
        # Tem responsável
        resp_idx = findfirst(p -> p.condicao_dom == 1, membros)
        if resp_idx === nothing
            continue
        end

        # NÃO tem cônjuge
        tem_conjuge = any(p -> p.condicao_dom in [2, 3], membros)
        if tem_conjuge
            continue
        end

        # TEM filhos
        if !haskey(filhos_por_dom, dom_id) || isempty(filhos_por_dom[dom_id])
            continue
        end

        monoparentais[dom_id] = (membros[resp_idx], filhos_por_dom[dom_id])
    end

    return monoparentais
end
```

## Exemplo Completo: Análise de Composição Familiar

```julia
using DataFrames, CSV

# Ler dados
pessoas = ler_pnadc("../data_pnadc2023/PNADC_2023_visita5.txt")

println("="^70)
println("ANÁLISE DE COMPOSIÇÃO FAMILIAR - PNADC 2023")
println("="^70)

# 1. Conjugalidade
println("\n[1/5] Analisando conjugalidade...")
casais = identificar_conjuges(pessoas)
println("Total de casais identificados: $(length(casais))")

prob_conj = prob_ter_conjuge_por_idade_sexo(pessoas)
CSV.write("prob_conjugalidade_2023.csv", prob_conj)
println("✓ Tabela de probabilidade salva")

# 2. Filhos
println("\n[2/5] Identificando filhos...")
filhos_por_dom = identificar_filhos_por_domicilio(pessoas)
n_dom_com_filhos = length(filhos_por_dom)
n_filhos_total = sum(length(v) for v in values(filhos_por_dom))
println("Domicílios com filhos: $n_dom_com_filhos")
println("Total de filhos: $n_filhos_total")

# 3. Probabilidade de ter filho
println("\n[3/5] Calculando probabilidade de ter filho...")
prob_filho = prob_ter_filho_por_idade_sexo(pessoas)
CSV.write("prob_ter_filho_2023.csv", prob_filho)
println("✓ Tabela de probabilidade salva")

# 4. Idade do filho mais novo
println("\n[4/5] Analisando idade do filho mais novo...")
filho_mais_novo = idade_filho_mais_novo_por_responsavel(pessoas)
CSV.write("idade_filho_mais_novo_2023.csv", filho_mais_novo)
println("✓ Dados salvos ($(nrow(filho_mais_novo)) responsáveis)")

using Statistics
println("Idade média do filho mais novo: $(round(mean(filho_mais_novo.idade_filho_mais_novo), digits=1)) anos")

# 5. Casos especiais
println("\n[5/5] Identificando casos especiais...")
monoparentais = identificar_monoparentais(pessoas)
println("Famílias monoparentais: $(length(monoparentais))")

casais_mesmo_sexo_count = count(p -> p.condicao_dom == 3, pessoas)
println("Cônjuges do mesmo sexo: $casais_mesmo_sexo_count")

println("\n" * "="^70)
println("✓ Análise concluída!")
println("="^70)
```

## Validações e Consistência

### Checagens Recomendadas

```julia
# 1. Todo cônjuge deve ter um responsável no mesmo domicílio
conjuges = filter(p -> p.condicao_dom in [2, 3], pessoas)
for conj in conjuges
    membros = filter(p -> p.domicilio_id == conj.domicilio_id, pessoas)
    tem_resp = any(p -> p.condicao_dom == 1, membros)
    if !tem_resp
        println("⚠️  Cônjuge sem responsável: $(conj.domicilio_id)")
    end
end

# 2. Filho não pode ser mais velho que responsável
# (Pode acontecer em casos de netos declarados como filhos)
filhos_por_dom = identificar_filhos_por_domicilio(pessoas)
for (dom_id, filhos) in filhos_por_dom
    resp = findfirst(p -> p.domicilio_id == dom_id && p.condicao_dom == 1, pessoas)
    if resp !== nothing
        for filho in filhos
            if filho.idade > pessoas[resp].idade
                println("⚠️  Filho mais velho que responsável: Dom $dom_id")
            end
        end
    end
end
```

## Próximos Passos

Com a composição familiar identificada:
1. **Gerar tabelas de probabilidade**: [06_probability_tables.md](06_probability_tables.md)
2. **Analisar age gaps**: [07_age_gap_analysis.md](07_age_gap_analysis.md)
3. **Integrar com modelos**: [08_integration_models.md](08_integration_models.md)
4. **Ver exemplos completos**: [09_examples.md](09_examples.md)
