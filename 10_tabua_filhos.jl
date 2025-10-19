#!/usr/bin/env julia
# Script para calcular tábuas de filhos (população geral vs servidores)
# Calcula prevalência, idade do filho mais novo e número de filhos

using CSV
using DataFrames
using Statistics
using Printf

println("=" ^ 70)
println("TÁBUAS DE FILHOS - População Geral vs Servidores")
println("=" ^ 70)

# ============================================================================
# CARREGAR DADOS
# ============================================================================

DADOS_DIR = "dados"
RESULTADOS_DIR = "resultados"
ARQUIVO_ENTRADA = joinpath(DADOS_DIR, "pnadc_2023_filhos.csv")
ARQUIVO_SAIDA = joinpath(RESULTADOS_DIR, "tabua_filhos.csv")

if !isfile(ARQUIVO_ENTRADA)
    println("\nERRO: Arquivo não encontrado: $ARQUIVO_ENTRADA")
    println("Execute primeiro: julia --project=. 11_processar_filhos.jl")
    exit(1)
end

# Criar diretório de resultados se não existir
if !isdir(RESULTADOS_DIR)
    mkdir(RESULTADOS_DIR)
end

println("\nCarregando dados de filhos...")
df = CSV.read(ARQUIVO_ENTRADA, DataFrame,
              types=Dict(:domicilio_id => String, :pessoa_id => String))
println("✓ Dados carregados: $(nrow(df)) responsáveis/cônjuges")

# ============================================================================
# FUNÇÕES DE CÁLCULO
# ============================================================================

function calcular_metricas_por_grupo(dados::DataFrame)
    """
    Calcula métricas ponderadas para um grupo específico.

    Retorna NamedTuple com:
    - prev_filho: P(ter filho ≤ 24) em %
    - idade_filho_media: idade média do filho mais novo
    - idade_filho_sd: desvio-padrão da idade do filho mais novo
    - n_filhos_media: número médio de filhos ≤ 24
    - n_amostra: tamanho amostral
    - n_pond: população ponderada
    """
    if nrow(dados) == 0
        return (
            prev_filho = 0.0,
            idade_filho_media = missing,
            idade_filho_sd = missing,
            n_filhos_media = 0.0,
            n_amostra = 0,
            n_pond = 0.0
        )
    end

    # População total ponderada
    n_pond = sum(dados.peso)
    n_amostra = nrow(dados)

    # 1. Prevalência de ter filho ≤ 24
    n_com_filho = sum(dados.peso[dados.tem_filho_dep])
    prev_filho = 100.0 * n_com_filho / n_pond

    # 2. Número médio de filhos (todos, incluindo zero)
    n_filhos_media = sum(dados.peso .* dados.n_filhos_dep) / n_pond

    # 3. Idade do filho mais novo (apenas quem tem filho)
    dados_com_filho = dropmissing(dados, :idade_filho_mais_novo)

    if nrow(dados_com_filho) > 0
        # Média ponderada
        idade_filho_media = sum(dados_com_filho.peso .* dados_com_filho.idade_filho_mais_novo) /
                           sum(dados_com_filho.peso)

        # Desvio-padrão ponderado
        # Var(X) = E[X²] - E[X]²
        ex2 = sum(dados_com_filho.peso .* dados_com_filho.idade_filho_mais_novo.^2) /
              sum(dados_com_filho.peso)
        variancia = ex2 - idade_filho_media^2
        idade_filho_sd = sqrt(max(0.0, variancia))  # max para evitar -0.0 por erros numéricos
    else
        idade_filho_media = missing
        idade_filho_sd = missing
    end

    return (
        prev_filho = prev_filho,
        idade_filho_media = idade_filho_media,
        idade_filho_sd = idade_filho_sd,
        n_filhos_media = n_filhos_media,
        n_amostra = n_amostra,
        n_pond = n_pond
    )
end

# ============================================================================
# CALCULAR TÁBUAS POR IDADE E SEXO
# ============================================================================

println("\n" * "=" ^ 70)
println("CALCULANDO TÁBUAS (IDADE × SEXO × GRUPO)")
println("=" ^ 70)

resultado = DataFrame()

# Idades de 15 a 90 anos
IDADES = 15:90

# Processar por sexo
for sexo_num in [1, 2]
    sexo_nome = sexo_num == 1 ? "Masculino" : "Feminino"

    println("\n📊 Processando: $sexo_nome")
    println("─" ^ 70)

    # Filtrar dados do sexo
    dados_sexo = filter(row -> row.sexo == sexo_num, df)

    for idade in IDADES
        # Filtrar por idade
        dados_idade = filter(row -> row.idade == idade, dados_sexo)

        # Separar por grupo
        dados_geral = filter(row -> !row.servidor, dados_idade)
        dados_serv = filter(row -> row.servidor, dados_idade)

        # Calcular métricas
        metricas_geral = calcular_metricas_por_grupo(dados_geral)
        metricas_serv = calcular_metricas_por_grupo(dados_serv)

        # Adicionar ao resultado
        push!(resultado, (
            idade = idade,
            sexo = sexo_nome,

            # População geral
            prev_filho_geral = metricas_geral.prev_filho,
            idade_filho_media_geral = metricas_geral.idade_filho_media,
            idade_filho_sd_geral = metricas_geral.idade_filho_sd,
            n_filhos_media_geral = metricas_geral.n_filhos_media,
            n_geral_amostra = metricas_geral.n_amostra,
            n_geral_pond = metricas_geral.n_pond,

            # Servidores
            prev_filho_serv = metricas_serv.prev_filho,
            idade_filho_media_serv = metricas_serv.idade_filho_media,
            idade_filho_sd_serv = metricas_serv.idade_filho_sd,
            n_filhos_media_serv = metricas_serv.n_filhos_media,
            n_serv_amostra = metricas_serv.n_amostra,
            n_serv_pond = metricas_serv.n_pond,

            # Diferenças
            diff_prev = metricas_serv.prev_filho - metricas_geral.prev_filho,
            diff_n_filhos = metricas_serv.n_filhos_media - metricas_geral.n_filhos_media
        ), cols=:union)
    end

    # Estatísticas por sexo
    println("\nResumo ($sexo_nome):")

    # Prevalência média (ponderada por população)
    dados_sexo_resultado = filter(row -> row.sexo == sexo_nome, resultado)

    # População geral
    pop_geral_total = sum(dados_sexo_resultado.n_geral_pond)
    pop_geral_prev_media = sum(dados_sexo_resultado.prev_filho_geral .* dados_sexo_resultado.n_geral_pond) /
                           pop_geral_total

    # Servidores
    pop_serv_total = sum(dados_sexo_resultado.n_serv_pond)
    if pop_serv_total > 0
        pop_serv_prev_media = sum(dados_sexo_resultado.prev_filho_serv .* dados_sexo_resultado.n_serv_pond) /
                              pop_serv_total
    else
        pop_serv_prev_media = 0.0
    end

    println("  Prevalência média (tem filho ≤ 24):")
    println("    - População geral: $(round(pop_geral_prev_media, digits=1))%")
    println("    - Servidores: $(round(pop_serv_prev_media, digits=1))%")
    println("    - Diferença: $(round(pop_serv_prev_media - pop_geral_prev_media, digits=1)) pp")

    # Idades com mais diferença
    diffs_abs = abs.(dados_sexo_resultado.diff_prev)
    idx_max = argmax(diffs_abs)
    idade_max_diff = dados_sexo_resultado.idade[idx_max]
    max_diff = dados_sexo_resultado.diff_prev[idx_max]

    println("\n  Maior diferença serv-geral:")
    println("    - Idade: $idade_max_diff anos")
    println("    - Diferença: $(round(max_diff, digits=1)) pp")
end

# ============================================================================
# ESTATÍSTICAS GERAIS
# ============================================================================

println("\n" * "=" ^ 70)
println("ESTATÍSTICAS GERAIS")
println("=" ^ 70)

# Por grupo (agregado)
for grupo in ["População geral", "Servidores"]
    eh_servidor = grupo == "Servidores"

    if eh_servidor
        pop_total = sum(resultado.n_serv_pond)
        prev_media = pop_total > 0 ?
                     sum(resultado.prev_filho_serv .* resultado.n_serv_pond) / pop_total : 0.0
    else
        pop_total = sum(resultado.n_geral_pond)
        prev_media = sum(resultado.prev_filho_geral .* resultado.n_geral_pond) / pop_total
    end

    println("\n$grupo:")
    println("  - População total: $(round(pop_total/1_000_000, digits=2))M")
    println("  - Prevalência média: $(round(prev_media, digits=1))%")
end

# Idades com maior prevalência
println("\nIdades com maior prevalência (população geral):")
for sexo in ["Masculino", "Feminino"]
    dados_sexo = filter(row -> row.sexo == sexo, resultado)
    idx_max = argmax(dados_sexo.prev_filho_geral)

    println("  $sexo: $(dados_sexo.idade[idx_max]) anos ($(round(dados_sexo.prev_filho_geral[idx_max], digits=1))%)")
end

# Qualidade dos dados de servidores
println("\nQualidade dos dados de servidores:")
n_serv_positivo = count(resultado.n_serv_amostra .> 0)
n_serv_30plus = count(resultado.n_serv_amostra .>= 30)
n_serv_100plus = count(resultado.n_serv_amostra .>= 100)

println("  - Idades com n > 0: $n_serv_positivo/$(nrow(resultado)) ($(round(100*n_serv_positivo/nrow(resultado), digits=1))%)")
println("  - Idades com n ≥ 30: $n_serv_30plus/$(nrow(resultado)) ($(round(100*n_serv_30plus/nrow(resultado), digits=1))%)")
println("  - Idades com n ≥ 100: $n_serv_100plus/$(nrow(resultado)) ($(round(100*n_serv_100plus/nrow(resultado), digits=1))%)")

# Médias amostrais de servidores
serv_com_dados = filter(row -> row.n_serv_amostra > 0, resultado)
if nrow(serv_com_dados) > 0
    println("  - n médio (quando > 0): $(round(mean(serv_com_dados.n_serv_amostra), digits=1))")
    println("  - n mediano: $(median(serv_com_dados.n_serv_amostra))")
end

# ============================================================================
# SALVAR RESULTADO
# ============================================================================

println("\n" * "=" ^ 70)
println("Salvando resultado: $ARQUIVO_SAIDA")
CSV.write(ARQUIVO_SAIDA, resultado)

println("\n" * "=" ^ 70)
println("✓ Tábuas calculadas com sucesso!")
println("=" ^ 70)
println("\nPróximos passos:")
println("  julia --project=. 13_credibilidade_filhos.jl")
println("=" ^ 70)
