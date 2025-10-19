#!/usr/bin/env julia
# Gráfico Simplificado - Prevalências Observadas
# Foco: Proporção de casados por idade e sexo

using CSV
using DataFrames
using Plots
using Statistics

println("=" ^ 70)
println("Gráfico de Prevalências Observadas - Simplificado")
println("=" ^ 70)

# Carregar dados
RESULTADOS_DIR = "resultados"
GRAFICOS_DIR = joinpath(RESULTADOS_DIR, "graficos")
arquivo = joinpath(RESULTADOS_DIR, "tabua_conjugalidade.csv")

if !isfile(arquivo)
    println("\nERRO: Arquivo não encontrado: $arquivo")
    println("Execute primeiro: julia 02_tabua_conjugalidade.jl")
    exit(1)
end

# Criar diretório de gráficos
mkpath(GRAFICOS_DIR)

println("\nCarregando dados...")
df = CSV.read(arquivo, DataFrame)

# Carregar dados de credibilidade (se disponível)
arquivo_credivel = joinpath(RESULTADOS_DIR, "conjugalidade_credivel.csv")
tem_credibilidade = isfile(arquivo_credivel)

if tem_credibilidade
    println("Carregando estimativas credíveis...")
    df_credivel = CSV.read(arquivo_credivel, DataFrame)
else
    println("⚠️  Estimativas credíveis não encontradas. Execute: julia 08_credibilidade_servidores.jl")
    df_credivel = nothing
end

# Configurações de plot
theme(:default)
default(
    fontfamily="DejaVu Sans",  # Fonte mais comum em Linux
    titlefontsize=11,
    guidefontsize=10,
    tickfontsize=9,
    legendfontsize=8,
    linewidth=0,  # Sem linhas, só pontos
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

dados_masc = filter(row -> row.sexo == "Masculino", df)

p1 = scatter(
    dados_masc.idade,
    dados_masc.prop_geral,
    label="Geral",
    color=:steelblue,
    alpha=0.7,
    xlabel="Idade",
    ylabel="Proporção Casados (%)",
    title="Prevalência de Casados - Masculino",
    legend=:topleft,
    grid=true,
    gridalpha=0.3
)

scatter!(
    p1,
    dados_masc.idade,
    dados_masc.prop_servidores,
    label="Servidores (obs)",
    color=:coral,
    alpha=0.7
)

# Adicionar curva suavizada (se disponível)
if tem_credibilidade
    dados_cred_masc = filter(row -> row.sexo == "Masculino", df_credivel)
    plot!(
        p1,
        dados_cred_masc.idade,
        dados_cred_masc.P_suavizado,
        label="Servidores (suavizado)",
        color=:darkorange,
        linewidth=2.5,
        alpha=0.9
    )
end

# Salvar
arquivo_masc = joinpath(GRAFICOS_DIR, "prevalencia_masculino.png")
savefig(p1, arquivo_masc)
println("  ✓ $arquivo_masc")

# === GRÁFICO 2: FEMININO ===
println("Gerando gráfico: Feminino...")

dados_fem = filter(row -> row.sexo == "Feminino", df)

p2 = scatter(
    dados_fem.idade,
    dados_fem.prop_geral,
    label="Geral",
    color=:steelblue,
    alpha=0.7,
    xlabel="Idade",
    ylabel="Proporção Casados (%)",
    title="Prevalência de Casados - Feminino",
    legend=:topleft,
    grid=true,
    gridalpha=0.3
)

scatter!(
    p2,
    dados_fem.idade,
    dados_fem.prop_servidores,
    label="Servidores (obs)",
    color=:coral,
    alpha=0.7
)

# Adicionar curva suavizada (se disponível)
if tem_credibilidade
    dados_cred_fem = filter(row -> row.sexo == "Feminino", df_credivel)
    plot!(
        p2,
        dados_cred_fem.idade,
        dados_cred_fem.P_suavizado,
        label="Servidores (suavizado)",
        color=:darkorange,
        linewidth=2.5,
        alpha=0.9
    )
end

# Salvar
arquivo_fem = joinpath(GRAFICOS_DIR, "prevalencia_feminino.png")
savefig(p2, arquivo_fem)
println("  ✓ $arquivo_fem")

# === RESUMO ESTATÍSTICO ===
println("\n" * "=" ^ 70)
println("RESUMO ESTATÍSTICO")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados = filter(row -> row.sexo == sexo, df)

    println("\n$sexo:")

    # Prevalência máxima
    idx_max_geral = argmax(dados.prop_geral)
    idx_max_serv = argmax(dados.prop_servidores)

    println("  Geral:")
    println("    Pico: $(round(dados[idx_max_geral, :prop_geral], digits=1))% aos $(dados[idx_max_geral, :idade]) anos")
    println("    Média (15-90): $(round(mean(dados.prop_geral), digits=1))%")

    println("  Servidores:")
    println("    Pico: $(round(dados[idx_max_serv, :prop_servidores], digits=1))% aos $(dados[idx_max_serv, :idade]) anos")
    println("    Média (15-90): $(round(mean(dados.prop_servidores), digits=1))%")

    # Diferença média
    diferenca_media = mean(filter(!isnan, dados.diferenca_pp))
    println("  Diferença média (Serv - Geral): $(round(diferenca_media, digits=1)) pp")

    # Estatísticas suavizadas (se disponível)
    if tem_credibilidade
        dados_cred = filter(row -> row.sexo == sexo, df_credivel)
        println("  Servidores (suavizado):")
        idx_max_suav = argmax(dados_cred.P_suavizado)
        println("    Pico: $(round(dados_cred[idx_max_suav, :P_suavizado], digits=1))% aos $(dados_cred[idx_max_suav, :idade]) anos")
        println("    Média (15-90): $(round(mean(dados_cred.P_suavizado), digits=1))%")
        println("    Z médio: $(round(mean(dados_cred.Z_credibilidade), digits=3))")
    end
end

println("\n" * "=" ^ 70)
println("Gráficos gerados com sucesso!")
println("=" ^ 70)
