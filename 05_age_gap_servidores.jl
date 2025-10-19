#!/usr/bin/env julia
# Análise de Age Gap - População Geral vs Servidores Públicos
# Age gap: Diferença de idade entre pessoa de referência e cônjuge
# Essencial para função heritor (idade esperada do beneficiário de pensão)

using CSV
using DataFrames
using Statistics
using StatsBase

# Importar módulos compartilhados
include("src/Credibilidade.jl")
include("src/AgeGap.jl")
using .Credibilidade
using .AgeGap

println("=" ^ 70)
println("Age Gap: População Geral vs Servidores Públicos")
println("=" ^ 70)

# Configurações
DADOS_DIR = "dados"
RESULTADOS_DIR = "resultados"
mkpath(RESULTADOS_DIR)

arquivo_dados = joinpath(DADOS_DIR, "pnadc_2023_processado.csv")

if !isfile(arquivo_dados)
    println("\nERRO: Arquivo não encontrado: $arquivo_dados")
    println("Execute primeiro: julia 01_processar_dados.jl")
    exit(1)
end

# === CARREGAR E PREPARAR DADOS ===

println("\nCarregando dados...")
df = CSV.read(arquivo_dados, DataFrame)

println("Total de registros: $(nrow(df))")
println("Registros com peso: $(count(!ismissing, df.peso))")

# Verificar variáveis necessárias
required_vars = ["domicilio_id", "condicao_dom", "idade", "sexo", "servidor", "peso"]
missing_vars = [v for v in required_vars if !(v in names(df))]

if !isempty(missing_vars)
    println("\nERRO: Variáveis ausentes: $missing_vars")
    println("Execute primeiro: julia 01_processar_dados.jl com dados reais")
    exit(1)
end

# === EXTRAIR PARES DE CÔNJUGES ===

println("\n" * "=" ^ 70)
println("IDENTIFICANDO PARES DE CÔNJUGES")
println("=" ^ 70)

println("\nCritério: Pessoa de referência (condicao_dom=1) + Cônjuge (condicao_dom=2 ou 3)")

# Função extrair_pares_age_gap agora vem de src/AgeGap.jl (módulo compartilhado)

println("\nExtraindo pares...")
pares = extrair_pares_age_gap(df)

println("\n✓ Pares identificados: $(nrow(pares))")
println("  População estimada: $(round(sum(pares.peso) / 1_000_000, digits=2)) milhões de casais")

# Separar por grupo
pares_geral = pares
pares_serv = filter(row -> row.servidor_ref, pares)

println("\n  Servidores (referência): $(nrow(pares_serv))")
println("    População estimada: $(round(sum(pares_serv.peso) / 1_000_000, digits=2)) milhões")

# === CALCULAR AGE GAP MÉDIO POR IDADE E SEXO ===

println("\n" * "=" ^ 70)
println("CALCULANDO AGE GAP MÉDIO POR IDADE E SEXO")
println("=" ^ 70)

function calcular_age_gap_por_idade(pares::DataFrame, label::String)
    """
    Calcula age gap médio E desvio-padrão ponderados por idade e sexo da referência

    IMPORTANTE: Agora calcula μ(idade, sexo) E σ(idade, sexo) para amostragem Monte Carlo
    """

    resultados = DataFrame(
        idade = Int[],
        sexo = String[],
        age_gap_medio = Union{Float64, Missing}[],
        age_gap_sd = Union{Float64, Missing}[],  # NOVO ✨
        n_amostra = Int[],
        n_pond = Float64[]
    )

    for sexo in [1, 2]
        sexo_label = sexo == 1 ? "Masculino" : "Feminino"

        for idade in 15:90
            dados_filtro = filter(row ->
                row.sexo_ref == sexo && row.idade_ref == idade,
                pares)

            if nrow(dados_filtro) == 0
                # Sem dados para esta idade
                push!(resultados, (
                    idade = idade,
                    sexo = sexo_label,
                    age_gap_medio = missing,
                    age_gap_sd = missing,  # NOVO ✨
                    n_amostra = 0,
                    n_pond = 0.0
                ))
                continue
            end

            # Age gap médio ponderado
            age_gap_medio = sum(dados_filtro.age_gap .* dados_filtro.peso) / sum(dados_filtro.peso)

            # Desvio-padrão ponderado (NOVO ✨)
            age_gap_var = sum((dados_filtro.age_gap .- age_gap_medio).^2 .* dados_filtro.peso) / sum(dados_filtro.peso)
            age_gap_sd = sqrt(age_gap_var)

            push!(resultados, (
                idade = idade,
                sexo = sexo_label,
                age_gap_medio = age_gap_medio,
                age_gap_sd = age_gap_sd,  # NOVO ✨
                n_amostra = nrow(dados_filtro),
                n_pond = sum(dados_filtro.peso)
            ))
        end
    end

    println("\n$label:")
    println("  Idades processadas: 15-90")
    println("  Observações com dados: $(count(.!ismissing.(resultados.age_gap_medio))) / $(nrow(resultados))")
    println("  Com desvio-padrão: $(count(.!ismissing.(resultados.age_gap_sd))) / $(nrow(resultados))")  # NOVO ✨

    return resultados
end

# Calcular para ambos os grupos
println("\nProcessando população geral...")
age_gap_geral = calcular_age_gap_por_idade(pares_geral, "População Geral")

println("\nProcessando servidores...")
age_gap_serv = calcular_age_gap_por_idade(pares_serv, "Servidores")

# === ESTATÍSTICAS DESCRITIVAS ===

println("\n" * "=" ^ 70)
println("ESTATÍSTICAS DESCRITIVAS")
println("=" ^ 70)

for (dados, label) in [(pares_geral, "Geral"), (pares_serv, "Servidores")]
    if nrow(dados) == 0
        continue
    end

    age_gap_medio = sum(dados.age_gap .* dados.peso) / sum(dados.peso)
    age_gap_var = sum((dados.age_gap .- age_gap_medio).^2 .* dados.peso) / sum(dados.peso)
    age_gap_sd = sqrt(age_gap_var)

    println("\n$label:")
    println("  Média ponderada: $(round(age_gap_medio, digits=2)) anos")
    println("  Desvio-padrão: $(round(age_gap_sd, digits=2)) anos")
    println("  Mediana: $(median(dados.age_gap)) anos")
    println("  Min/Max: $(minimum(dados.age_gap)) / $(maximum(dados.age_gap)) anos")

    # Por sexo
    for sexo in [1, 2]
        sexo_label = sexo == 1 ? "Masculino" : "Feminino"
        dados_sexo = filter(row -> row.sexo_ref == sexo, dados)

        if nrow(dados_sexo) > 0
            media_sexo = sum(dados_sexo.age_gap .* dados_sexo.peso) / sum(dados_sexo.peso)
            println("    $sexo_label: $(round(media_sexo, digits=2)) anos")
        end
    end
end

# === APLICAR CREDIBILIDADE BÜHLMANN-STRAUB ===

println("\n" * "=" ^ 70)
println("MODELO DE CREDIBILIDADE BÜHLMANN-STRAUB")
println("=" ^ 70)

println("\nRacional:")
println("  • Servidores têm amostras pequenas em algumas idades")
println("  • Combinar dados de servidores com população geral (estável)")
println("  • Preservar diferença sistemática entre grupos")

# Juntar dados
df_combined = innerjoin(
    age_gap_geral,
    age_gap_serv,
    on = [:idade, :sexo],
    makeunique = true
)

rename!(df_combined,
    :age_gap_medio => :agegap_geral,
    :age_gap_sd => :sd_geral,  # NOVO ✨
    :n_amostra => :n_geral_amostra,
    :n_pond => :n_geral_pond,
    :age_gap_medio_1 => :agegap_serv_obs,
    :age_gap_sd_1 => :sd_serv_obs,  # NOVO ✨
    :n_amostra_1 => :n_serv_amostra,
    :n_pond_1 => :n_serv_pond
)

# Remover idades sem dados de servidores
filter!(row -> row.n_serv_amostra > 0, df_combined)

println("\nIdades com dados de servidores: $(nrow(df_combined))")

# Função suavizar_com_prior agora vem de src/Credibilidade.jl (módulo compartilhado)

# Aplicar credibilidade por sexo
resultados_credibilidade = DataFrame()

for sexo_label in ["Masculino", "Feminino"]
    dados_sexo = filter(row -> row.sexo == sexo_label, df_combined)

    if nrow(dados_sexo) == 0
        continue
    end

    println("\n$sexo_label:")

    # Extrair vetores (substituir missing por NaN temporariamente)
    agegap_geral = coalesce.(dados_sexo.agegap_geral, NaN)
    agegap_serv = coalesce.(dados_sexo.agegap_serv_obs, NaN)
    sd_geral = coalesce.(dados_sexo.sd_geral, NaN)  # NOVO ✨
    sd_serv = coalesce.(dados_sexo.sd_serv_obs, NaN)  # NOVO ✨
    n_serv = dados_sexo.n_serv_amostra

    # ===== CREDIBILIDADE PARA MÉDIA (μ) =====

    # 1. Estimar shift sistemático para média (Δ_μ)
    # Usar apenas idades com n >= 30
    idx_confiavel = (n_serv .>= 30) .& .!isnan.(agegap_geral) .& .!isnan.(agegap_serv)

    if sum(idx_confiavel) < 5
        println("  ⚠️  Poucos dados confiáveis (n<5). Usando Δ_μ=0")
        Δ_μ = 0.0
    else
        Δ_μ = mean(agegap_serv[idx_confiavel] .- agegap_geral[idx_confiavel])
        println("  Shift sistemático média (Δ_μ): $(round(Δ_μ, digits=2)) anos")
    end

    # 2. Ajustar prior de média
    agegap_geral_ajustado = agegap_geral .+ Δ_μ

    # ===== CREDIBILIDADE PARA SD (σ) ===== (NOVO ✨)

    # 1. Estimar shift sistemático para SD (Δ_σ)
    idx_confiavel_sd = (n_serv .>= 30) .& .!isnan.(sd_geral) .& .!isnan.(sd_serv)

    if sum(idx_confiavel_sd) < 5
        println("  ⚠️  Poucos dados para SD. Usando Δ_σ=0")
        Δ_σ = 0.0
    else
        Δ_σ = mean(sd_serv[idx_confiavel_sd] .- sd_geral[idx_confiavel_sd])
        println("  Shift sistemático SD (Δ_σ): $(round(Δ_σ, digits=2)) anos")
    end

    # 2. Ajustar prior de SD
    sd_geral_ajustado = sd_geral .+ Δ_σ
    # Garantir SD não-negativo
    sd_geral_ajustado = max.(sd_geral_ajustado, 0.1)

    # 3. Calcular parâmetro k (credibilidade - ÚNICO para μ e σ)
    k = sqrt(mean(n_serv[n_serv .> 0]))
    println("  Parâmetro k: $(round(k, digits=2))")

    # 4. Aplicar credibilidade por idade (μ E σ)
    agegap_credivel = similar(agegap_serv)
    sd_credivel = similar(sd_serv)  # NOVO ✨
    Z_valores = similar(agegap_serv)

    for i in 1:length(agegap_serv)
        if n_serv[i] == 0 || isnan(agegap_serv[i])
            # Sem dados de servidores: usar prior ajustado
            agegap_credivel[i] = agegap_geral_ajustado[i]
            sd_credivel[i] = sd_geral_ajustado[i]  # NOVO ✨
            Z_valores[i] = 0.0
        else
            # Com dados: aplicar credibilidade
            Z = n_serv[i] / (n_serv[i] + k)

            # Credibilidade para média
            agegap_credivel[i] = Z * agegap_serv[i] + (1 - Z) * agegap_geral_ajustado[i]

            # Credibilidade para SD (NOVO ✨)
            if !isnan(sd_serv[i])
                sd_credivel[i] = Z * sd_serv[i] + (1 - Z) * sd_geral_ajustado[i]
                # Garantir SD não-negativo
                sd_credivel[i] = max(sd_credivel[i], 0.1)
            else
                sd_credivel[i] = sd_geral_ajustado[i]
            end

            Z_valores[i] = Z
        end
    end

    # 5. Suavizar com prior (μ E σ)
    println("  Aplicando suavização...")

    # Suavizar MÉDIA
    agegap_credivel_union = Vector{Union{Float64, Missing}}(agegap_credivel)
    agegap_geral_ajustado_union = Vector{Union{Float64, Missing}}(agegap_geral_ajustado)

    agegap_suavizado = suavizar_com_prior(
        agegap_credivel_union,
        agegap_geral_ajustado_union,
        janela=5,
        peso_prior=0.3,
        n_iteracoes=3
    )

    # Suavizar SD (NOVO ✨)
    sd_credivel_union = Vector{Union{Float64, Missing}}(sd_credivel)
    sd_geral_ajustado_union = Vector{Union{Float64, Missing}}(sd_geral_ajustado)

    sd_suavizado = suavizar_com_prior(
        sd_credivel_union,
        sd_geral_ajustado_union,
        janela=5,
        peso_prior=0.3,
        n_iteracoes=3
    )

    # Garantir SD suavizado não-negativo
    sd_suavizado = [ismissing(s) ? missing : max(s, 0.1) for s in sd_suavizado]

    # Calcular métricas (MÉDIA)
    idx_valido = .!isnan.(agegap_serv) .& .!isnan.(agegap_suavizado)

    if sum(idx_valido) > 0
        volatilidade_obs_media = std(agegap_serv[idx_valido])
        volatilidade_suav_media = std(agegap_suavizado[idx_valido])
        reducao_media = (1 - volatilidade_suav_media / volatilidade_obs_media) * 100

        println("  Volatilidade MÉDIA observada: $(round(volatilidade_obs_media, digits=2))")
        println("  Volatilidade MÉDIA suavizada: $(round(volatilidade_suav_media, digits=2))")
        println("  Redução: $(round(reducao_media, digits=1))%")
    end

    # Calcular métricas (SD) - NOVO ✨
    idx_valido_sd = .!isnan.(sd_serv) .& .!ismissing.(sd_suavizado)

    if sum(idx_valido_sd) > 0
        volatilidade_obs_sd = std(sd_serv[idx_valido_sd])
        volatilidade_suav_sd = std([s for s in sd_suavizado[idx_valido_sd] if !ismissing(s)])
        reducao_sd = (1 - volatilidade_suav_sd / volatilidade_obs_sd) * 100

        println("  Volatilidade SD observada: $(round(volatilidade_obs_sd, digits=2))")
        println("  Volatilidade SD suavizada: $(round(volatilidade_suav_sd, digits=2))")
        println("  Redução SD: $(round(reducao_sd, digits=1))%")
    end

    # Adicionar ao resultado
    for (i, row) in enumerate(eachrow(dados_sexo))
        push!(resultados_credibilidade, (
            idade = row.idade,
            sexo = row.sexo,
            # MÉDIA
            agegap_geral = agegap_geral[i],
            agegap_serv_obs = agegap_serv[i],
            agegap_geral_ajustado = agegap_geral_ajustado[i],
            agegap_credivel = agegap_credivel[i],
            agegap_suavizado = agegap_suavizado[i],
            # SD (NOVO ✨)
            sd_geral = sd_geral[i],
            sd_serv_obs = sd_serv[i],
            sd_geral_ajustado = sd_geral_ajustado[i],
            sd_credivel = sd_credivel[i],
            sd_suavizado = sd_suavizado[i],
            # COMUM
            Z_credibilidade = Z_valores[i],
            n_serv_amostra = n_serv[i],
            n_serv_pond = row.n_serv_pond
        ))
    end
end

# === SALVAR RESULTADOS ===

println("\n" * "=" ^ 70)
println("SALVANDO RESULTADOS")
println("=" ^ 70)

# Tabela observada (ambos os grupos)
tabela_obs = DataFrame(
    idade = Int[],
    sexo = String[],
    agegap_geral = Float64[],
    agegap_serv = Float64[],
    diferenca = Float64[],
    n_geral_amostra = Int[],
    n_geral_pond = Float64[],
    n_serv_amostra = Int[],
    n_serv_pond = Float64[]
)

for sexo_label in ["Masculino", "Feminino"]
    dados_geral = filter(row -> row.sexo == sexo_label, age_gap_geral)
    dados_serv = filter(row -> row.sexo == sexo_label, age_gap_serv)

    for idade in 15:90
        row_geral = filter(r -> r.idade == idade, dados_geral)
        row_serv = filter(r -> r.idade == idade, dados_serv)

        agegap_g = nrow(row_geral) > 0 ? coalesce(row_geral[1, :age_gap_medio], NaN) : NaN
        agegap_s = nrow(row_serv) > 0 ? coalesce(row_serv[1, :age_gap_medio], NaN) : NaN

        n_g_amostra = nrow(row_geral) > 0 ? row_geral[1, :n_amostra] : 0
        n_g_pond = nrow(row_geral) > 0 ? row_geral[1, :n_pond] : 0.0
        n_s_amostra = nrow(row_serv) > 0 ? row_serv[1, :n_amostra] : 0
        n_s_pond = nrow(row_serv) > 0 ? row_serv[1, :n_pond] : 0.0

        diferenca = !isnan(agegap_s) && !isnan(agegap_g) ? agegap_s - agegap_g : NaN

        push!(tabela_obs, (
            idade, sexo_label,
            agegap_g, agegap_s, diferenca,
            n_g_amostra, n_g_pond,
            n_s_amostra, n_s_pond
        ))
    end
end

arquivo_obs = joinpath(RESULTADOS_DIR, "age_gap_observado.csv")
CSV.write(arquivo_obs, tabela_obs)
println("\n✓ Dados observados: $arquivo_obs")

# Tabela credível
arquivo_cred = joinpath(RESULTADOS_DIR, "age_gap_credivel.csv")
CSV.write(arquivo_cred, resultados_credibilidade)
println("✓ Dados credíveis: $arquivo_cred")

# === RESUMO FINAL ===

println("\n" * "=" ^ 70)
println("RESUMO - AGE GAP ANALYSIS")
println("=" ^ 70)

println("\nAge Gap Médio:")
for (dados, label) in [(pares_geral, "População Geral"), (pares_serv, "Servidores")]
    if nrow(dados) == 0
        continue
    end
    media = sum(dados.age_gap .* dados.peso) / sum(dados.peso)
    println("  $label: $(round(media, digits=2)) anos")
end

println("\nInterpretação:")
println("  • Age gap positivo: pessoa de referência é mais velha que cônjuge")
println("  • Age gap negativo: cônjuge é mais velho que pessoa de referência")

println("\nAplicação para função heritor:")
println("  • Servidor homem de 60 anos → Cônjuge esperada: ~$(60 - round(mean(filter(r -> r.sexo_ref == 1, pares_serv).age_gap))) anos")
println("  • Usada para estimar idade do beneficiário de pensão por morte")

println("\n" * "=" ^ 70)
println("Próximos passos:")
println("  julia 10_grafico_age_gap.jl")
println("=" ^ 70)
