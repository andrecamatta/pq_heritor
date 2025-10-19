#!/usr/bin/env julia
# Análise Exploratória da Distribuição de Age Gap
#
# Objetivo: Determinar qual distribuição usar para amostragem Monte Carlo
# - Normal(μ, σ)?
# - t-Student(μ, σ, ν)?
# - Empírica?
#
# Análises:
# - Histogramas por sexo e faixa etária
# - QQ-plots (Normal, t-Student)
# - Testes de normalidade
# - Estatísticas: assimetria, curtose
# - Heterogeneidade de variância

using CSV
using DataFrames
using Statistics
using StatsBase
using Distributions
using Plots
using HypothesisTests  # Para testes de normalidade
using Printf

# Importar módulo compartilhado
include("src/AgeGap.jl")
using .AgeGap

println("=" ^ 70)
println("ANÁLISE EXPLORATÓRIA: DISTRIBUIÇÃO DE AGE GAP")
println("=" ^ 70)

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

DADOS_DIR = "dados"
RESULTADOS_DIR = "resultados"
GRAFICOS_DIR = joinpath(RESULTADOS_DIR, "graficos")
mkpath(GRAFICOS_DIR)

arquivo_dados = joinpath(DADOS_DIR, "pnadc_2023_processado.csv")

if !isfile(arquivo_dados)
    println("\nERRO: Arquivo não encontrado: $arquivo_dados")
    println("Execute primeiro: julia 01_processar_dados.jl")
    exit(1)
end

# ============================================================================
# CARREGAR E PREPARAR DADOS
# ============================================================================

println("\nCarregando dados...")
df = CSV.read(arquivo_dados, DataFrame)

println("Total de registros: $(nrow(df))")

# Função extrair_pares_age_gap agora vem de src/AgeGap.jl (módulo compartilhado)

println("\nExtraindo pares...")
pares = extrair_pares_age_gap(df)

println("✓ Pares identificados: $(nrow(pares))")
println("  População estimada: $(round(sum(pares.peso) / 1_000_000, digits=2)) milhões de casais")

# Separar por grupo
pares_geral = pares
pares_serv = filter(row -> row.servidor_ref, pares)

println("\n  Servidores (referência): $(nrow(pares_serv))")
println("    População estimada: $(round(sum(pares_serv.peso) / 1_000_000, digits=2)) milhões")

# ============================================================================
# ESTATÍSTICAS DESCRITIVAS GLOBAIS
# ============================================================================

println("\n" * "=" ^ 70)
println("ESTATÍSTICAS DESCRITIVAS GLOBAIS")
println("=" ^ 70)

for (dados, label) in [(pares_geral, "População Geral"), (pares_serv, "Servidores")]
    if nrow(dados) == 0
        continue
    end

    println("\n$label:")

    # Estatísticas ponderadas
    ag_medio = sum(dados.age_gap .* dados.peso) / sum(dados.peso)
    ag_var = sum((dados.age_gap .- ag_medio).^2 .* dados.peso) / sum(dados.peso)
    ag_sd = sqrt(ag_var)

    # Assimetria e curtose (ponderados)
    ag_skew = sum((dados.age_gap .- ag_medio).^3 .* dados.peso) / (sum(dados.peso) * ag_sd^3)
    ag_kurt = sum((dados.age_gap .- ag_medio).^4 .* dados.peso) / (sum(dados.peso) * ag_sd^4) - 3

    println("  Média ponderada: $(round(ag_medio, digits=2)) anos")
    println("  Desvio-padrão: $(round(ag_sd, digits=2)) anos")
    println("  Assimetria: $(round(ag_skew, digits=3)) (0=simétrico, >0=cauda direita, <0=cauda esquerda)")
    println("  Curtose: $(round(ag_kurt, digits=3)) (0=Normal, >0=caudas pesadas, <0=caudas leves)")
    println("  Mediana: $(median(dados.age_gap)) anos")
    println("  Min/Max: $(minimum(dados.age_gap)) / $(maximum(dados.age_gap)) anos")
    println("  IQR (P75-P25): $(quantile(dados.age_gap, 0.75) - quantile(dados.age_gap, 0.25)) anos")

    # Por sexo
    for sexo in [1, 2]
        sexo_label = sexo == 1 ? "Masculino" : "Feminino"
        dados_sexo = filter(row -> row.sexo_ref == sexo, dados)

        if nrow(dados_sexo) > 0
            media_sexo = sum(dados_sexo.age_gap .* dados_sexo.peso) / sum(dados_sexo.peso)
            sd_sexo = sqrt(sum((dados_sexo.age_gap .- media_sexo).^2 .* dados_sexo.peso) / sum(dados_sexo.peso))
            println("    $sexo_label: μ=$(round(media_sexo, digits=2)) anos, σ=$(round(sd_sexo, digits=2)) anos")
        end
    end
end

# ============================================================================
# HISTOGRAMAS POR SEXO
# ============================================================================

println("\n" * "=" ^ 70)
println("GERANDO HISTOGRAMAS")
println("=" ^ 70)

for (dados, grupo_label) in [(pares_geral, "Geral"), (pares_serv, "Servidores")]
    if nrow(dados) == 0
        continue
    end

    for sexo in [1, 2]
        sexo_label = sexo == 1 ? "Masculino" : "Feminino"
        dados_sexo = filter(row -> row.sexo_ref == sexo, dados)

        if nrow(dados_sexo) < 30  # Amostra muito pequena
            continue
        end

        println("\nGerando histograma: $grupo_label - $sexo_label")

        # Histograma
        p = histogram(
            dados_sexo.age_gap,
            weights = dados_sexo.peso,
            bins = -40:2:40,
            label = "Observado",
            xlabel = "Age Gap (anos)",
            ylabel = "Frequência Ponderada",
            title = "Distribuição de Age Gap - $sexo_label ($grupo_label)",
            legend = :topright,
            alpha = 0.6,
            size = (1000, 600),
            dpi = 150
        )

        # Sobrepor distribuição Normal ajustada
        ag_medio = sum(dados_sexo.age_gap .* dados_sexo.peso) / sum(dados_sexo.peso)
        ag_sd = sqrt(sum((dados_sexo.age_gap .- ag_medio).^2 .* dados_sexo.peso) / sum(dados_sexo.peso))

        x_range = -40:0.5:40
        dist_normal = Normal(ag_medio, ag_sd)
        y_normal = pdf.(dist_normal, x_range) .* sum(dados_sexo.peso) .* 2  # Escalar para bins de largura 2

        plot!(p, x_range, y_normal,
              linewidth = 3,
              color = :red,
              label = "Normal(μ=$(round(ag_medio, digits=1)), σ=$(round(ag_sd, digits=1)))")

        # Linha vertical em zero
        vline!(p, [0],
               linestyle = :dash,
               color = :gray,
               linewidth = 2,
               label = "Age gap = 0")

        # Salvar
        arquivo = joinpath(GRAFICOS_DIR, "age_gap_hist_$(lowercase(grupo_label))_$(lowercase(sexo_label)).png")
        savefig(p, arquivo)
        println("  ✓ Salvo: $arquivo")
    end
end

# ============================================================================
# QQ-PLOTS (Normal)
# ============================================================================

println("\n" * "=" ^ 70)
println("GERANDO QQ-PLOTS (NORMALIDADE)")
println("=" ^ 70)

for (dados, grupo_label) in [(pares_geral, "Geral"), (pares_serv, "Servidores")]
    if nrow(dados) == 0
        continue
    end

    for sexo in [1, 2]
        sexo_label = sexo == 1 ? "Masculino" : "Feminino"
        dados_sexo = filter(row -> row.sexo_ref == sexo, dados)

        if nrow(dados_sexo) < 30
            continue
        end

        println("\nGerando QQ-plot: $grupo_label - $sexo_label")

        # QQ-plot manual (Plots.jl não tem qqplot nativo)
        ag_sorted = sort(dados_sexo.age_gap)
        n = length(ag_sorted)
        theoretical_quantiles = quantile(Normal(0, 1), (1:n) ./ (n + 1))

        # Padronizar observações
        ag_medio = sum(dados_sexo.age_gap .* dados_sexo.peso) / sum(dados_sexo.peso)
        ag_sd = sqrt(sum((dados_sexo.age_gap .- ag_medio).^2 .* dados_sexo.peso) / sum(dados_sexo.peso))
        ag_standardized = (ag_sorted .- ag_medio) ./ ag_sd

        p = scatter(
            theoretical_quantiles,
            ag_standardized,
            label = "Dados observados",
            xlabel = "Quantis Teóricos (Normal Padrão)",
            ylabel = "Quantis Observados (Padronizados)",
            title = "QQ-Plot Normal - $sexo_label ($grupo_label)",
            markersize = 2,
            alpha = 0.5,
            legend = :topleft,
            size = (800, 800),
            dpi = 150
        )

        # Linha y=x (perfeita normalidade)
        plot!(p, [-4, 4], [-4, 4],
              linewidth = 2,
              color = :red,
              label = "Normal perfeita (y=x)")

        # Salvar
        arquivo = joinpath(GRAFICOS_DIR, "age_gap_qqplot_$(lowercase(grupo_label))_$(lowercase(sexo_label)).png")
        savefig(p, arquivo)
        println("  ✓ Salvo: $arquivo")
    end
end

# ============================================================================
# TESTES DE NORMALIDADE (por faixa etária)
# ============================================================================

println("\n" * "=" ^ 70)
println("TESTES DE NORMALIDADE POR FAIXA ETÁRIA")
println("=" ^ 70)

faixas = [(20, 34), (35, 49), (50, 64), (65, 90)]

arquivo_diagnostico = joinpath(RESULTADOS_DIR, "age_gap_diagnostico.txt")
open(arquivo_diagnostico, "w") do io
    write(io, "DIAGNÓSTICO: DISTRIBUIÇÃO DE AGE GAP\n")
    write(io, "=" ^ 70 * "\n\n")

    for (dados, grupo_label) in [(pares_geral, "População Geral"), (pares_serv, "Servidores")]
        if nrow(dados) == 0
            continue
        end

        write(io, "\n$grupo_label:\n")
        write(io, "-" ^ 70 * "\n\n")

        for sexo in [1, 2]
            sexo_label = sexo == 1 ? "Masculino" : "Feminino"
            dados_sexo = filter(row -> row.sexo_ref == sexo, dados)

            write(io, "\n  $sexo_label:\n\n")

            for (idade_min, idade_max) in faixas
                dados_faixa = filter(row -> idade_min <= row.idade_ref <= idade_max, dados_sexo)

                if nrow(dados_faixa) < 20  # Amostra muito pequena para teste
                    write(io, "    Faixa $idade_min-$idade_max: n=$(nrow(dados_faixa)) (muito pequena)\n")
                    continue
                end

                ag = dados_faixa.age_gap
                ag_medio = mean(ag)
                ag_sd = std(ag)
                ag_skew = skewness(ag)
                ag_kurt = kurtosis(ag)

                write(io, "    Faixa $idade_min-$idade_max (n=$(nrow(dados_faixa))):\n")
                write(io, "      μ=$(round(ag_medio, digits=2)), σ=$(round(ag_sd, digits=2))\n")
                write(io, "      Assimetria=$(round(ag_skew, digits=3)), Curtose=$(round(ag_kurt, digits=3))\n")

                # Teste de normalidade (Shapiro-Wilk se n <= 5000, Anderson-Darling caso contrário)
                if nrow(dados_faixa) <= 5000
                    test_result = OneSampleADTest(ag, Normal(ag_medio, ag_sd))
                    pval = pvalue(test_result)
                    write(io, "      Anderson-Darling p-value: $(round(pval, digits=4))\n")

                    if pval < 0.01
                        write(io, "      ⚠️  Evidência forte contra normalidade (p < 0.01)\n")
                    elseif pval < 0.05
                        write(io, "      ⚠️  Evidência moderada contra normalidade (p < 0.05)\n")
                    else
                        write(io, "      ✓ Não rejeita normalidade (p >= 0.05)\n")
                    end
                else
                    write(io, "      (amostra grande, teste não aplicado)\n")
                end

                write(io, "\n")
            end
        end
    end

    # Resumo e recomendações
    write(io, "\n" * "=" ^ 70 * "\n")
    write(io, "RECOMENDAÇÕES\n")
    write(io, "=" ^ 70 * "\n\n")
    write(io, "Com base nas análises acima:\n\n")
    write(io, "1. Se assimetria ≈ 0 e curtose ≈ 0 em todas faixas:\n")
    write(io, "   → Distribuição NORMAL é adequada\n\n")
    write(io, "2. Se curtose > 0.5 (caudas pesadas):\n")
    write(io, "   → Considerar t-Student com ν = 5-10 graus de liberdade\n\n")
    write(io, "3. Se assimetria significativa (|skew| > 0.5):\n")
    write(io, "   → Considerar distribuição EMPÍRICA (não-paramétrica)\n\n")
    write(io, "4. Se testes rejeitam normalidade (p < 0.05) em várias faixas:\n")
    write(io, "   → Usar distribuição EMPÍRICA ou t-Student\n\n")
end

println("\n✓ Diagnóstico salvo: $arquivo_diagnostico")

# ============================================================================
# HETEROGENEIDADE DE VARIÂNCIA POR IDADE
# ============================================================================

println("\n" * "=" ^ 70)
println("HETEROGENEIDADE DE VARIÂNCIA (σ varia com idade?)")
println("=" ^ 70)

for (dados, grupo_label) in [(pares_geral, "Geral"), (pares_serv, "Servidores")]
    if nrow(dados) == 0
        continue
    end

    for sexo in [1, 2]
        sexo_label = sexo == 1 ? "Masculino" : "Feminino"
        dados_sexo = filter(row -> row.sexo_ref == sexo, dados)

        if nrow(dados_sexo) < 100
            continue
        end

        println("\n$grupo_label - $sexo_label:")

        # Calcular SD por faixa etária
        sds = Float64[]
        medias = Float64[]
        faixa_labels = String[]

        for (idade_min, idade_max) in faixas
            dados_faixa = filter(row -> idade_min <= row.idade_ref <= idade_max, dados_sexo)

            if nrow(dados_faixa) >= 10
                ag_medio = mean(dados_faixa.age_gap)
                ag_sd = std(dados_faixa.age_gap)

                push!(sds, ag_sd)
                push!(medias, ag_medio)
                push!(faixa_labels, "$idade_min-$idade_max")

                println("  Faixa $idade_min-$idade_max: μ=$(round(ag_medio, digits=2)), σ=$(round(ag_sd, digits=2))")
            end
        end

        if length(sds) >= 2
            cv_sds = std(sds) / mean(sds)  # Coeficiente de variação dos SDs
            println("  Variabilidade dos SDs (CV): $(round(cv_sds, digits=3))")

            if cv_sds < 0.15
                println("  ✓ σ relativamente constante entre faixas (CV < 0.15)")
                println("    → Pode usar σ global ou suavização leve")
            else
                println("  ⚠️  σ varia entre faixas (CV >= 0.15)")
                println("    → Recomenda-se modelar σ(idade) com credibilidade + suavização")
            end
        end
    end
end

# ============================================================================
# RESUMO FINAL
# ============================================================================

println("\n" * "=" ^ 70)
println("RESUMO DA ANÁLISE")
println("=" ^ 70)

println("""
Arquivos gerados:

Histogramas:
  - age_gap_hist_geral_masculino.png
  - age_gap_hist_geral_feminino.png
  - age_gap_hist_servidores_masculino.png
  - age_gap_hist_servidores_feminino.png

QQ-plots (normalidade):
  - age_gap_qqplot_geral_masculino.png
  - age_gap_qqplot_geral_feminino.png
  - age_gap_qqplot_servidores_masculino.png
  - age_gap_qqplot_servidores_feminino.png

Diagnóstico:
  - age_gap_diagnostico.txt ⭐ CONSULTAR ESTE ARQUIVO

Próximos passos:

1. EXAMINAR GRÁFICOS:
   - Histogramas: Distribuição é simétrica? Caudas pesadas?
   - QQ-plots: Pontos seguem linha y=x? Desvios nas caudas?

2. LER DIAGNÓSTICO:
   - age_gap_diagnostico.txt contém:
     * Estatísticas por faixa etária
     * Testes de normalidade
     * Recomendações

3. DECIDIR DISTRIBUIÇÃO:
   - Normal: Se assimetria ≈ 0, curtose ≈ 0, QQ-plot linear
   - t-Student: Se caudas pesadas (curtose > 0.5)
   - Empírica: Se assimetria alta ou testes rejeitam normalidade

4. EXECUTAR:
   - julia 09_age_gap_servidores.jl  (modificado com σ)
   - julia 09b_samplear_age_gap.jl   (amostragem Monte Carlo)
""")

println("=" ^ 70)
println("✓ Análise exploratória concluída!")
println("=" ^ 70)
