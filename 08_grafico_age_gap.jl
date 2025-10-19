#!/usr/bin/env julia
# Gráficos de Age Gap - População Geral vs Servidores
# Diferença de idade entre pessoa de referência e cônjuge

using CSV
using DataFrames
using Plots
using Statistics

println("=" ^ 70)
println("Gráficos de Age Gap - População Geral vs Servidores")
println("=" ^ 70)

# Carregar dados
RESULTADOS_DIR = "resultados"
GRAFICOS_DIR = joinpath(RESULTADOS_DIR, "graficos")
mkpath(GRAFICOS_DIR)

arquivo_obs = joinpath(RESULTADOS_DIR, "age_gap_observado.csv")
arquivo_cred = joinpath(RESULTADOS_DIR, "age_gap_credivel.csv")

if !isfile(arquivo_obs)
    println("\nERRO: Arquivo não encontrado: $arquivo_obs")
    println("Execute primeiro: julia 09_age_gap_servidores.jl")
    exit(1)
end

if !isfile(arquivo_cred)
    println("\nERRO: Arquivo não encontrado: $arquivo_cred")
    println("Execute primeiro: julia 09_age_gap_servidores.jl")
    exit(1)
end

println("\nCarregando dados...")
df_obs = CSV.read(arquivo_obs, DataFrame)
df_cred = CSV.read(arquivo_cred, DataFrame)

println("✓ Dados observados carregados: $(nrow(df_obs)) registros")
println("✓ Dados credíveis carregados: $(nrow(df_cred)) registros")

# Configurações de plot
theme(:default)
default(
    fontfamily="DejaVu Sans",
    titlefontsize=11,
    guidefontsize=10,
    tickfontsize=9,
    legendfontsize=8,
    linewidth=0,  # Sem linhas nos scatter
    markersize=4,
    markerstrokewidth=0,
    dpi=150,
    size=(850, 520),
    left_margin=5Plots.mm,
    right_margin=8Plots.mm,
    top_margin=3Plots.mm,
    bottom_margin=5Plots.mm,
    legend_background_color=RGBA(1, 1, 1, 0.8),
    legend_foreground_color=:gray50,
    framestyle=:box
)

# === GRÁFICO 1: MASCULINO ===

println("\nGerando gráfico: Masculino...")

dados_masc_obs = filter(row -> row.sexo == "Masculino", df_obs)
dados_masc_cred = filter(row -> row.sexo == "Masculino", df_cred)

# Filtrar valores válidos (não NaN)
filter!(row -> !isnan(row.agegap_geral), dados_masc_obs)
dados_serv_masc = filter(row -> !isnan(row.agegap_serv), dados_masc_obs)
filter!(row -> !isnan(row.agegap_suavizado), dados_masc_cred)

p1 = scatter(
    dados_masc_obs.idade,
    dados_masc_obs.agegap_geral,
    label="Geral",
    color=:steelblue,
    alpha=0.7,
    xlabel="Idade da Referência",
    ylabel="Age Gap (anos)",
    title="Age Gap Médio - Masculino",
    legend=:topright,
    grid=true,
    gridalpha=0.3
)

# Servidores observados
if nrow(dados_serv_masc) > 0
    scatter!(
        p1,
        dados_serv_masc.idade,
        dados_serv_masc.agegap_serv,
        label="Servidores (obs)",
        color=:coral,
        alpha=0.7
    )
end

# Servidores suavizados
if nrow(dados_masc_cred) > 0
    plot!(
        p1,
        dados_masc_cred.idade,
        dados_masc_cred.agegap_suavizado,
        label="Servidores (suavizado)",
        color=:darkorange,
        linewidth=2.5,
        alpha=0.9
    )
end

# Linha de referência (age gap = 0)
hline!(p1, [0], color=:gray, linestyle=:dash, linewidth=1, label=nothing, alpha=0.5)

# Salvar
arquivo_masc = joinpath(GRAFICOS_DIR, "age_gap_masculino.png")
savefig(p1, arquivo_masc)
println("  ✓ $arquivo_masc")

# === GRÁFICO 2: FEMININO ===

println("Gerando gráfico: Feminino...")

dados_fem_obs = filter(row -> row.sexo == "Feminino", df_obs)
dados_fem_cred = filter(row -> row.sexo == "Feminino", df_cred)

# Filtrar valores válidos (não NaN)
filter!(row -> !isnan(row.agegap_geral), dados_fem_obs)
dados_serv_fem = filter(row -> !isnan(row.agegap_serv), dados_fem_obs)
filter!(row -> !isnan(row.agegap_suavizado), dados_fem_cred)

p2 = scatter(
    dados_fem_obs.idade,
    dados_fem_obs.agegap_geral,
    label="Geral",
    color=:steelblue,
    alpha=0.7,
    xlabel="Idade da Referência",
    ylabel="Age Gap (anos)",
    title="Age Gap Médio - Feminino",
    legend=:topright,
    grid=true,
    gridalpha=0.3
)

# Servidores observados
if nrow(dados_serv_fem) > 0
    scatter!(
        p2,
        dados_serv_fem.idade,
        dados_serv_fem.agegap_serv,
        label="Servidores (obs)",
        color=:coral,
        alpha=0.7
    )
end

# Servidores suavizados
if nrow(dados_fem_cred) > 0
    plot!(
        p2,
        dados_fem_cred.idade,
        dados_fem_cred.agegap_suavizado,
        label="Servidores (suavizado)",
        color=:darkorange,
        linewidth=2.5,
        alpha=0.9
    )
end

# Linha de referência (age gap = 0)
hline!(p2, [0], color=:gray, linestyle=:dash, linewidth=1, label=nothing, alpha=0.5)

# Salvar
arquivo_fem = joinpath(GRAFICOS_DIR, "age_gap_feminino.png")
savefig(p2, arquivo_fem)
println("  ✓ $arquivo_fem")

# === RESUMO ESTATÍSTICO ===

println("\n" * "=" ^ 70)
println("RESUMO ESTATÍSTICO")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    println("\n$sexo:")

    # Observado
    dados_obs_sexo = filter(row -> row.sexo == sexo, df_obs)
    dados_geral = filter(row -> !isnan(row.agegap_geral), dados_obs_sexo)
    dados_serv = filter(row -> !isnan(row.agegap_serv), dados_obs_sexo)

    if nrow(dados_geral) > 0
        println("  Geral:")
        println("    Média: $(round(mean(dados_geral.agegap_geral), digits=2)) anos")
        println("    Min/Max: $(round(minimum(dados_geral.agegap_geral), digits=1)) / $(round(maximum(dados_geral.agegap_geral), digits=1)) anos")
    end

    if nrow(dados_serv) > 0
        println("  Servidores (observado):")
        println("    Média: $(round(mean(dados_serv.agegap_serv), digits=2)) anos")
        println("    Min/Max: $(round(minimum(dados_serv.agegap_serv), digits=1)) / $(round(maximum(dados_serv.agegap_serv), digits=1)) anos")
    end

    # Suavizado
    dados_cred_sexo = filter(row -> row.sexo == sexo && !isnan(row.agegap_suavizado), df_cred)
    if nrow(dados_cred_sexo) > 0
        println("  Servidores (suavizado):")
        println("    Média: $(round(mean(dados_cred_sexo.agegap_suavizado), digits=2)) anos")
        println("    Min/Max: $(round(minimum(dados_cred_sexo.agegap_suavizado), digits=1)) / $(round(maximum(dados_cred_sexo.agegap_suavizado), digits=1)) anos")
        println("    Z médio: $(round(mean(dados_cred_sexo.Z_credibilidade), digits=3))")
    end
end

println("\n" * "=" ^ 70)
println("Interpretação:")
println("=" ^ 70)

println("""
Age Gap = idade_referência - idade_cônjuge

• Valor positivo: pessoa de referência é mais velha
• Valor negativo: cônjuge é mais velho
• Valor zero: mesma idade

A linha laranja mostra o age gap estabilizado pela credibilidade,
corrigindo volatilidade em idades com poucos dados.
""")

println("\n" * "=" ^ 70)
println("Gráficos gerados com sucesso!")
println("=" ^ 70)
