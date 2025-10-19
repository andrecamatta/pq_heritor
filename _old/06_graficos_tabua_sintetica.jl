#!/usr/bin/env julia
# Gráficos da Tábua de Coorte Sintética
# Visualizações das probabilidades de transição e validação dos modelos

using CSV
using DataFrames
using Plots
using Statistics
using Printf

println("=" ^ 70)
println("Visualizações da Tábua de Coorte Sintética")
println("=" ^ 70)

# Configurações de plots
gr()
default(
    fontfamily = "Computer Modern",
    linewidth = 2,
    framestyle = :box,
    label = nothing,
    grid = true,
    size = (800, 600),
    dpi = 150
)

# Carregar resultados
RESULTADOS_DIR = "resultados"
GRAFICOS_DIR = joinpath(RESULTADOS_DIR, "graficos")
mkpath(GRAFICOS_DIR)

arquivo_completo = joinpath(RESULTADOS_DIR, "tabua_sintetica_completa.csv")

if !isfile(arquivo_completo)
    println("\nERRO: Arquivo não encontrado: $arquivo_completo")
    println("Execute primeiro: julia 05_tabua_sintetica.jl")
    exit(1)
end

println("\nCarregando resultados da tábua sintética...")
df = CSV.read(arquivo_completo, DataFrame)
println("Dados carregados: $(nrow(df)) registros")

# === GRÁFICO 1: PROBABILIDADE DE CASAR (q_casar) ===

println("\n📊 Gráfico 1: Probabilidade de Casar por Idade")

p1 = plot(
    title = "Probabilidade de Casar (q_casar) por Idade",
    xlabel = "Idade",
    ylabel = "Probabilidade (%)",
    legend = :topright
)

for sexo in ["Masculino", "Feminino"]
    for grupo in ["Geral", "Servidores"]
        dados = filter(row -> row.sexo == sexo && row.grupo == grupo, df)

        # Remover missings
        idades_validas = dados.idade[1:end-1]  # q_casar tem n-1 elementos
        q_casar_vals = collect(skipmissing(dados.q_casar)) .* 100

        estilo = grupo == "Geral" ? :solid : :dash
        cor = sexo == "Masculino" ? :steelblue : :coral

        plot!(
            p1,
            idades_validas,
            q_casar_vals,
            label = "$sexo - $grupo",
            linestyle = estilo,
            color = cor,
            linewidth = 2
        )
    end
end

savefig(p1, joinpath(GRAFICOS_DIR, "08_q_casar_por_idade.png"))
println("  ✓ Salvo: 08_q_casar_por_idade.png")

# === GRÁFICO 2: PROPORÇÃO SOLTEIRA (l_solteiro) ===

println("\n📊 Gráfico 2: Proporção que Permanece Solteira")

p2 = plot(
    title = "Proporção Solteira até Idade x (l_solteiro)",
    xlabel = "Idade",
    ylabel = "Proporção (%)",
    legend = :topright
)

for sexo in ["Masculino", "Feminino"]
    for grupo in ["Geral", "Servidores"]
        dados = filter(row -> row.sexo == sexo && row.grupo == grupo, df)

        estilo = grupo == "Geral" ? :solid : :dash
        cor = sexo == "Masculino" ? :steelblue : :coral

        plot!(
            p2,
            dados.idade,
            dados.l_solteiro .* 100,
            label = "$sexo - $grupo",
            linestyle = estilo,
            color = cor,
            linewidth = 2
        )
    end
end

savefig(p2, joinpath(GRAFICOS_DIR, "09_l_solteiro_por_idade.png"))
println("  ✓ Salvo: 09_l_solteiro_por_idade.png")

# === GRÁFICO 3: VALIDAÇÃO (Observado vs Reconstruído) ===

println("\n📊 Gráfico 3: Validação do Modelo (Observado vs Modelo)")

layout_validacao = @layout [a b; c d]

p3_masculino_geral = plot(
    title = "Masculino - Geral",
    xlabel = "Idade",
    ylabel = "Proporção Casada (%)",
    legend = :bottomright
)
dados_mg = filter(row -> row.sexo == "Masculino" && row.grupo == "Geral", df)
plot!(p3_masculino_geral, dados_mg.idade, dados_mg.P_observada .* 100,
      label = "Observado", color = :black, linewidth = 2)
plot!(p3_masculino_geral, dados_mg.idade, dados_mg.P_reconstruida .* 100,
      label = "Modelo", color = :steelblue, linestyle = :dash, linewidth = 2)

p3_masculino_serv = plot(
    title = "Masculino - Servidores",
    xlabel = "Idade",
    ylabel = "Proporção Casada (%)",
    legend = :bottomright
)
dados_ms = filter(row -> row.sexo == "Masculino" && row.grupo == "Servidores", df)
plot!(p3_masculino_serv, dados_ms.idade, dados_ms.P_observada .* 100,
      label = "Observado", color = :black, linewidth = 2)
plot!(p3_masculino_serv, dados_ms.idade, dados_ms.P_reconstruida .* 100,
      label = "Modelo", color = :steelblue, linestyle = :dash, linewidth = 2)

p3_feminino_geral = plot(
    title = "Feminino - Geral",
    xlabel = "Idade",
    ylabel = "Proporção Casada (%)",
    legend = :bottomright
)
dados_fg = filter(row -> row.sexo == "Feminino" && row.grupo == "Geral", df)
plot!(p3_feminino_geral, dados_fg.idade, dados_fg.P_observada .* 100,
      label = "Observado", color = :black, linewidth = 2)
plot!(p3_feminino_geral, dados_fg.idade, dados_fg.P_reconstruida .* 100,
      label = "Modelo", color = :coral, linestyle = :dash, linewidth = 2)

p3_feminino_serv = plot(
    title = "Feminino - Servidores",
    xlabel = "Idade",
    ylabel = "Proporção Casada (%)",
    legend = :bottomright
)
dados_fs = filter(row -> row.sexo == "Feminino" && row.grupo == "Servidores", df)
plot!(p3_feminino_serv, dados_fs.idade, dados_fs.P_observada .* 100,
      label = "Observado", color = :black, linewidth = 2)
plot!(p3_feminino_serv, dados_fs.idade, dados_fs.P_reconstruida .* 100,
      label = "Modelo", color = :coral, linestyle = :dash, linewidth = 2)

p3 = plot(
    p3_masculino_geral, p3_masculino_serv,
    p3_feminino_geral, p3_feminino_serv,
    layout = layout_validacao,
    size = (1200, 900),
    plot_title = "Validação: Prevalência Observada vs Modelo"
)

savefig(p3, joinpath(GRAFICOS_DIR, "10_validacao_modelo.png"))
println("  ✓ Salvo: 10_validacao_modelo.png")

# === GRÁFICO 4: ERROS DO MODELO ===

println("\n📊 Gráfico 4: Erros do Modelo (Resíduos)")

p4 = plot(
    title = "Erro do Modelo (Observado - Reconstruído)",
    xlabel = "Idade",
    ylabel = "Erro (pontos percentuais)",
    legend = :topright
)

for sexo in ["Masculino", "Feminino"]
    for grupo in ["Geral", "Servidores"]
        dados = filter(row -> row.sexo == sexo && row.grupo == grupo, df)

        estilo = grupo == "Geral" ? :solid : :dash
        cor = sexo == "Masculino" ? :steelblue : :coral

        plot!(
            p4,
            dados.idade,
            dados.erro_abs .* 100,
            label = "$sexo - $grupo",
            linestyle = estilo,
            color = cor,
            linewidth = 2
        )
    end
end

hline!(p4, [0], color = :black, linestyle = :dot, label = "Sem erro", linewidth = 1)

savefig(p4, joinpath(GRAFICOS_DIR, "11_erros_modelo.png"))
println("  ✓ Salvo: 11_erros_modelo.png")

# === GRÁFICO 5: DIFERENÇA SERVIDORES - GERAL (q_casar) ===

println("\n📊 Gráfico 5: Diferença em q_casar (Servidores - Geral)")

p5 = plot(
    title = "Diferença: q_casar Servidores - Geral",
    xlabel = "Idade",
    ylabel = "Diferença (pontos percentuais)",
    legend = :topright
)

for sexo in ["Masculino", "Feminino"]
    dados_geral = filter(row -> row.sexo == sexo && row.grupo == "Geral", df)
    dados_serv = filter(row -> row.sexo == sexo && row.grupo == "Servidores", df)

    q_geral = collect(skipmissing(dados_geral.q_casar))
    q_serv = collect(skipmissing(dados_serv.q_casar))

    diferenca = (q_serv .- q_geral) .* 100
    idades_validas = dados_geral.idade[1:end-1]

    cor = sexo == "Masculino" ? :steelblue : :coral

    plot!(
        p5,
        idades_validas,
        diferenca,
        label = sexo,
        color = cor,
        linewidth = 2
    )
end

hline!(p5, [0], color = :black, linestyle = :dot, label = "Sem diferença", linewidth = 1)

savefig(p5, joinpath(GRAFICOS_DIR, "12_diferenca_q_casar.png"))
println("  ✓ Salvo: 12_diferenca_q_casar.png")

# === GRÁFICO 6: PROBABILIDADE DE SEPARAR (q_separar) ===

println("\n📊 Gráfico 6: Probabilidade de Separar")

p6 = plot(
    title = "Probabilidade de Separar (q_separar) por Idade",
    xlabel = "Idade",
    ylabel = "Probabilidade (%)",
    legend = :topright
)

for sexo in ["Masculino", "Feminino"]
    for grupo in ["Geral", "Servidores"]
        dados = filter(row -> row.sexo == sexo && row.grupo == grupo, df)

        idades_validas = dados.idade[1:end-1]
        q_separar_vals = collect(skipmissing(dados.q_separar)) .* 100

        estilo = grupo == "Geral" ? :solid : :dash
        cor = sexo == "Masculino" ? :steelblue : :coral

        plot!(
            p6,
            idades_validas,
            q_separar_vals,
            label = "$sexo - $grupo",
            linestyle = estilo,
            color = cor,
            linewidth = 2
        )
    end
end

savefig(p6, joinpath(GRAFICOS_DIR, "13_q_separar_por_idade.png"))
println("  ✓ Salvo: 13_q_separar_por_idade.png")

# === ESTATÍSTICAS DE VALIDAÇÃO ===

println("\n" * "=" ^ 70)
println("ESTATÍSTICAS DE VALIDAÇÃO")
println("=" ^ 70)

println("\nErro Médio Absoluto (MAE) por Grupo:")
println("")

for sexo in ["Masculino", "Feminino"]
    println("$sexo:")
    for grupo in ["Geral", "Servidores"]
        dados = filter(row -> row.sexo == sexo && row.grupo == grupo, df)
        mae = mean(abs.(skipmissing(dados.erro_abs))) * 100
        rmse = sqrt(mean(skipmissing(dados.erro_abs).^2)) * 100
        max_erro = maximum(abs.(skipmissing(dados.erro_abs))) * 100

        println("  $grupo:")
        println("    MAE  = $(round(mae, digits=3))%")
        println("    RMSE = $(round(rmse, digits=3))%")
        println("    Máx  = $(round(max_erro, digits=3))%")
    end
end

# === INTERPRETAÇÃO ===

println("\n" * "=" ^ 70)
println("INTERPRETAÇÃO DOS GRÁFICOS")
println("=" ^ 70)

println("\n📌 Gráfico 8 (q_casar):")
println("  - Mostra a 'hazard function' de casamento")
println("  - Pico indica idade típica de casamento")
println("  - Queda após pico = menos solteiros disponíveis")

println("\n📌 Gráfico 9 (l_solteiro):")
println("  - Curva de sobrevivência no estado solteiro")
println("  - Queda rápida = muitos casamentos")
println("  - Assíntota = proporção que nunca casa")

println("\n📌 Gráfico 10 (validação):")
println("  - Modelo deve acompanhar dados observados")
println("  - Pequenos desvios são aceitáveis")
println("  - Se MAE < 1%, modelo está bom")

println("\n📌 Gráfico 11 (erros):")
println("  - Resíduos devem oscilar em torno de zero")
println("  - Padrões sistemáticos indicam má especificação")

println("\n📌 Gráfico 12 (diferença q_casar):")
println("  - Positivo = servidores casam mais nessa idade")
println("  - Negativo = população geral casa mais")

println("\n📌 Gráfico 13 (q_separar):")
println("  - Taxa de dissolução de uniões")
println("  - Valores pequenos são esperados")
println("  - Variação por idade mostra dinâmica de separações")

# === USO PRÁTICO ===

println("\n" * "=" ^ 70)
println("USO PRÁTICO PARA FUNÇÃO HERITOR")
println("=" ^ 70)

println("\n🎯 Exemplo: Probabilidade de servidor solteiro de 30 anos casar até 40:")
println("")

dados_exemplo = filter(row -> row.sexo == "Masculino" && row.grupo == "Servidores", df)

if 30 in dados_exemplo.idade && 40 in dados_exemplo.idade
    idx_30 = findfirst(dados_exemplo.idade .== 30)
    idx_40 = findfirst(dados_exemplo.idade .== 40)

    l_30 = dados_exemplo.l_solteiro[idx_30]
    l_40 = dados_exemplo.l_solteiro[idx_40]

    prob_casar = 1 - (l_40 / l_30)

    println("  l_solteiro[30] = $(round(l_30, digits=4))")
    println("  l_solteiro[40] = $(round(l_40, digits=4))")
    println("")
    println("  P(casar entre 30-40 | solteiro aos 30) = $(round(prob_casar * 100, digits=2))%")
end

println("\n" * "=" ^ 70)
println("RESUMO")
println("=" ^ 70)

println("\n✓ Gráficos criados:")
println("  1. 08_q_casar_por_idade.png")
println("  2. 09_l_solteiro_por_idade.png")
println("  3. 10_validacao_modelo.png")
println("  4. 11_erros_modelo.png")
println("  5. 12_diferenca_q_casar.png")
println("  6. 13_q_separar_por_idade.png")

println("\n" * "=" ^ 70)
println("Próximos passos:")
println("  - Revisar validação (MAE < 1%?)")
println("  - Documentar metodologia (METODOLOGIA_TABUA_SINTETICA.md)")
println("  - Integrar com cálculo de pensão heritor")
println("=" ^ 70)
