# PNAD 2011 + PNADC 2023 - Harmonização para Análise Temporal

## Objetivo

Este documento descreve como **harmonizar** dados da PNAD 2011 e PNADC 2023 para criar:
1. **Séries temporais** de conjugalidade (2011-2023)
2. **Projeções futuras** (2024-2040) para cálculos atuariais
3. **Análise de tendências** por grupo (servidores públicos vs população geral)

## Pipeline Completo de Harmonização

### Passo 1: Leitura e Processamento Individual

```julia
# === PNAD 2011 ===
df_2011 = ler_e_processar_pnad2011("dados/PES2011.txt")

# === PNADC 2023 ===
df_2023 = ler_e_processar_pnadc2023("dados/PNADC_2023_visita1.txt")
```

### Passo 2: Padronização de Variáveis

```julia
function padronizar_variaveis!(df::DataFrame, fonte::String)
    """
    Cria colunas padronizadas em ambas as bases

    Colunas criadas:
    - ano: Int (2011 ou 2023)
    - uf: Int
    - sexo: Int (1=Masculino, 2=Feminino) - PADRONIZADO
    - idade: Int (anos completos)
    - peso: Float64
    - tem_conjuge: Bool
    - servidor_publico: Bool
    """

    if fonte == "PNAD2011"
        df.ano = fill(2011, nrow(df))
        df.uf = df.UF

        # RECODIFICAR sexo: 2→1, 4→2
        df.sexo = ifelse.(df.V0302 .== 2, 1, 2)

        df.idade = df.V8005
        df.peso = df.V4729

        # Identificar cônjuge
        identificar_conjuges_pnad2011!(df)

        # Servidor (⚠️ verificar código!)
        df.servidor_publico = df.V4706 .== 05  # Placeholder

    elseif fonte == "PNADC2023"
        df.ano = fill(2023, nrow(df))
        df.uf = df.UF
        df.sexo = df.V2007  # Já é 1/2
        df.idade = df.V2009
        df.peso = df.V1032

        # Identificar cônjuge (02 ou 03)
        identificar_conjuges_pnadc2023!(df)

        # Servidor
        df.servidor_publico = df.V4028 .== 5

    else
        error("Fonte inválida: $fonte")
    end

    return df
end

# Uso
padronizar_variaveis!(df_2011, "PNAD2011")
padronizar_variaveis!(df_2023, "PNADC2023")
```

### Passo 3: Aplicar Filtros Comuns

```julia
function aplicar_filtros_harmonizacao!(df::DataFrame)
    """
    Filtros comuns para ambas as bases
    """

    # Idade válida
    filter!(row -> 15 <= row.idade <= 90, df)

    # Peso válido
    filter!(row -> row.peso > 0, df)

    # Sexo válido
    filter!(row -> row.sexo ∈ [1, 2], df)

    return df
end

aplicar_filtros_harmonizacao!(df_2011)
aplicar_filtros_harmonizacao!(df_2023)
```

### Passo 4: (Opcional) Filtro de Comparabilidade Geográfica

```julia
function aplicar_filtro_geografico!(df::DataFrame; excluir_rural_norte::Bool = false)
    """
    Excluir zona rural do Norte se necessário para comparabilidade estrita

    PNAD 2011 não inclui zona rural do Norte
    PNADC 2023 inclui

    Opções:
    - excluir_rural_norte = true: Máxima comparabilidade (perde dados)
    - excluir_rural_norte = false: Usa todos os dados (preferível)
    """

    if excluir_rural_norte
        # UFs do Norte: 11-17
        # V1022 = 2 (rural) - variável da PNADC 2023
        if :V1022 in names(df)
            filter!(row -> !(row.uf <= 17 && row.V1022 == 2), df)
            println("⚠️ Zona rural do Norte excluída")
        end
    end

    return df
end

# Decisão: Geralmente NÃO excluir (zona rural do Norte é pequena proporção)
# aplicar_filtro_geografico!(df_2023, excluir_rural_norte = false)
```

### Passo 5: Selecionar Colunas Comuns e Empilhar

```julia
function empilhar_bases(df_2011::DataFrame, df_2023::DataFrame)
    """
    Seleciona colunas comuns e empilha as bases
    """

    colunas = [:ano, :uf, :sexo, :idade, :peso, :tem_conjuge, :servidor_publico]

    df_2011_sel = select(df_2011, colunas)
    df_2023_sel = select(df_2023, colunas)

    # Empilhar
    df_combinado = vcat(df_2011_sel, df_2023_sel)

    println("Base combinada:")
    println("  2011: $(count(df_combinado.ano .== 2011)) registros")
    println("  2023: $(count(df_combinado.ano .== 2023)) registros")

    return df_combinado
end

df_harmonizado = empilhar_bases(df_2011, df_2023)
```

## Cálculo de Tábuas Temporais

### Tábua por Ano, Sexo, Idade, Grupo

```julia
function calcular_tabua_temporal(df::DataFrame)
    """
    Calcula tábua de conjugalidade para ambos os anos
    """

    # Criar grupo
    df.grupo = ifelse.(df.servidor_publico, "Servidores", "Geral")

    # Calcular proporções
    tabua = combine(
        groupby(df, [:ano, :sexo, :idade, :grupo])
    ) do sdf
        n_total_pond = sum(sdf.peso)
        n_conjuge_pond = sum(sdf.peso[sdf.tem_conjuge])

        prop = n_total_pond > 0 ? (n_conjuge_pond / n_total_pond) * 100 : 0.0

        DataFrame(
            prop_com_conjuge = prop,
            n_ponderado = n_total_pond,
            n_amostra = nrow(sdf)
        )
    end

    # Ordenar
    sort!(tabua, [:grupo, :sexo, :idade, :ano])

    return tabua
end

tabua_temporal = calcular_tabua_temporal(df_harmonizado)
```

### Visualização de Tendências

```julia
using Plots

function plotar_tendencia_temporal(tabua::DataFrame)
    """
    Plota evolução 2011-2023 para idades selecionadas
    """

    idades_plot = [25, 35, 45, 55]

    for sexo_val in [1, 2]
        sexo_label = sexo_val == 1 ? "Masculino" : "Feminino"

        p = plot(
            title = "Tendência de Conjugalidade - $sexo_label",
            xlabel = "Ano",
            ylabel = "Proporção com cônjuge (%)",
            legend = :bottomright,
            size = (1000, 600)
        )

        for grupo in ["Geral", "Servidores"]
            for idade in idades_plot
                dados = filter(row ->
                    row.sexo == sexo_val &&
                    row.idade == idade &&
                    row.grupo == grupo,
                    tabua)

                if nrow(dados) == 2  # 2011 e 2023
                    plot!(p, dados.ano, dados.prop_com_conjuge,
                          label = "$grupo - $(idade) anos",
                          marker = :circle,
                          linewidth = 2)
                end
            end
        end

        savefig(p, "resultados/tendencia_$(sexo_label).png")
        println("✓ Gráfico salvo: tendencia_$(sexo_label).png")
    end
end
```

## Projeção para Anos Futuros (2024-2040)

### Modelo Linear Simples

```julia
function projetar_conjugalidade_linear(tabua::DataFrame, anos_proj::Vector{Int})
    """
    Projeção linear simples baseada em 2011 e 2023

    ⚠️ Modelo simplificado - considerar modelos mais sofisticados para uso atuarial
    """

    projecoes = DataFrame()

    for sexo_val in [1, 2]
        for idade in 15:90
            for grupo in ["Geral", "Servidores"]
                # Dados históricos
                dados = filter(row ->
                    row.sexo == sexo_val &&
                    row.idade == idade &&
                    row.grupo == grupo,
                    tabua)

                if nrow(dados) < 2
                    continue  # Sem dados suficientes
                end

                # Ordenar por ano
                sort!(dados, :ano)

                # Taxa de mudança anual
                prop_2011 = dados[1, :prop_com_conjuge]
                prop_2023 = dados[2, :prop_com_conjuge]
                taxa_anual = (prop_2023 - prop_2011) / (2023 - 2011)

                # Projetar
                for ano_futuro in anos_proj
                    anos_diff = ano_futuro - 2023
                    prop_proj = prop_2023 + taxa_anual * anos_diff

                    # Limitar entre 0 e 100
                    prop_proj = clamp(prop_proj, 0.0, 100.0)

                    push!(projecoes, (
                        ano = ano_futuro,
                        sexo = sexo_val,
                        idade = idade,
                        grupo = grupo,
                        prop_com_conjuge = prop_proj,
                        metodo = "linear"
                    ))
                end
            end
        end
    end

    return projecoes
end

# Projetar até 2040
anos_futuro = collect(2024:2040)
projecoes = projetar_conjugalidade_linear(tabua_temporal, anos_futuro)
```

### Modelo Alternativo: Tendência Suavizada

```julia
function projetar_conjugalidade_suavizada(tabua::DataFrame, anos_proj::Vector{Int};
                                           fator_amortecimento::Float64 = 0.5)
    """
    Projeção com amortecimento (tendência desacelera ao longo do tempo)

    fator_amortecimento ∈ [0, 1]:
    - 0.0: Sem mudança (mantém 2023)
    - 1.0: Mudança linear completa
    - 0.5: Mudança amortecida pela metade
    """

    projecoes = DataFrame()

    for sexo_val in [1, 2]
        for idade in 15:90
            for grupo in ["Geral", "Servidores"]
                dados = filter(row ->
                    row.sexo == sexo_val &&
                    row.idade == idade &&
                    row.grupo == grupo,
                    tabua)

                if nrow(dados) < 2
                    continue
                end

                sort!(dados, :ano)
                prop_2011 = dados[1, :prop_com_conjuge]
                prop_2023 = dados[2, :prop_com_conjuge]

                # Taxa amortecida
                taxa_anual = (prop_2023 - prop_2011) / (2023 - 2011) * fator_amortecimento

                for ano_futuro in anos_proj
                    anos_diff = ano_futuro - 2023
                    prop_proj = prop_2023 + taxa_anual * anos_diff
                    prop_proj = clamp(prop_proj, 0.0, 100.0)

                    push!(projecoes, (
                        ano = ano_futuro,
                        sexo = sexo_val,
                        idade = idade,
                        grupo = grupo,
                        prop_com_conjuge = prop_proj,
                        metodo = "suavizada"
                    ))
                end
            end
        end
    end

    return projecoes
end

# Projeção conservadora (50% da tendência)
projecoes_conserv = projetar_conjugalidade_suavizada(tabua_temporal, anos_futuro,
                                                       fator_amortecimento = 0.5)
```

## Validação de Harmonização

### Checklist de Validação

```julia
function validar_harmonizacao(df_2011::DataFrame, df_2023::DataFrame, tabua::DataFrame)
    """
    Valida harmonização entre PNAD 2011 e PNADC 2023
    """

    println("=== Validação de Harmonização ===\n")

    # 1. Tamanhos amostrais
    println("1. Tamanhos amostrais:")
    println("  PNAD 2011: $(nrow(df_2011)) registros")
    println("  PNADC 2023: $(nrow(df_2023)) registros")

    # 2. Distribuição de sexo
    println("\n2. Distribuição de sexo (deve estar em 1/2):")
    for ano in [2011, 2023]
        df_ano = ano == 2011 ? df_2011 : df_2023
        println("  $ano:")
        println("    Masculino (1): $(count(df_ano.sexo .== 1))")
        println("    Feminino (2): $(count(df_ano.sexo .== 2))")

        if any(df_ano.sexo .∉ Ref([1, 2]))
            @warn "$ano: Valores de sexo fora de 1/2!"
        end
    end

    # 3. Proporção de servidores
    println("\n3. Proporção de servidores públicos:")
    for ano in [2011, 2023]
        df_ano = ano == 2011 ? df_2011 : df_2023
        prop_serv = count(df_ano.servidor_publico) / nrow(df_ano) * 100
        pop_serv = sum(df_ano.peso[df_ano.servidor_publico]) / 1_000_000

        println("  $ano: $(round(prop_serv, digits=1))% ($(round(pop_serv, digits=1)) milhões)")
    end

    # 4. Tendências esperadas
    println("\n4. Verificando tendências (2011 → 2023):")

    for sexo_val in [1, 2]
        sexo_label = sexo_val == 1 ? "Masculino" : "Feminino"

        # Jovens (25 anos) - espera-se redução
        tab_25 = filter(row -> row.sexo == sexo_val && row.idade == 25 && row.grupo == "Geral", tabua)
        if nrow(tab_25) == 2
            mudanca = tab_25[2, :prop_com_conjuge] - tab_25[1, :prop_com_conjuge]
            println("  $sexo_label, 25 anos: $(round(mudanca, digits=1)) pp")
            if mudanca > 5
                @warn "Aumento inesperado em jovens (esperado redução)"
            end
        end

        # Adultos (45 anos) - espera-se estabilidade ou leve redução
        tab_45 = filter(row -> row.sexo == sexo_val && row.idade == 45 && row.grupo == "Geral", tabua)
        if nrow(tab_45) == 2
            mudanca = tab_45[2, :prop_com_conjuge] - tab_45[1, :prop_com_conjuge]
            println("  $sexo_label, 45 anos: $(round(mudanca, digits=1)) pp")
            if abs(mudanca) > 10
                @warn "Mudança muito grande (> 10 pp) - verificar"
            end
        end
    end

    println("\n" * "="^50)
end
```

## Script Completo de Harmonização

### `scripts/harmonizar_2011_2023.jl`

```julia
#!/usr/bin/env julia
# Pipeline completo de harmonização PNAD 2011 + PNADC 2023

using CSV
using DataFrames
using Plots

include("../lib/pnad2011_functions.jl")
include("../lib/pnadc2023_functions.jl")

println("=== Harmonização PNAD 2011 + PNADC 2023 ===\n")

# 1. Ler dados
println("1. Lendo dados...")
df_2011 = CSV.read("dados/pnad2011_processado.csv", DataFrame)
df_2023 = CSV.read("dados/pnadc2023_processado.csv", DataFrame)

# 2. Padronizar
println("\n2. Padronizando variáveis...")
padronizar_variaveis!(df_2011, "PNAD2011")
padronizar_variaveis!(df_2023, "PNADC2023")

# 3. Filtrar
println("\n3. Aplicando filtros comuns...")
aplicar_filtros_harmonizacao!(df_2011)
aplicar_filtros_harmonizacao!(df_2023)

# 4. Empilhar
println("\n4. Empilhando bases...")
df_harmonizado = empilhar_bases(df_2011, df_2023)

# 5. Calcular tábuas
println("\n5. Calculando tábuas temporais...")
tabua_temporal = calcular_tabua_temporal(df_harmonizado)

# 6. Salvar
println("\n6. Salvando resultados...")
CSV.write("resultados/tabua_temporal_2011_2023.csv", tabua_temporal)

# 7. Projeções
println("\n7. Gerando projeções 2024-2040...")
projecoes = projetar_conjugalidade_suavizada(tabua_temporal, collect(2024:2040))
CSV.write("resultados/projecoes_2024_2040.csv", projecoes)

# 8. Validação
println("\n8. Validação...")
validar_harmonizacao(df_2011, df_2023, tabua_temporal)

# 9. Visualizações
println("\n9. Gerando gráficos...")
plotar_tendencia_temporal(tabua_temporal)

println("\n✅ Harmonização completa!")
```

## Referências

- IBGE. *Comparabilidade entre PNAD e PNAD Contínua - Notas Técnicas*.
- Preston, S. H., Heuveline, P., & Guillot, M. (2001). *Demography: Measuring and Modeling Population Processes*. (Métodos de projeção)

---

**Última atualização**: 2025-10-17
**Status**: ✅ Metodologia definida - Implementar após download de dados
