#!/usr/bin/env julia
# Modelo de Credibilidade Bühlmann-Straub para Métricas de Filhos
# Estabiliza estimativas de servidores usando população geral como referência

using CSV
using DataFrames
using Statistics
using Printf

# Carregar módulo de credibilidade compartilhado
include("src/Credibilidade.jl")
using .Credibilidade

println("=" ^ 70)
println("MODELO DE CREDIBILIDADE - Métricas de Filhos de Servidores")
println("=" ^ 70)

# ============================================================================
# CARREGAR DADOS
# ============================================================================

RESULTADOS_DIR = "resultados"
ARQUIVO_ENTRADA = joinpath(RESULTADOS_DIR, "tabua_filhos.csv")
ARQUIVO_SAIDA = joinpath(RESULTADOS_DIR, "filhos_credivel.csv")

if !isfile(ARQUIVO_ENTRADA)
    println("\nERRO: Arquivo não encontrado: $ARQUIVO_ENTRADA")
    println("Execute primeiro: julia --project=. 12_tabua_filhos.jl")
    exit(1)
end

println("\nCarregando dados de filhos...")
df = CSV.read(ARQUIVO_ENTRADA, DataFrame)
println("Dados carregados: $(nrow(df)) registros")

# ============================================================================
# APLICAR CREDIBILIDADE POR MÉTRICA
# ============================================================================

function aplicar_credibilidade_metrica(dados_sexo::DataFrame,
                                      coluna_geral::Symbol,
                                      coluna_serv::Symbol;
                                      nome_metrica::String="métrica")
    """
    Aplica credibilidade Bühlmann-Straub + suavização para uma métrica

    Retorna: (valores_suavizados, Z_credibilidade, delta_shift, k_parametro)
    """
    println("\n" * "─" ^ 70)
    println("MÉTRICA: $nome_metrica")
    println("─" ^ 70)

    # === PASSO 1: Estimar shift sistemático Δ ===
    println("\n1. Estimando shift sistemático (Δ)...")

    # Filtrar apenas idades bem representadas (n >= 30)
    dados_bemrep = filter(row -> row.n_serv_amostra >= 30 &&
                                 !ismissing(row[coluna_geral]) &&
                                 !ismissing(row[coluna_serv]),
                          dados_sexo)

    if nrow(dados_bemrep) == 0
        println("   ⚠️  AVISO: Nenhuma idade com n >= 30 e dados válidos.")
        println("   Tentando com n >= 10...")

        dados_bemrep = filter(row -> row.n_serv_amostra >= 10 &&
                                     !ismissing(row[coluna_geral]) &&
                                     !ismissing(row[coluna_serv]),
                              dados_sexo)
    end

    if nrow(dados_bemrep) > 0
        println("   Idades bem representadas: $(nrow(dados_bemrep))")

        # Calcular diferença média
        diferencas = dados_bemrep[!, coluna_serv] .- dados_bemrep[!, coluna_geral]
        delta = mean(diferencas)

        println("   Δ = $(round(delta, digits=3))")
        println("   Desvio-padrão das diferenças: $(round(std(diferencas), digits=3))")
    else
        println("   ⚠️  AVISO: Sem dados válidos. Usando Δ = 0")
        delta = 0.0
    end

    # === PASSO 2: Calcular parâmetro k ===
    println("\n2. Calculando parâmetro de credibilidade (k)...")

    ns_positivos = filter(x -> x > 0, dados_sexo.n_serv_amostra)

    if length(ns_positivos) == 0
        println("   ⚠️  AVISO: Nenhuma observação de servidores!")
        k = 50.0
    else
        n_medio = mean(ns_positivos)
        k = sqrt(n_medio)

        println("   n médio (servidores): $(round(n_medio, digits=1))")
        println("   k = √n_medio = $(round(k, digits=2))")
    end

    # === PASSO 3: Aplicar credibilidade ===
    println("\n3. Aplicando modelo de credibilidade...")

    valores_ajustados = Float64[]
    valores_credivel = Float64[]
    Z_valores = Float64[]

    for row in eachrow(dados_sexo)
        valor_geral = row[coluna_geral]
        valor_serv = row[coluna_serv]
        n_serv = row.n_serv_amostra

        # Ajustar população geral
        valor_geral_ajustado = ismissing(valor_geral) ? 0.0 : valor_geral + delta
        push!(valores_ajustados, valor_geral_ajustado)

        # Calcular Z (credibilidade)
        Z = n_serv / (n_serv + k)
        push!(Z_valores, Z)

        # Aplicar credibilidade
        if ismissing(valor_serv) || n_serv == 0
            # Sem dados de servidores → usar população geral ajustada
            valor_cred = valor_geral_ajustado
        else
            # Combinar servidores + população geral ajustada
            valor_cred = Z * valor_serv + (1 - Z) * valor_geral_ajustado
        end

        push!(valores_credivel, valor_cred)
    end

    # === PASSO 4: Suavizar ===
    println("\n4. Suavizando com média móvel...")

    valores_suavizados = suavizar_com_prior(
        valores_credivel,
        valores_ajustados,
        janela=5,
        peso_prior=0.3,
        n_iteracoes=3
    )

    # Estatísticas
    println("\n   Estatísticas finais:")
    println("   - Z médio: $(round(mean(Z_valores), digits=3))")
    println("   - Z mínimo: $(round(minimum(Z_valores), digits=3))")
    println("   - Z máximo: $(round(maximum(Z_valores), digits=3))")
    println("   - Valor médio suavizado: $(round(mean(valores_suavizados), digits=2))")

    return (
        valores_suavizados = valores_suavizados,
        Z_credibilidade = Z_valores,
        delta_shift = delta,
        k_parametro = k
    )
end

# ============================================================================
# PROCESSAR POR SEXO
# ============================================================================

println("\n" * "=" ^ 70)
println("APLICANDO CREDIBILIDADE POR SEXO")
println("=" ^ 70)

# Inicializar DataFrame de saída
resultados = DataFrame(
    idade = Int[],
    sexo = String[],

    # Prevalência de ter filho
    prev_filho_geral = Float64[],
    prev_filho_serv_obs = Float64[],
    prev_filho_suavizado = Float64[],

    # Idade do filho mais novo
    idade_filho_geral = Float64[],
    idade_filho_serv_obs = Float64[],
    idade_filho_suavizado = Float64[],

    # Desvio-padrão da idade do filho mais novo
    idade_filho_sd_geral = Float64[],
    idade_filho_sd_serv_obs = Float64[],
    idade_filho_sd_suavizado = Float64[],

    # Número médio de filhos
    n_filhos_geral = Float64[],
    n_filhos_serv_obs = Float64[],
    n_filhos_suavizado = Float64[],

    # Metadados
    n_serv_amostra = Int[],
    Z_credibilidade = Float64[]
)

for sexo in ["Masculino", "Feminino"]
    println("\n\n" * "=" ^ 70)
    println("📊 PROCESSANDO: $sexo")
    println("=" ^ 70)

    # Filtrar dados do sexo
    dados_sexo = filter(row -> row.sexo == sexo, df)

    # === MÉTRICA 1: Prevalência de ter filho ≤ 24 ===
    resultado_prev = aplicar_credibilidade_metrica(
        dados_sexo,
        :prev_filho_geral,
        :prev_filho_serv,
        nome_metrica="Prevalência de ter filho ≤ 24 anos (%)"
    )

    # === MÉTRICA 2: Idade do filho mais novo ===
    resultado_idade = aplicar_credibilidade_metrica(
        dados_sexo,
        :idade_filho_media_geral,
        :idade_filho_media_serv,
        nome_metrica="Idade do filho mais novo (anos)"
    )

    # === MÉTRICA 3: Desvio-padrão da idade do filho mais novo ===
    resultado_idade_sd = aplicar_credibilidade_metrica(
        dados_sexo,
        :idade_filho_sd_geral,
        :idade_filho_sd_serv,
        nome_metrica="Desvio-padrão da idade do filho mais novo (anos)"
    )

    # === MÉTRICA 4: Número médio de filhos ===
    resultado_n_filhos = aplicar_credibilidade_metrica(
        dados_sexo,
        :n_filhos_media_geral,
        :n_filhos_media_serv,
        nome_metrica="Número médio de filhos ≤ 24 anos"
    )

    # === Consolidar resultados ===
    println("\n" * "─" ^ 70)
    println("CONSOLIDANDO RESULTADOS ($sexo)")
    println("─" ^ 70)

    for (i, row) in enumerate(eachrow(dados_sexo))
        push!(resultados, (
            idade = row.idade,
            sexo = sexo,

            # Prevalência
            prev_filho_geral = row.prev_filho_geral,
            prev_filho_serv_obs = row.prev_filho_serv,
            prev_filho_suavizado = resultado_prev.valores_suavizados[i],

            # Idade filho mais novo
            idade_filho_geral = coalesce(row.idade_filho_media_geral, 0.0),
            idade_filho_serv_obs = coalesce(row.idade_filho_media_serv, 0.0),
            idade_filho_suavizado = resultado_idade.valores_suavizados[i],

            # Desvio-padrão idade filho
            idade_filho_sd_geral = coalesce(row.idade_filho_sd_geral, 0.0),
            idade_filho_sd_serv_obs = coalesce(row.idade_filho_sd_serv, 0.0),
            idade_filho_sd_suavizado = resultado_idade_sd.valores_suavizados[i],

            # Número de filhos
            n_filhos_geral = row.n_filhos_media_geral,
            n_filhos_serv_obs = row.n_filhos_media_serv,
            n_filhos_suavizado = resultado_n_filhos.valores_suavizados[i],

            # Metadados (usar Z da prevalência como representativo)
            n_serv_amostra = row.n_serv_amostra,
            Z_credibilidade = resultado_prev.Z_credibilidade[i]
        ), cols=:union)
    end

    println("✓ Resultados consolidados para $sexo")
end

# ============================================================================
# ESTATÍSTICAS FINAIS
# ============================================================================

println("\n" * "=" ^ 70)
println("ESTATÍSTICAS FINAIS")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados_sexo = filter(row -> row.sexo == sexo, resultados)

    println("\n$sexo:")

    # Prevalência
    prev_media = mean(dados_sexo.prev_filho_suavizado)
    idade_pico_prev = dados_sexo.idade[argmax(dados_sexo.prev_filho_suavizado)]
    pico_prev = maximum(dados_sexo.prev_filho_suavizado)

    println("  Prevalência (ter filho ≤ 24):")
    println("    - Média: $(round(prev_media, digits=1))%")
    println("    - Pico: $(round(pico_prev, digits=1))% aos $idade_pico_prev anos")

    # Idade do filho mais novo (filtrar zeros)
    dados_com_filho = filter(row -> row.idade_filho_suavizado > 0, dados_sexo)
    if nrow(dados_com_filho) > 0
        idade_filho_media = mean(dados_com_filho.idade_filho_suavizado)
        idade_filho_sd_media = mean(dados_com_filho.idade_filho_sd_suavizado)

        println("  Idade do filho mais novo:")
        println("    - Média geral: $(round(idade_filho_media, digits=1)) anos")
        println("    - σ médio: $(round(idade_filho_sd_media, digits=1)) anos")
    end

    # Número de filhos
    n_filhos_media = mean(dados_sexo.n_filhos_suavizado)
    println("  Número médio de filhos ≤ 24: $(round(n_filhos_media, digits=2))")

    # Z médio
    Z_media = mean(dados_sexo.Z_credibilidade)
    println("  Z médio (credibilidade): $(round(Z_media, digits=3))")
end

# ============================================================================
# SALVAR RESULTADO
# ============================================================================

println("\n" * "=" ^ 70)
println("Salvando resultado: $ARQUIVO_SAIDA")
CSV.write(ARQUIVO_SAIDA, resultados)

println("\n" * "=" ^ 70)
println("✓ Credibilidade aplicada com sucesso!")
println("=" ^ 70)
println("\n📊 ARQUIVO FINAL PARA USO:")
println("  → $ARQUIVO_SAIDA")
println("\nColunas principais:")
println("  - prev_filho_suavizado: P(ter filho ≤ 24 anos) em %")
println("  - idade_filho_suavizado: E[idade do filho mais novo]")
println("  - idade_filho_sd_suavizado: σ[idade do filho mais novo] (para Monte Carlo)")
println("  - n_filhos_suavizado: E[número de filhos ≤ 24]")
println("\nPróximos passos (opcional):")
println("  julia --project=. 14_grafico_filhos.jl")
println("=" ^ 70)
