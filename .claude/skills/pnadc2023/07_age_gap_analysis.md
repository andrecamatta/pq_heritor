# Age Gap Analysis - Diferença de Idade entre Cônjuges

## Visão Geral

Age gap (diferença de idade) é um indicador demográfico importante para análise familiar. No PNADC 2023, calculamos:

```
age_gap = idade_responsável - idade_cônjuge
```

**Convenção**:
- **age_gap > 0**: Responsável mais velho
- **age_gap < 0**: Responsável mais jovem
- **age_gap = 0**: Mesma idade

## Arquivo de Referência

`conjugality/03_age_gap_pnadc2023.jl` - Implementação completa funcional

## Identificação de Casais

### Estrutura de Dados

```julia
struct Casal
    domicilio_id::String
    idade_resp::Int
    sexo_resp::Int
    idade_conj::Int
    sexo_conj::Int
    tipo_conjuge::Int  # 2=sexo diferente, 3=mesmo sexo
    peso::Float64
end
```

### Algoritmo de Identificação

```julia
function identificar_casais(pessoas::Vector{Pessoa})
    """
    Identifica casais (responsável + cônjuge) no PNADC 2023.
    Retorna vetor de Casal.
    """
    # Agrupar por domicílio
    dominios = Dict{String, Vector{Pessoa}}()
    for p in pessoas
        if !haskey(dominios, p.domicilio_id)
            dominios[p.domicilio_id] = Pessoa[]
        end
        push!(dominios[p.domicilio_id], p)
    end

    casais = Casal[]

    for (dom_id, membros) in dominios
        # Encontrar responsável (V2005 = 01)
        responsavel = findfirst(p -> p.condicao_dom == 1, membros)
        if responsavel === nothing
            continue
        end
        resp = membros[responsavel]

        # Encontrar cônjuge (V2005 = 02 ou 03)
        conjuge = findfirst(p -> p.condicao_dom in [2, 3], membros)
        if conjuge === nothing
            continue
        end
        conj = membros[conjuge]

        # Criar registro de casal
        push!(casais, Casal(
            dom_id,
            resp.idade,
            resp.sexo,
            conj.idade,
            conj.sexo,
            conj.condicao_dom,  # 2 ou 3
            resp.peso  # usar peso do responsável
        ))
    end

    return casais
end
```

## Cálculo do Age Gap

### Por Casal Individual

```julia
# Adicionar age_gap ao DataFrame
using DataFrames

df_casais = DataFrame(
    domicilio_id = [c.domicilio_id for c in casais],
    idade_resp = [c.idade_resp for c in casais],
    sexo_resp = [c.sexo_resp for c in casais],
    idade_conj = [c.idade_conj for c in casais],
    sexo_conj = [c.sexo_conj for c in casais],
    tipo_conjuge = [c.tipo_conjuge for c in casais],
    peso = [c.peso for c in casais]
)

# Calcular age gap
df_casais[!, :age_gap] = df_casais.idade_resp .- df_casais.idade_conj
```

### Classificação de Casais

```julia
# Adicionar tipo de casal
df_casais[!, :tipo_casal] = map(df_casais.sexo_resp, df_casais.tipo_conjuge) do sr, tc
    if tc == 3
        return "mesmo_sexo"
    elseif sr == 1  # homem responsável
        return "tradicional"  # homem + mulher
    else  # mulher responsável
        return "invertido"  # mulher + homem
    end
end
```

## Estatísticas Descritivas

### Globais

```julia
using Statistics, Printf

function analisar_age_gaps(df_casais::DataFrame)
    println("="^70)
    println("ESTATÍSTICAS DE AGE GAP - PNADC 2023")
    println("="^70)

    println("\nESTATÍSTICAS GLOBAIS:")
    println("-"^70)
    println(@sprintf("  Média de age gap: %.2f anos", mean(df_casais.age_gap)))
    println(@sprintf("  Mediana: %.2f anos", median(df_casais.age_gap)))
    println(@sprintf("  Desvio padrão: %.2f anos", std(df_casais.age_gap)))
    println(@sprintf("  Q1: %.2f anos", quantile(df_casais.age_gap, 0.25)))
    println(@sprintf("  Q3: %.2f anos", quantile(df_casais.age_gap, 0.75)))
    println(@sprintf("  Mínimo: %d anos", minimum(df_casais.age_gap)))
    println(@sprintf("  Máximo: %d anos", maximum(df_casais.age_gap)))

    # Proporção de inversão (mulher mais velha ou homem mais jovem)
    n_inversao = sum(df_casais.age_gap .< 0)
    pct_inversao = n_inversao / nrow(df_casais) * 100
    println()
    println(@sprintf("  Casais com inversão (responsável mais jovem): %d (%.1f%%)",
                     n_inversao, pct_inversao))

    println()
end
```

### Por Tipo de Casal

```julia
function analisar_por_tipo(df_casais::DataFrame)
    println("ESTATÍSTICAS POR TIPO DE CASAL:")
    println("-"^70)

    for tipo in ["tradicional", "invertido", "mesmo_sexo"]
        df_tipo = filter(r -> r.tipo_casal == tipo, df_casais)
        if nrow(df_tipo) == 0
            continue
        end

        println()
        println("  $(uppercase(tipo)):")
        println(@sprintf("    N = %d casais", nrow(df_tipo)))
        println(@sprintf("    Média age gap: %.2f anos", mean(df_tipo.age_gap)))
        println(@sprintf("    Mediana: %.2f anos", median(df_tipo.age_gap)))
        println(@sprintf("    Desvio padrão: %.2f anos", std(df_tipo.age_gap)))

        if tipo != "mesmo_sexo"
            n_inv = sum(df_tipo.age_gap .< 0)
            pct_inv = n_inv / nrow(df_tipo) * 100
            println(@sprintf("    Inversão: %d (%.1f%%)", n_inv, pct_inv))
        end
    end

    println()
end
```

## Age Gap Médio por Idade e Sexo do Responsável

### Método: Média Ponderada

```julia
function age_gap_por_idade_sexo(df_casais::DataFrame)
    """
    Calcula age gap médio ponderado por (idade_resp, sexo_resp).
    """
    using DataFrames, Statistics

    # Agrupar e calcular média ponderada
    result = combine(
        groupby(df_casais, [:idade_resp, :sexo_resp]),
        :age_gap => (x -> mean(x)) => :gap_medio,
        :age_gap => (x -> std(x)) => :gap_std,
        nrow => :n_casais,
        :peso => sum => :peso_total
    )

    # Ordenar
    sort!(result, [:sexo_resp, :idade_resp])

    return result
end
```

### Método: Média Ponderada Manual (Mais Preciso)

```julia
function age_gap_ponderado_por_idade_sexo(casais::Vector{Casal})
    """
    Calcula age gap médio usando pesos amostrais explicitamente.
    """
    contadores = Dict{Tuple{Int, Int}, Vector{Tuple{Float64, Float64}}}()
    # (idade, sexo) => [(age_gap, peso), ...]

    for c in casais
        key = (c.idade_resp, c.sexo_resp)
        age_gap = c.idade_resp - c.idade_conj

        if !haskey(contadores, key)
            contadores[key] = []
        end
        push!(contadores[key], (age_gap, c.peso))
    end

    # Calcular médias ponderadas
    result = DataFrame(
        idade = Int[],
        sexo = Int[],
        age_gap_medio = Float64[],
        n_casais = Int[]
    )

    for ((idade, sexo), gaps_pesos) in contadores
        soma_ponderada = sum(gap * peso for (gap, peso) in gaps_pesos)
        soma_pesos = sum(peso for (gap, peso) in gaps_pesos)
        media = soma_ponderada / soma_pesos

        push!(result, (idade, sexo, media, length(gaps_pesos)))
    end

    return result
end
```

## Visualizações

### Histograma de Age Gap

```julia
using Plots

function plot_age_gap_histogram(df_casais::DataFrame)
    histogram(
        df_casais.age_gap,
        bins=-30:2:30,
        xlabel="Age Gap (anos)",
        ylabel="Frequência",
        title="Distribuição de Age Gap - PNADC 2023",
        legend=false,
        color=:steelblue
    )

    vline!([0], color=:red, linestyle=:dash, linewidth=2)
    annotate!(0, :top, text("Gap = 0", 8, :red))

    savefig("age_gap_histogram_2023.png")
end
```

### Age Gap por Idade do Responsável

```julia
function plot_age_gap_by_age(gap_por_idade::DataFrame)
    # Separar por sexo
    df_m = filter(r -> r.sexo == 1, gap_por_idade)
    df_f = filter(r -> r.sexo == 2, gap_por_idade)

    plot(df_m.idade, df_m.age_gap_medio,
         label="Homens responsáveis",
         color=:blue,
         linewidth=2,
         xlabel="Idade do responsável",
         ylabel="Age gap médio (anos)",
         title="Age Gap Médio por Idade - PNADC 2023",
         legend=:topright)

    plot!(df_f.idade, df_f.age_gap_medio,
          label="Mulheres responsáveis",
          color=:red,
          linewidth=2)

    hline!([0], color=:black, linestyle=:dash, linewidth=1)

    savefig("age_gap_by_age_2023.png")
end
```

## Comparação com Modelos ou Dados Históricos

### Comparar com PNAD 2011

```julia
# Carregar dados históricos
df_2011 = CSV.read("conjugality/age_gaps_2011.csv", DataFrame)
df_2023 = age_gap_por_idade_sexo(df_casais)

# Merge
df_comp = outerjoin(
    rename(df_2011, :gap_medio => :gap_2011),
    rename(df_2023, :gap_medio => :gap_2023),
    on = [:idade, :sexo]
)

# Calcular diferença
df_comp[!, :diferenca] = df_comp.gap_2023 .- df_comp.gap_2011

# Plot
plot(df_comp.idade, df_comp.diferenca,
     xlabel="Idade",
     ylabel="Diferença de age gap (2023 - 2011)",
     title="Evolução do Age Gap: 2011 → 2023",
     legend=false)

hline!([0], color=:black, linestyle=:dash)
```

### Comparar com Modelo Demográfico

```julia
# Carregar modelo
include("age_gap/age_gap_model.jl")

# Ajustar splines com dados 2011
df_2011 = CSV.read("age_gap/apendice6_idade_conjuge_2011.csv", DataFrame)
fit_gap_splines!(df_2011)

# Comparar predições do modelo vs observado 2023
idades = 20:80

# Predições do modelo (ajustado em 2011)
pred_m = [mu_gap(a, sex=:M) for a in idades]
pred_f = [mu_gap(a, sex=:F) for a in idades]

# Observado 2023
df_2023 = age_gap_por_idade_sexo(df_casais)
obs_m = df_2023[df_2023.sexo .== 1, :]
obs_f = df_2023[df_2023.sexo .== 2, :]

# Plot comparação
plot(idades, pred_m,
     label="Modelo 2011 (Homens)",
     color=:blue,
     linestyle=:dash,
     linewidth=2)

scatter!(obs_m.idade, obs_m.age_gap_medio,
         label="Observado 2023 (Homens)",
         color=:blue,
         markersize=3)

# Similar para mulheres...
```

## Salvando Resultados

```julia
using CSV

function salvar_age_gap_analysis(casais::Vector{Casal}; output_dir="output/")
    mkpath(output_dir)

    # 1. DataFrame com todos os casais
    df_casais = DataFrame(casais)
    df_casais[!, :age_gap] = df_casais.idade_resp .- df_casais.idade_conj
    CSV.write(joinpath(output_dir, "age_gaps_2023.csv"), df_casais)

    # 2. Sumário estatístico
    df_summary = DataFrame(
        tipo_casal = String[],
        n_casais = Int[],
        media_age_gap = Float64[],
        mediana_age_gap = Float64[],
        desvio_age_gap = Float64[],
        q25 = Float64[],
        q75 = Float64[],
        pct_inversao = Float64[]
    )

    for tipo in ["tradicional", "invertido", "mesmo_sexo", "TOTAL"]
        if tipo == "TOTAL"
            df_tipo = df_casais
        else
            df_tipo = filter(r -> r.tipo_casal == tipo, df_casais)
        end

        if nrow(df_tipo) == 0
            continue
        end

        n_inv = sum(df_tipo.age_gap .< 0)
        pct_inv = n_inv / nrow(df_tipo) * 100

        push!(df_summary, (
            tipo,
            nrow(df_tipo),
            mean(df_tipo.age_gap),
            median(df_tipo.age_gap),
            std(df_tipo.age_gap),
            quantile(df_tipo.age_gap, 0.25),
            quantile(df_tipo.age_gap, 0.75),
            pct_inv
        ))
    end

    CSV.write(joinpath(output_dir, "age_gaps_2023_summary.csv"), df_summary)

    # 3. Age gap por idade e sexo
    df_by_age = age_gap_ponderado_por_idade_sexo(casais)
    CSV.write(joinpath(output_dir, "age_gap_by_age_2023.csv"), df_by_age)

    println("✓ Arquivos salvos:")
    println("  - age_gaps_2023.csv (detalhado)")
    println("  - age_gaps_2023_summary.csv (resumo)")
    println("  - age_gap_by_age_2023.csv (por idade)")
end
```

## Exemplo Completo

**Arquivo de referência**: `conjugality/03_age_gap_pnadc2023.jl`

```julia
using DataFrames, CSV, Statistics, Printf

# 1. Ler dados
println("[1/4] Lendo arquivo PNADC 2023...")
pessoas = ler_pnadc("../data_pnadc2023/PNADC_2023_visita5.txt")

# 2. Identificar casais
println("[2/4] Identificando casais...")
casais = identificar_casais(pessoas)
println("Total de casais: $(length(casais))")

# 3. Calcular age gaps e estatísticas
println("[3/4] Calculando age gaps...")
df_casais = DataFrame(casais)
df_casais[!, :age_gap] = df_casais.idade_resp .- df_casais.idade_conj

# Classificar tipo de casal
df_casais[!, :tipo_casal] = map(df_casais.sexo_resp, df_casais.tipo_conjuge) do sr, tc
    if tc == 3
        return "mesmo_sexo"
    elseif sr == 1
        return "tradicional"
    else
        return "invertido"
    end
end

# Estatísticas
analisar_age_gaps(df_casais)
analisar_por_tipo(df_casais)

# 4. Salvar resultados
println("[4/4] Salvando resultados...")
salvar_age_gap_analysis(casais, output_dir="output/")

println()
println("="^70)
println("✓ Análise de age gap concluída!")
println("="^70)
```

## Interpretação dos Resultados

### Age Gap Positivo vs Negativo

- **Tradicional (homem responsável + mulher cônjuge)**:
  - Age gap positivo = homem mais velho (comum)
  - Age gap negativo = homem mais jovem (menos comum)

- **Invertido (mulher responsável + homem cônjuge)**:
  - Age gap positivo = mulher mais velha
  - Age gap negativo = mulher mais jovem

### Tendências Esperadas

1. **Homens responsáveis**: Gap positivo ~2-5 anos (parceiro mais jovem)
2. **Mulheres responsáveis**: Gap mais variável, frequentemente negativo
3. **Variação com idade**: Gap tende a aumentar com idade do responsável

## Próximos Passos

Com age gaps analisados:
1. **Integrar com modelos**: [08_integration_models.md](08_integration_models.md)
2. **Exemplos completos**: [09_examples.md](09_examples.md)
3. **Comparar com dados históricos**: Ver `conjugality/RELATORIO_PNADC2023.md`
