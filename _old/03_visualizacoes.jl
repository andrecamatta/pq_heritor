#!/usr/bin/env julia
# Visualizações da Tábua de Conjugalidade
# Gráficos comparativos entre população geral e servidores públicos

using CSV
using DataFrames
using Plots
using StatsPlots

println("=" ^ 70)
println("Gerando Visualizações - Tábua de Conjugalidade")
println("=" ^ 70)

# Configuração dos gráficos
gr()  # Backend GR
default(
    fontfamily = "Computer Modern",
    linewidth = 2,
    framestyle = :box,
    label = nothing,
    grid = true,
    gridstyle = :dot,
    gridalpha = 0.3
)

# Carregar resultados
RESULTADOS_DIR = "resultados"
GRAFICOS_DIR = joinpath(RESULTADOS_DIR, "graficos")
mkpath(GRAFICOS_DIR)

arquivo_resultados = joinpath(RESULTADOS_DIR, "tabua_conjugalidade.csv")

if !isfile(arquivo_resultados)
    println("\nERRO: Arquivo não encontrado: $arquivo_resultados")
    println("Execute primeiro: julia 02_tabua_conjugalidade.jl")
    exit(1)
end

println("\nCarregando resultados...")
df = CSV.read(arquivo_resultados, DataFrame)

# Separar por sexo
df_masc = filter(row -> row.sexo == "Masculino", df)
df_fem = filter(row -> row.sexo == "Feminino", df)

println("Dados carregados: $(nrow(df)) registros")
println("  Masculino: $(nrow(df_masc))")
println("  Feminino: $(nrow(df_fem))")

# === GRÁFICO 1: Linhas - Proporção de casados por idade (Masculino) ===
println("\n📈 Gerando gráfico 1: Linhas (Masculino)...")

p1 = plot(
    df_masc.idade,
    df_masc.prop_geral,
    label = "População Geral",
    color = :steelblue,
    linewidth = 2.5,
    title = "Proporção de Casados/União Estável - Masculino",
    xlabel = "Idade (anos)",
    ylabel = "Proporção (%)",
    legend = :topleft,
    size = (1000, 600),
    dpi = 150,
    margin = 8Plots.mm,
    xlims = (15, 90),
    ylims = (0, 100)
)

plot!(
    p1,
    df_masc.idade,
    df_masc.prop_servidores,
    label = "Servidores Públicos",
    color = :darkorange,
    linewidth = 2.5
)

savefig(p1, joinpath(GRAFICOS_DIR, "01_linha_masculino.png"))
println("✅ Salvo: 01_linha_masculino.png")

# === GRÁFICO 2: Linhas - Proporção de casados por idade (Feminino) ===
println("\n📈 Gerando gráfico 2: Linhas (Feminino)...")

p2 = plot(
    df_fem.idade,
    df_fem.prop_geral,
    label = "População Geral",
    color = :mediumpurple,
    linewidth = 2.5,
    title = "Proporção de Casados/União Estável - Feminino",
    xlabel = "Idade (anos)",
    ylabel = "Proporção (%)",
    legend = :topleft,
    size = (1000, 600),
    dpi = 150,
    margin = 8Plots.mm,
    xlims = (15, 90),
    ylims = (0, 100)
)

plot!(
    p2,
    df_fem.idade,
    df_fem.prop_servidores,
    label = "Servidores Públicos",
    color = :crimson,
    linewidth = 2.5
)

savefig(p2, joinpath(GRAFICOS_DIR, "02_linha_feminino.png"))
println("✅ Salvo: 02_linha_feminino.png")

# === GRÁFICO 3: Comparação Direta - Ambos os Sexos ===
println("\n📊 Gerando gráfico 3: Comparação ambos os sexos...")

p3 = plot(
    df_masc.idade,
    df_masc.prop_geral,
    label = "Geral - Masculino",
    color = :steelblue,
    linewidth = 2,
    linestyle = :solid,
    title = "Tábua de Conjugalidade - Comparação Completa",
    xlabel = "Idade (anos)",
    ylabel = "Proporção de Casados/União (%)",
    legend = :right,
    size = (1200, 700),
    dpi = 150,
    margin = 8Plots.mm,
    xlims = (15, 90),
    ylims = (0, 100)
)

plot!(p3, df_masc.idade, df_masc.prop_servidores,
    label = "Servidores - Masculino", color = :darkorange, linewidth = 2.5)
plot!(p3, df_fem.idade, df_fem.prop_geral,
    label = "Geral - Feminino", color = :mediumpurple, linewidth = 2, linestyle = :solid)
plot!(p3, df_fem.idade, df_fem.prop_servidores,
    label = "Servidores - Feminino", color = :crimson, linewidth = 2.5)

savefig(p3, joinpath(GRAFICOS_DIR, "03_comparacao_completa.png"))
println("✅ Salvo: 03_comparacao_completa.png")

# === GRÁFICO 4: Diferença em pontos percentuais ===
println("\n📊 Gerando gráfico 4: Diferença entre grupos...")

p4 = plot(
    df_masc.idade,
    df_masc.diferenca_pp,
    label = "Masculino",
    color = :steelblue,
    linewidth = 2.5,
    title = "Diferença: Servidores - População Geral (pp)",
    xlabel = "Idade (anos)",
    ylabel = "Diferença (pontos percentuais)",
    legend = :topright,
    size = (1000, 600),
    dpi = 150,
    margin = 8Plots.mm,
    xlims = (15, 90)
)

plot!(
    p4,
    df_fem.idade,
    df_fem.diferenca_pp,
    label = "Feminino",
    color = :mediumpurple,
    linewidth = 2.5
)

hline!(p4, [0], color = :black, linestyle = :dash, linewidth = 1, label = nothing)

savefig(p4, joinpath(GRAFICOS_DIR, "04_diferenca_pp.png"))
println("✅ Salvo: 04_diferenca_pp.png")

# === GRÁFICO 5: Painel comparativo (2x2) ===
println("\n📊 Gerando gráfico 5: Painel comparativo...")

# Masculino - Geral
p5a = plot(
    df_masc.idade,
    df_masc.prop_geral,
    label = nothing,
    color = :steelblue,
    linewidth = 2,
    title = "Masculino - População Geral",
    ylabel = "Proporção (%)",
    xlims = (15, 90),
    ylims = (0, 100)
)

# Masculino - Servidores
p5b = plot(
    df_masc.idade,
    df_masc.prop_servidores,
    label = nothing,
    color = :darkorange,
    linewidth = 2,
    title = "Masculino - Servidores",
    xlims = (15, 90),
    ylims = (0, 100)
)

# Feminino - Geral
p5c = plot(
    df_fem.idade,
    df_fem.prop_geral,
    label = nothing,
    color = :mediumpurple,
    linewidth = 2,
    title = "Feminino - População Geral",
    xlabel = "Idade (anos)",
    ylabel = "Proporção (%)",
    xlims = (15, 90),
    ylims = (0, 100)
)

# Feminino - Servidores
p5d = plot(
    df_fem.idade,
    df_fem.prop_servidores,
    label = nothing,
    color = :crimson,
    linewidth = 2,
    title = "Feminino - Servidores",
    xlabel = "Idade (anos)",
    xlims = (15, 90),
    ylims = (0, 100)
)

p5 = plot(
    p5a, p5b, p5c, p5d,
    layout = (2, 2),
    size = (1400, 1000),
    dpi = 150,
    margin = 6Plots.mm,
    plot_title = "Painel Comparativo - Conjugalidade por Sexo e Grupo"
)

savefig(p5, joinpath(GRAFICOS_DIR, "05_painel_comparativo.png"))
println("✅ Salvo: 05_painel_comparativo.png")

# === RESUMO ===
println("\n" * "=" ^ 70)
println("VISUALIZAÇÕES GERADAS COM SUCESSO!")
println("=" ^ 70)
println("\nArquivos salvos em: $GRAFICOS_DIR/")
println("  1. 01_linha_masculino.png")
println("  2. 02_linha_feminino.png")
println("  3. 03_comparacao_completa.png")
println("  4. 04_diferenca_pp.png")
println("  5. 05_painel_comparativo.png")
println("\n" * "=" ^ 70)
