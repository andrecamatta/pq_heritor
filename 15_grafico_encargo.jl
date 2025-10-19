#!/usr/bin/env julia
# Gráficos de Encargo Atuarial
# Visualização do custo das pensões por idade e sexo

using CSV
using DataFrames
using Plots
using Statistics

println("=" ^ 70)
println("GRÁFICOS - Encargo Atuarial (Função Heritor)")
println("=" ^ 70)

# ============================================================================
# CONFIGURAÇÃO
# ============================================================================

# Diretórios
RESULTADOS_DIR = "resultados"
GRAFICOS_DIR = joinpath(RESULTADOS_DIR, "graficos")
ARQUIVO_ENCARGO = joinpath(RESULTADOS_DIR, "encargo_heritor.csv")
ARQUIVO_SENSIBILIDADE = joinpath(RESULTADOS_DIR, "encargo_sensibilidade_taxa.csv")

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

if !isfile(ARQUIVO_ENCARGO)
    println("\nERRO: Arquivo não encontrado: $ARQUIVO_ENCARGO")
    println("Execute primeiro: julia --project=. 17_calcular_encargo_tabela.jl")
    exit(1)
end

println("\nCarregando dados...")
df_encargo = CSV.read(ARQUIVO_ENCARGO, DataFrame)
println("✓ Dados de encargo carregados: $(nrow(df_encargo)) registros")

# Carregar dados de sensibilidade (se existir)
tem_sensibilidade = isfile(ARQUIVO_SENSIBILIDADE)
if tem_sensibilidade
    df_sensibilidade = CSV.read(ARQUIVO_SENSIBILIDADE, DataFrame)
    println("✓ Dados de sensibilidade carregados: $(nrow(df_sensibilidade)) registros")
else
    println("⚠  Arquivo de sensibilidade não encontrado (opcional)")
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
# GRÁFICO 1-2: ENCARGO POR IDADE (SEPARADO POR SEXO)
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 1-2: Encargo por Idade (Masculino e Feminino)")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados = filter(row -> row.sexo == sexo, df_encargo)

    println("\nGerando gráfico: $sexo")

    p = plot(
        title="Encargo Atuarial - $sexo",
        xlabel="Idade (anos)",
        ylabel="Encargo (anos de benefício)",
        legend=:topleft,  # Movido para esquerda
        ylims=(0, :auto)
    )

    # Banda P10-P90 (intervalo de confiança 80%)
    plot!(p, dados.idade, dados.encargo_p90,
          fillrange=dados.encargo_p10,
          fillalpha=0.15,
          fillcolor=:steelblue,
          linealpha=0,
          label="P10-P90 (IC 80%)")

    # Linha do encargo médio
    plot!(p, dados.idade, dados.encargo_medio,
          label="Encargo médio",
          color=:steelblue,
          linewidth=3,
          alpha=0.9)

    # Linha do encargo mediano
    plot!(p, dados.idade, dados.encargo_mediano,
          label="Encargo mediano",
          color=:coral,
          linewidth=2,
          linestyle=:dash,
          alpha=0.8)

    # Estatísticas no gráfico - posicionado no canto inferior direito
    encargo_max_medio = maximum(dados.encargo_medio)
    idade_max = dados.idade[argmax(dados.encargo_medio)]
    encargo_medio_geral = mean(dados.encargo_medio)

    # Posicionar anotação no canto inferior direito para não conflitar com legenda
    y_max = maximum(dados.encargo_p90)
    annotate!(p, [(
        78, y_max * 0.15,  # Canto inferior direito
        text("Pico: $(round(encargo_max_medio, digits=1)) anos aos $idade_max anos\n" *
             "Média: $(round(encargo_medio_geral, digits=1)) anos",
             :right, 8, :gray30)
    )])

    nome_arquivo = "encargo_$(lowercase(sexo)).png"
    salvar_plot(p, nome_arquivo)
end

# ============================================================================
# GRÁFICO 3: COMPARAÇÃO ENTRE SEXOS
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 3: Comparação entre Sexos")
println("=" ^ 70)

dados_masc = filter(row -> row.sexo == "Masculino", df_encargo)
dados_fem = filter(row -> row.sexo == "Feminino", df_encargo)

println("\nGerando gráfico comparativo...")

p = plot(
    title="Encargo Atuarial - Comparação entre Sexos",
    xlabel="Idade (anos)",
    ylabel="Encargo (anos de benefício)",
    legend=:topleft,  # Movido para esquerda
    ylims=(0, :auto)
)

# Masculino
plot!(p, dados_masc.idade, dados_masc.encargo_medio,
      label="Masculino",
      color=:steelblue,
      linewidth=3,
      alpha=0.9)

# Feminino
plot!(p, dados_fem.idade, dados_fem.encargo_medio,
      label="Feminino",
      color=:coral,
      linewidth=3,
      alpha=0.9)

# Estatísticas - posicionar no canto inferior direito
encargo_medio_masc = mean(dados_masc.encargo_medio)
encargo_medio_fem = mean(dados_fem.encargo_medio)
diferenca = encargo_medio_fem - encargo_medio_masc

y_max_comp = maximum([maximum(dados_masc.encargo_medio), maximum(dados_fem.encargo_medio)])
annotate!(p, [(
    78, y_max_comp * 0.15,  # Canto inferior direito
    text("Média M: $(round(encargo_medio_masc, digits=1)) anos\n" *
         "Média F: $(round(encargo_medio_fem, digits=1)) anos\n" *
         "Diferença: $(round(diferenca, digits=1)) anos",
         :right, 8, :gray30)
)])

salvar_plot(p, "encargo_comparacao_sexos.png")

# ============================================================================
# GRÁFICO 4: PERCENTUAL DE PENSÃO MÉDIO
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 4: Percentual de Pensão Médio")
println("=" ^ 70)

println("\nGerando gráfico de percentual de pensão...")

p = plot(
    title="Percentual Médio de Pensão por Idade (incluindo casos sem dependentes)",
    xlabel="Idade (anos)",
    ylabel="Percentual de Pensão (%)",
    legend=:bottomright,
    ylims=(0, 100)
)

# Linhas de referência
hline!(p, [50.0], color=:gray, linestyle=:dot, linewidth=1, label="Base (50%)", alpha=0.5)
hline!(p, [60.0], color=:orange, linestyle=:dashdot, linewidth=1, label="1 dependente (60%)", alpha=0.6)
hline!(p, [100.0], color=:gray, linestyle=:dot, linewidth=1, label="Máximo (100%)", alpha=0.5)

# Masculino
plot!(p, dados_masc.idade, 100 * dados_masc.percentual_pensao_medio,
      label="Masculino",
      color=:steelblue,
      linewidth=3,
      alpha=0.9)

# Feminino
plot!(p, dados_fem.idade, 100 * dados_fem.percentual_pensao_medio,
      label="Feminino",
      color=:coral,
      linewidth=3,
      alpha=0.9)

# Explicação da regra - posicionada no topo esquerdo
annotate!(p, [(
    33, 88,  # Canto superior esquerdo (ajustado)
    text("Regra: 50% + 10% × n_dependentes (max 100%)\n\n" *
         "⚠️  Média INCLUI casos sem dependentes:\n" *
         "   • 0 dependentes → 0% pensão\n" *
         "   • 1 dependente → 60% pensão\n" *
         "   • ≥5 dependentes → 100% pensão\n\n" *
         "Valores < 50% são NORMAIS em idades jovens\n" *
         "(muitos solteiros/sem filhos)",
         :left, 7, :gray30)
)])

salvar_plot(p, "percentual_pensao.png")

# ============================================================================
# GRÁFICO 5: SENSIBILIDADE À TAXA DE JUROS
# ============================================================================

if tem_sensibilidade
    println("\n" * "=" ^ 70)
    println("GRÁFICO 5: Sensibilidade à Taxa de Juros")
    println("=" ^ 70)

    println("\nGerando gráfico de sensibilidade...")

    # Obter idades representativas
    idades_rep = sort(unique(df_sensibilidade.idade))
    n_idades = length(idades_rep)

    # Layout de subplots
    layout = (2, 2)  # 2x2 para 4 idades

    # Criar subplots
    plots_array = []

    for (idx, idade) in enumerate(idades_rep)
        dados_idade = filter(row -> row.idade == idade, df_sensibilidade)
        dados_masc_sens = filter(row -> row.sexo == "Masculino", dados_idade)
        dados_fem_sens = filter(row -> row.sexo == "Feminino", dados_idade)

        p_sub = plot(
            title="Idade $idade anos",
            xlabel=idx > 2 ? "Taxa de Juros (%)" : "",
            ylabel=(idx == 1 || idx == 3) ? "Encargo (anos)" : "",
            legend=(idx == 1) ? :topright : false,
            ylims=(0, :auto)
        )

        # Masculino
        if nrow(dados_masc_sens) > 0
            plot!(p_sub, dados_masc_sens.taxa_juros, dados_masc_sens.encargo_medio,
                  label="Masculino",
                  color=:steelblue,
                  linewidth=2.5,
                  marker=:circle,
                  markersize=5,
                  alpha=0.9)
        end

        # Feminino
        if nrow(dados_fem_sens) > 0
            plot!(p_sub, dados_fem_sens.taxa_juros, dados_fem_sens.encargo_medio,
                  label="Feminino",
                  color=:coral,
                  linewidth=2.5,
                  marker=:circle,
                  markersize=5,
                  alpha=0.9)
        end

        push!(plots_array, p_sub)
    end

    # Combinar subplots
    p_final = plot(plots_array..., layout=layout, size=(1200, 800))

    salvar_plot(p_final, "sensibilidade_taxa_juros.png")
else
    println("\n⚠  Pulando gráfico de sensibilidade (dados não disponíveis)")
end

# ============================================================================
# SUMÁRIO
# ============================================================================

println("\n" * "=" ^ 70)
println("✓ Gráficos gerados com sucesso!")
println("=" ^ 70)
println("\nArquivos salvos em: $GRAFICOS_DIR")
println("\nGráficos gerados:")
println("  1. encargo_masculino.png - Encargo por idade (Homens)")
println("  2. encargo_feminino.png - Encargo por idade (Mulheres)")
println("  3. encargo_comparacao_sexos.png - Comparação Masculino vs Feminino")
println("  4. percentual_pensao.png - % médio de pensão por idade")

if tem_sensibilidade
    println("  5. sensibilidade_taxa_juros.png - Sensibilidade à taxa (4%-8%)")
end

println("\n💡 Interpretação:")
println("   • Encargo = custo das pensões em \"anos de benefício\" ao valor presente")
println("   • Taxa 6% a.a., tábua AT-2012 IAM Basic (SOA)")
println("   • Inclui cônjuge (vitalício) + filhos ≤ 24 anos (temporário)")
println("   • Percentual: 50% + 10% × n_dependentes (max 100%)")
println("=" ^ 70)
