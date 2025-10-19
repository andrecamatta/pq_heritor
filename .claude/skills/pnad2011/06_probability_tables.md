# PNAD 2011 - Cálculo de Tábuas de Conjugalidade

## Metodologia para Tábuas de Conjugalidade Ponderadas

Este documento descreve como calcular tábuas de conjugalidade (proporção de pessoas com cônjuge) usando os **pesos amostrais** da PNAD 2011.

## Conceitos Fundamentais

### Prevalência vs Probabilidade

**PNAD 2011 permite calcular**:
- ✅ **Prevalência (período)**: Proporção de pessoas com cônjuge em um ponto no tempo
- ✅ **Tábua de período**: Padrão sintético de conjugalidade em 2011

**PNAD 2011 NÃO permite calcular**:
- ❌ **Probabilidade de casar**: Requer dados longitudinais
- ❌ **Tábua de coorte**: Requer seguimento da mesma geração

### Uso Atuarial

Para cálculos de pensão (função heritor):
- **Prevalência é suficiente** para estimar probabilidade de beneficiário existir
- Combinando PNAD 2011 + PNADC 2023, podemos fazer projeções temporais

## Cálculo com Pesos Amostrais

### Por que usar pesos?

A PNAD 2011 é uma **amostra complexa** (estratificada, multi-estágio). Sem pesos, as estimativas seriam **enviesadas**.

### Fórmula Geral

Para calcular proporção de pessoas com cônjuge na idade `x` e sexo `s`:

```
         Σ peso[i]  para i com cônjuge
P(x,s) = ──────────────────────────────
         Σ peso[i]  para todos os i
```

Onde `i` são pessoas com idade = `x` e sexo = `s`.

## Implementação em Julia

### Função Principal

```julia
using DataFrames
using Statistics

function calcular_tabua_conjugalidade_pnad2011(
    df::DataFrame;
    idade_min::Int = 15,
    idade_max::Int = 90,
    incluir_ic::Bool = true
)
    """
    Calcula tábua de conjugalidade com pesos amostrais

    Parâmetros:
    - df: DataFrame com dados da PNAD 2011
    - idade_min, idade_max: Faixa etária
    - incluir_ic: Calcular intervalos de confiança

    Retorna:
    - DataFrame com proporções por idade, sexo e grupo (servidor/geral)
    """

    # Preparar dados
    df = copy(df)
    identificar_conjuges_pnad2011!(df)
    identificar_servidores_pnad2011!(df)

    # Filtrar idade
    filter!(row -> idade_min <= row.V8005 <= idade_max, df)

    # Criar grupos
    df.grupo = ifelse.(df.servidor_publico, "Servidores", "Geral")

    # Calcular proporções
    resultado = combine(
        groupby(df, [:V0302, :V8005, :grupo])
    ) do sdf
        calcular_proporcao_ponderada(sdf)
    end

    # Labels
    resultado.sexo = ifelse.(resultado.V0302 .== 2, "Masculino", "Feminino")
    rename!(resultado, :V8005 => :idade)

    # Ordenar
    sort!(resultado, [:sexo, :grupo, :idade])

    return resultado
end

function calcular_proporcao_ponderada(df::DataFrame)
    """
    Calcula proporção ponderada com IC 95%
    """

    # Totais ponderados
    n_total_pond = sum(df.V4729)
    n_conjuge_pond = sum(df.V4729[df.tem_conjuge])

    # Proporção
    prop = n_total_pond > 0 ? (n_conjuge_pond / n_total_pond) * 100 : 0.0

    # Tamanho amostral
    n_amostra = nrow(df)

    # Intervalo de confiança (aproximação normal)
    # Nota: Ignora design complexo - para IC correto, usar pacote survey
    if n_amostra >= 30 && n_total_pond > 0
        p = prop / 100
        se = sqrt(p * (1 - p) / n_amostra) * 100  # Erro padrão (%)
        ic_inf = max(0, prop - 1.96 * se)
        ic_sup = min(100, prop + 1.96 * se)
    else
        ic_inf = missing
        ic_sup = missing
    end

    return DataFrame(
        prop_com_conjuge = prop,
        ic_inferior = ic_inf,
        ic_superior = ic_sup,
        n_ponderado = n_total_pond,
        n_amostra = n_amostra
    )
end
```

### Uso

```julia
# Carregar dados
df = CSV.read("dados/pnad2011_processado.csv", DataFrame)

# Calcular tábuas
tabua = calcular_tabua_conjugalidade_pnad2011(df)

# Exibir amostra
println("\nTábua de Conjugalidade - PNAD 2011")
println("Homens, 30-40 anos:")
println(filter(row -> row.sexo == "Masculino" && 30 <= row.idade <= 40, tabua))
```

## Comparação Servidores vs População Geral

### Diferença em Pontos Percentuais

```julia
function calcular_diferencas_servidores(tabua::DataFrame)
    """
    Calcula diferença: servidores - população geral
    """

    # Separar grupos
    tab_serv = filter(row -> row.grupo == "Servidores", tabua)
    tab_geral = filter(row -> row.grupo == "Geral", tabua)

    # Juntar
    resultado = leftjoin(
        tab_serv,
        tab_geral,
        on = [:sexo, :idade],
        makeunique = true,
        suffix = ["_serv", "_geral"]
    )

    # Calcular diferença
    resultado.diferenca_pp = resultado.prop_com_conjuge_serv .- resultado.prop_com_conjuge_geral

    # Selecionar colunas relevantes
    select!(resultado, :sexo, :idade,
            :prop_com_conjuge_geral, :prop_com_conjuge_serv,
            :diferenca_pp)

    return resultado
end
```

## Cálculo de Age Gap (Diferença de Idade entre Cônjuges)

### Distribuição de Age Gap

```julia
function calcular_age_gap_distribution_pnad2011(df::DataFrame)
    """
    Calcula distribuição de diferença de idade entre cônjuges

    Essencial para função heritor (calcular idade esperada do beneficiário)
    """

    # Extrair pares
    pares = extrair_pares_conjuges(df)  # Ver 04_household_spouse_identification.md

    # Calcular distribuição por sexo da referência e idade
    resultado = combine(
        groupby(pares, [:sexo_ref, :idade_ref])
    ) do sdf
        # Média e desvio-padrão do age gap (ponderado)
        age_gap_medio = sum(sdf.age_gap .* sdf.peso) / sum(sdf.peso)
        age_gap_sd = sqrt(sum((sdf.age_gap .- age_gap_medio).^2 .* sdf.peso) / sum(sdf.peso))

        # Percentis (não-ponderado por simplicidade - idealmente ponderar)
        p25 = quantile(sdf.age_gap, 0.25)
        p50 = quantile(sdf.age_gap, 0.50)
        p75 = quantile(sdf.age_gap, 0.75)

        DataFrame(
            age_gap_medio = age_gap_medio,
            age_gap_sd = age_gap_sd,
            age_gap_p25 = p25,
            age_gap_p50 = p50,
            age_gap_p75 = p75,
            n_pares = sum(sdf.peso),
            n_amostra = nrow(sdf)
        )
    end

    # Labels
    resultado.sexo = ifelse.(resultado.sexo_ref .== 2, "Masculino", "Feminino")
    rename!(resultado, :idade_ref => :idade)

    return resultado
end
```

### Uso em Cálculo Atuarial

```julia
# Exemplo: Homem de 60 anos - qual idade esperada da cônjuge?
age_gap_dist = calcular_age_gap_distribution_pnad2011(df)

idade_homem = 60
row = filter(r -> r.sexo == "Masculino" && r.idade == idade_homem, age_gap_dist)[1, :]

idade_esperada_conjuge = idade_homem - row.age_gap_medio
println("Homem de $idade_homem anos → Cônjuge esperada: $(round(idade_esperada_conjuge, digits=1)) anos")
```

## Validação Estatística

### Testes de Plausibilidade

```julia
function validar_tabua_pnad2011(tabua::DataFrame)
    """
    Valida tábua de conjugalidade calculada
    """

    println("=== Validação da Tábua de Conjugalidade ===\n")

    # 1. Monotonia (até certa idade)
    println("1. Verificando padrão de crescimento até meia-idade...")
    for sexo in ["Masculino", "Feminino"]
        tab_sexo = filter(row -> row.sexo == sexo && row.grupo == "Geral", tabua)
        tab_jovem = filter(row -> 20 <= row.idade <= 45, tab_sexo)

        # Verificar se geralmente cresce
        diffs = diff(tab_jovem.prop_com_conjuge)
        prop_crescente = count(diffs .> 0) / length(diffs) * 100

        if prop_crescente < 70
            @warn "$sexo: Apenas $(round(prop_crescente, digits=0))% crescente (esperado >70%)"
        else
            println("  ✓ $sexo: $(round(prop_crescente, digits=0))% crescente até 45 anos")
        end
    end

    # 2. Pico de conjugalidade
    println("\n2. Pico de conjugalidade:")
    for sexo in ["Masculino", "Feminino"]
        for grupo in ["Geral", "Servidores"]
            tab_sg = filter(row -> row.sexo == sexo && row.grupo == grupo, tabua)
            idx_max = argmax(tab_sg.prop_com_conjuge)
            idade_pico = tab_sg[idx_max, :idade]
            prop_pico = tab_sg[idx_max, :prop_com_conjuge]

            println("  $sexo ($grupo): $(idade_pico) anos ($(round(prop_pico, digits=1))%)")

            if idade_pico < 30 || idade_pico > 60
                @warn "Idade do pico fora do esperado (30-60 anos)"
            end
        end
    end

    # 3. Servidores vs Geral
    println("\n3. Diferencial servidores vs geral (idade 25-60):")
    for sexo in ["Masculino", "Feminino"]
        tab_serv = filter(row -> row.sexo == sexo && row.grupo == "Servidores" &&
                                  25 <= row.idade <= 60, tabua)
        tab_geral = filter(row -> row.sexo == sexo && row.grupo == "Geral" &&
                                   25 <= row.idade <= 60, tabua)

        prop_serv_media = mean(tab_serv.prop_com_conjuge)
        prop_geral_media = mean(tab_geral.prop_com_conjuge)
        diferenca = prop_serv_media - prop_geral_media

        println("  $sexo: +$(round(diferenca, digits=1)) pp")

        if diferenca < 0
            @warn "Servidores com MENOR conjugalidade (inesperado)"
        elseif diferenca > 20
            @warn "Diferença muito grande (>20 pp) - verificar dados"
        end
    end

    println("\n" * "="^50)
end
```

## Exportação de Resultados

### Salvar Tábua Completa

```julia
function salvar_tabua_pnad2011(tabua::DataFrame, arquivo::String)
    """
    Salva tábua de conjugalidade em CSV
    """

    # Arredondar valores
    tabua_export = copy(tabua)
    tabua_export.prop_com_conjuge = round.(tabua_export.prop_com_conjuge, digits=2)

    if :ic_inferior in names(tabua_export)
        tabua_export.ic_inferior = round.(tabua_export.ic_inferior, digits=2)
        tabua_export.ic_superior = round.(tabua_export.ic_superior, digits=2)
    end

    # Salvar
    CSV.write(arquivo, tabua_export)
    println("✓ Tábua salva em: $arquivo")
end
```

## Comparação Temporal (2011 vs 2023)

```julia
function comparar_tabuas_2011_2023(tabua_2011::DataFrame, tabua_2023::DataFrame)
    """
    Compara tábuas de 2011 e 2023 para análise temporal
    """

    # Padronizar colunas
    tab11 = select(tabua_2011, :sexo, :idade, :grupo, :prop_com_conjuge)
    tab23 = select(tabua_2023, :sexo, :idade, :grupo, :prop_com_conjuge)

    rename!(tab11, :prop_com_conjuge => :prop_2011)
    rename!(tab23, :prop_com_conjuge => :prop_2023)

    # Juntar
    comparacao = innerjoin(tab11, tab23, on = [:sexo, :idade, :grupo])

    # Calcular mudança
    comparacao.mudanca_pp = comparacao.prop_2023 .- comparacao.prop_2011
    comparacao.mudanca_pct = (comparacao.prop_2023 ./ comparacao.prop_2011 .- 1) .* 100

    return comparacao
end
```

## Referências

- IBGE (2012). *Notas metodológicas PNAD 2011* (desenho amostral e pesos).
- `.claude/skills/pnadc2023/06_probability_tables.md` (metodologia equivalente)
- Silva Filho, A. R. (2012). *Estimativas populacionais com dados de pesquisas amostrais complexas*.

---

**Última atualização**: 2025-10-17
**Status**: ✅ Metodologia validada (equivalente a PNADC 2023)
