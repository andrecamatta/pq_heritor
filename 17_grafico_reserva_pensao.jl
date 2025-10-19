#!/usr/bin/env julia
# Gráficos de Reserva Matemática de Pensão
# Visualização da reserva para servidor VIVO

using CSV
using DataFrames
using Plots
using Statistics

println("=" ^ 70)
println("GRÁFICOS - Reserva Matemática de Pensão")
println("=" ^ 70)

# ============================================================================
# CONFIGURAÇÃO
# ============================================================================

# Diretórios
RESULTADOS_DIR = "resultados"
GRAFICOS_DIR = joinpath(RESULTADOS_DIR, "graficos")
ARQUIVO_RESERVA = joinpath(RESULTADOS_DIR, "reserva_pensao.csv")
ARQUIVO_ENCARGO = joinpath(RESULTADOS_DIR, "encargo_heritor.csv")

# Criar diretório de gráficos se não existir
if !isdir(GRAFICOS_DIR)
    mkpath(GRAFICOS_DIR)
end

# Configuração do Plots
gr()  # Backend GR
default(
    fontfamily="Computer Modern",
    linewidth=2,
    framestyle=:box,
    label=nothing,
    grid=true,
    size=(1000, 600),
    dpi=150
)

# ============================================================================
# CARREGAR DADOS
# ============================================================================

if !isfile(ARQUIVO_RESERVA)
    println("\nERRO: Arquivo não encontrado: $ARQUIVO_RESERVA")
    println("Execute primeiro: julia --project=. 19_calcular_reserva_pensao.jl")
    exit(1)
end

println("\nCarregando dados...")
df_reserva = CSV.read(ARQUIVO_RESERVA, DataFrame)
println("✓ Dados de reserva carregados: $(nrow(df_reserva)) registros")

# Carregar também dados de encargo para comparação
if isfile(ARQUIVO_ENCARGO)
    df_encargo = CSV.read(ARQUIVO_ENCARGO, DataFrame)
    println("✓ Dados de encargo carregados: $(nrow(df_encargo)) registros")
    tem_encargo = true
else
    println("⚠  Arquivo de encargo não encontrado (opcional)")
    tem_encargo = false
end

# ============================================================================
# FUNÇÃO AUXILIAR DE PLOT
# ============================================================================

function salvar_plot(p, nome_arquivo::String)
    """Salva gráfico e exibe confirmação"""
    caminho = joinpath(GRAFICOS_DIR, nome_arquivo)
    savefig(p, caminho)
    println("  ✓ Salvo: $nome_arquivo")
end

# ============================================================================
# GRÁFICO 1: RESERVA TOTAL POR IDADE (COMPARAÇÃO ENTRE SEXOS)
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 1: Reserva Total por Idade")
println("=" ^ 70)

dados_masc = filter(row -> row.sexo == "Masculino", df_reserva)
dados_fem = filter(row -> row.sexo == "Feminino", df_reserva)

println("\nGerando gráfico comparativo...")

p1 = plot(
    title="Reserva Matemática de Pensão - Servidor Vivo",
    xlabel="Idade Atual (anos)",
    ylabel="Reserva (anos de benefício)",
    legend=:topright,
    ylims=(0, :auto)
)

# Masculino
plot!(p1, dados_masc.idade_atual, dados_masc.reserva_total,
      label="Masculino",
      color=:steelblue,
      linewidth=3,
      alpha=0.9)

# Feminino
plot!(p1, dados_fem.idade_atual, dados_fem.reserva_total,
      label="Feminino",
      color=:coral,
      linewidth=3,
      alpha=0.9)

# Estatísticas
reserva_media_masc = mean(dados_masc.reserva_total)
reserva_media_fem = mean(dados_fem.reserva_total)
diferenca = reserva_media_masc - reserva_media_fem

y_max = maximum([maximum(dados_masc.reserva_total), maximum(dados_fem.reserva_total)])
annotate!(p1, [(
    75, y_max * 0.9,
    text("Média M: $(round(reserva_media_masc, digits=2)) anos\n" *
         "Média F: $(round(reserva_media_fem, digits=2)) anos\n" *
         "Diferença: +$(round(diferenca, digits=2)) anos",
         :right, 8, :gray30)
)])

salvar_plot(p1, "reserva_total.png")

# ============================================================================
# GRÁFICO 2: EXPECTATIVA DE VIDA
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 2: Expectativa de Vida")
println("=" ^ 70)

println("\nGerando gráfico de expectativa de vida...")

p2 = plot(
    title="Expectativa de Vida Residual (AT-2012 IAM Basic)",
    xlabel="Idade Atual (anos)",
    ylabel="Expectativa de Vida (anos)",
    legend=:topright,
    ylims=(0, :auto)
)

# Masculino
plot!(p2, dados_masc.idade_atual, dados_masc.expectativa_vida,
      label="Masculino",
      color=:steelblue,
      linewidth=3,
      alpha=0.9)

# Feminino
plot!(p2, dados_fem.idade_atual, dados_fem.expectativa_vida,
      label="Feminino",
      color=:coral,
      linewidth=3,
      alpha=0.9)

# Anotação
ex_55_masc = dados_masc[dados_masc.idade_atual .== 55, :expectativa_vida][1]
ex_55_fem = dados_fem[dados_fem.idade_atual .== 55, :expectativa_vida][1]

annotate!(p2, [(
    75, maximum(dados_fem.expectativa_vida) * 0.9,
    text("e₅₅ Masculino: $(round(ex_55_masc, digits=1)) anos\n" *
         "e₅₅ Feminino: $(round(ex_55_fem, digits=1)) anos\n" *
         "Diferença: $(round(ex_55_fem - ex_55_masc, digits=1)) anos",
         :right, 8, :gray30)
)])

salvar_plot(p2, "expectativa_vida.png")

# ============================================================================
# GRÁFICO 3: PROBABILIDADE DE DEIXAR PENSÃO
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 3: Probabilidade de Deixar Pensão")
println("=" ^ 70)

println("\nGerando gráfico de probabilidade...")

p3 = plot(
    title="Probabilidade de Deixar ≥1 Dependente (Média Ponderada Futura)",
    xlabel="Idade Atual (anos)",
    ylabel="Probabilidade (%)",
    legend=:topright,
    ylims=(0, 100)
)

# Masculino
plot!(p3, dados_masc.idade_atual, 100 * dados_masc.prob_deixar_pensao,
      label="Masculino",
      color=:steelblue,
      linewidth=3,
      alpha=0.9)

# Feminino
plot!(p3, dados_fem.idade_atual, 100 * dados_fem.prob_deixar_pensao,
      label="Feminino",
      color=:coral,
      linewidth=3,
      alpha=0.9)

# Linhas de referência
hline!(p3, [50.0], color=:gray, linestyle=:dot, linewidth=1, label="50%", alpha=0.5)

# Anotação
prob_media_masc = mean(dados_masc.prob_deixar_pensao)
prob_media_fem = mean(dados_fem.prob_deixar_pensao)

annotate!(p3, [(
    35, 90,
    text("Média M: $(round(100 * prob_media_masc, digits=1))%\n" *
         "Média F: $(round(100 * prob_media_fem, digits=1))%\n" *
         "(ponderada por mortalidade)",
         :left, 8, :gray30)
)])

salvar_plot(p3, "prob_deixar_pensao.png")

# ============================================================================
# GRÁFICO 4: COMPARAÇÃO RESERVA vs ENCARGO HERITOR
# ============================================================================

if tem_encargo
    println("\n" * "=" ^ 70)
    println("GRÁFICO 4: Comparação Reserva vs Encargo Heritor")
    println("=" ^ 70)

    println("\nGerando gráfico comparativo (layout 2×2)...")

    # Carregar dados de encargo
    dados_enc_masc = filter(row -> row.sexo == "Masculino", df_encargo)
    dados_enc_fem = filter(row -> row.sexo == "Feminino", df_encargo)

    # Criar subplot 2×2
    p4 = plot(layout=(2, 2), size=(1400, 800))

    # [1,1] Reserva Masculino
    plot!(p4[1],
          dados_masc.idade_atual, dados_masc.reserva_total,
          label=nothing,
          color=:steelblue,
          linewidth=3,
          title="Reserva - Masculino",
          xlabel="",
          ylabel="Reserva (anos)",
          ylims=(0, :auto))

    # [1,2] Encargo Masculino
    plot!(p4[2],
          dados_enc_masc.idade, dados_enc_masc.encargo_medio,
          label=nothing,
          color=:steelblue,
          linewidth=3,
          title="Encargo - Masculino",
          xlabel="",
          ylabel="Encargo (anos)",
          ylims=(0, :auto))

    # [2,1] Reserva Feminino
    plot!(p4[3],
          dados_fem.idade_atual, dados_fem.reserva_total,
          label=nothing,
          color=:coral,
          linewidth=3,
          title="Reserva - Feminino",
          xlabel="Idade (anos)",
          ylabel="Reserva (anos)",
          ylims=(0, :auto))

    # [2,2] Encargo Feminino
    plot!(p4[4],
          dados_enc_fem.idade, dados_enc_fem.encargo_medio,
          label=nothing,
          color=:coral,
          linewidth=3,
          title="Encargo - Feminino",
          xlabel="Idade (anos)",
          ylabel="Encargo (anos)",
          ylims=(0, :auto))

    salvar_plot(p4, "reserva_vs_encargo.png")
end

# ============================================================================
# SUMÁRIO
# ============================================================================

println("\n" * "=" ^ 70)
println("✓ Gráficos gerados com sucesso!")
println("=" ^ 70)
println("\nArquivos salvos em: $GRAFICOS_DIR")
println("\nGráficos gerados:")
println("  1. reserva_total.png - Reserva por idade (M vs F)")
println("  2. expectativa_vida.png - Expectativa de vida e_x")
println("  3. prob_deixar_pensao.png - P(deixar ≥1 dependente)")

if tem_encargo
    println("  4. reserva_vs_encargo.png - Comparação Reserva vs Encargo Heritor")
end

println("\n💡 Interpretação:")
println("   • Reserva = Valor presente esperado do custo de pensões")
println("     para servidor VIVO de idade x")
println("   • Encargo Heritor = Custo condicional SE morrer em idade x")
println("   • Reserva << Encargo (distribuída por todas idades futuras)")
println("=" ^ 70)
