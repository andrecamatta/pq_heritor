#!/usr/bin/env julia
# Script para gerar gráficos de métricas de filhos
# Comparação: População geral vs Servidores (credível)

using CSV
using DataFrames
using Plots
using Statistics

println("=" ^ 70)
println("GRÁFICOS - Métricas de Filhos")
println("=" ^ 70)

# ============================================================================
# CONFIGURAÇÃO
# ============================================================================

# Diretórios
RESULTADOS_DIR = "resultados"
GRAFICOS_DIR = joinpath(RESULTADOS_DIR, "graficos")
ARQUIVO_DADOS = joinpath(RESULTADOS_DIR, "filhos_credivel.csv")

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

if !isfile(ARQUIVO_DADOS)
    println("\nERRO: Arquivo não encontrado: $ARQUIVO_DADOS")
    println("Execute primeiro: julia --project=. 13_credibilidade_filhos.jl")
    exit(1)
end

println("\nCarregando dados...")
df = CSV.read(ARQUIVO_DADOS, DataFrame)
println("✓ Dados carregados: $(nrow(df)) registros")

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
# GRÁFICO 1: PREVALÊNCIA DE TER FILHO ≤ 24
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 1: Prevalência de ter filho ≤ 24 anos")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados = filter(row -> row.sexo == sexo, df)

    println("\nGerando gráfico: $sexo")

    p = plot(
        title="Prevalência de ter filho ≤ 24 anos - $sexo",
        xlabel="Idade (anos)",
        ylabel="Prevalência (%)",
        legend=:topright,
        ylims=(0, 100)
    )

    # População geral (linha azul)
    plot!(p, dados.idade, dados.prev_filho_geral,
          label="População geral",
          color=:blue,
          linewidth=2,
          alpha=0.8)

    # Servidores observado (pontos coral dispersos)
    dados_serv_obs = filter(row -> row.n_serv_amostra > 0, dados)
    scatter!(p, dados_serv_obs.idade, dados_serv_obs.prev_filho_serv_obs,
             label="Servidores (observado)",
             color=:coral,
             markersize=3,
             alpha=0.6,
             markerstrokewidth=0)

    # Servidores credível (linha laranja destacada)
    plot!(p, dados.idade, dados.prev_filho_suavizado,
          label="Servidores (credível)",
          color=:orange,
          linewidth=3,
          alpha=0.9)

    # Estatísticas no gráfico
    prev_max_geral = maximum(dados.prev_filho_geral)
    idade_max_geral = dados.idade[argmax(dados.prev_filho_geral)]

    prev_max_serv = maximum(dados.prev_filho_suavizado)
    idade_max_serv = dados.idade[argmax(dados.prev_filho_suavizado)]

    annotate!(p, [(
        85, 95,
        text("Pico (geral): $(round(prev_max_geral, digits=1))% aos $idade_max_geral anos\n" *
             "Pico (serv): $(round(prev_max_serv, digits=1))% aos $idade_max_serv anos",
             :right, 9, :gray40)
    )])

    nome_arquivo = "prevalencia_filho_$(lowercase(sexo)).png"
    salvar_plot(p, nome_arquivo)
end

# ============================================================================
# GRÁFICO 2: IDADE DO FILHO MAIS NOVO
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 2: Idade do filho mais novo")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados = filter(row -> row.sexo == sexo, df)

    # Filtrar apenas idades onde há filhos
    dados = filter(row -> row.idade_filho_suavizado > 0, dados)

    if nrow(dados) == 0
        println("\n⚠️  Sem dados para $sexo")
        continue
    end

    println("\nGerando gráfico: $sexo")

    p = plot(
        title="Idade do filho mais novo - $sexo",
        xlabel="Idade do responsável/cônjuge (anos)",
        ylabel="Idade do filho mais novo (anos)",
        legend=:topleft,
        ylims=(0, 25)
    )

    # Linha de referência: filho nasceu quando pai tinha 25 anos
    # idade_filho = idade_pai - 25
    plot!(p, 25:90, 0:65,
          label="Filho nasceu aos 25 anos do pai",
          color=:gray,
          linestyle=:dash,
          linewidth=1,
          alpha=0.5)

    # População geral (linha azul)
    dados_geral = filter(row -> row.idade_filho_geral > 0, dados)
    if nrow(dados_geral) > 0
        plot!(p, dados_geral.idade, dados_geral.idade_filho_geral,
              label="População geral",
              color=:blue,
              linewidth=2,
              alpha=0.8)
    end

    # Servidores observado (pontos coral)
    dados_serv_obs = filter(row -> row.n_serv_amostra > 0 &&
                                   row.idade_filho_serv_obs > 0, dados)
    if nrow(dados_serv_obs) > 0
        scatter!(p, dados_serv_obs.idade, dados_serv_obs.idade_filho_serv_obs,
                 label="Servidores (observado)",
                 color=:coral,
                 markersize=3,
                 alpha=0.6,
                 markerstrokewidth=0)
    end

    # Servidores credível (linha laranja)
    plot!(p, dados.idade, dados.idade_filho_suavizado,
          label="Servidores (credível)",
          color=:orange,
          linewidth=3,
          alpha=0.9)

    # Banda de confiança (μ ± σ)
    idade_superior = min.(dados.idade_filho_suavizado .+ dados.idade_filho_sd_suavizado, 24)
    idade_inferior = max.(dados.idade_filho_suavizado .- dados.idade_filho_sd_suavizado, 0)

    plot!(p, dados.idade, idade_superior,
          fillrange=idade_inferior,
          fillalpha=0.15,
          fillcolor=:orange,
          linealpha=0,
          label="μ ± σ (servidores)")

    nome_arquivo = "idade_filho_mais_novo_$(lowercase(sexo)).png"
    salvar_plot(p, nome_arquivo)
end

# ============================================================================
# GRÁFICO 3: NÚMERO MÉDIO DE FILHOS
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 3: Número médio de filhos ≤ 24 anos")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados = filter(row -> row.sexo == sexo, df)

    println("\nGerando gráfico: $sexo")

    p = plot(
        title="Número médio de filhos ≤ 24 anos - $sexo",
        xlabel="Idade (anos)",
        ylabel="Número médio de filhos",
        legend=:topright,
        ylims=(0, :auto)
    )

    # Linha de referência: 1 filho
    hline!(p, [1.0],
           label="1 filho",
           color=:gray,
           linestyle=:dash,
           linewidth=1,
           alpha=0.5)

    # População geral (linha azul)
    plot!(p, dados.idade, dados.n_filhos_geral,
          label="População geral",
          color=:blue,
          linewidth=2,
          alpha=0.8)

    # Servidores observado (pontos coral)
    dados_serv_obs = filter(row -> row.n_serv_amostra > 0, dados)
    scatter!(p, dados_serv_obs.idade, dados_serv_obs.n_filhos_serv_obs,
             label="Servidores (observado)",
             color=:coral,
             markersize=3,
             alpha=0.6,
             markerstrokewidth=0)

    # Servidores credível (linha laranja)
    plot!(p, dados.idade, dados.n_filhos_suavizado,
          label="Servidores (credível)",
          color=:orange,
          linewidth=3,
          alpha=0.9)

    # Estatísticas
    n_max_geral = maximum(dados.n_filhos_geral)
    idade_max_geral = dados.idade[argmax(dados.n_filhos_geral)]

    n_max_serv = maximum(dados.n_filhos_suavizado)
    idade_max_serv = dados.idade[argmax(dados.n_filhos_suavizado)]

    annotate!(p, [(
        85, maximum(dados.n_filhos_suavizado) * 0.95,
        text("Pico (geral): $(round(n_max_geral, digits=2)) aos $idade_max_geral anos\n" *
             "Pico (serv): $(round(n_max_serv, digits=2)) aos $idade_max_serv anos",
             :right, 9, :gray40)
    )])

    nome_arquivo = "n_filhos_medio_$(lowercase(sexo)).png"
    salvar_plot(p, nome_arquivo)
end

# ============================================================================
# GRÁFICO 4: DESVIO-PADRÃO DA IDADE DO FILHO
# ============================================================================

println("\n" * "=" ^ 70)
println("GRÁFICO 4: Desvio-padrão da idade do filho mais novo")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados = filter(row -> row.sexo == sexo, df)

    # Filtrar apenas idades onde há filhos
    dados = filter(row -> row.idade_filho_sd_suavizado > 0, dados)

    if nrow(dados) == 0
        println("\n⚠️  Sem dados para $sexo")
        continue
    end

    println("\nGerando gráfico: $sexo")

    p = plot(
        title="Desvio-padrão da idade do filho mais novo - $sexo",
        xlabel="Idade do responsável/cônjuge (anos)",
        ylabel="σ (anos)",
        legend=:topright,
        ylims=(0, :auto)
    )

    # População geral (linha azul)
    dados_geral = filter(row -> row.idade_filho_sd_geral > 0, dados)
    if nrow(dados_geral) > 0
        plot!(p, dados_geral.idade, dados_geral.idade_filho_sd_geral,
              label="População geral",
              color=:blue,
              linewidth=2,
              alpha=0.8)
    end

    # Servidores observado (pontos coral)
    dados_serv_obs = filter(row -> row.n_serv_amostra > 0 &&
                                   row.idade_filho_sd_serv_obs > 0, dados)
    if nrow(dados_serv_obs) > 0
        scatter!(p, dados_serv_obs.idade, dados_serv_obs.idade_filho_sd_serv_obs,
                 label="Servidores (observado)",
                 color=:coral,
                 markersize=3,
                 alpha=0.6,
                 markerstrokewidth=0)
    end

    # Servidores credível (linha laranja)
    plot!(p, dados.idade, dados.idade_filho_sd_suavizado,
          label="Servidores (credível)",
          color=:orange,
          linewidth=3,
          alpha=0.9)

    # Estatísticas
    sd_media_geral = mean(dados_geral.idade_filho_sd_geral)
    sd_media_serv = mean(dados.idade_filho_sd_suavizado)

    annotate!(p, [(
        85, maximum(dados.idade_filho_sd_suavizado) * 0.95,
        text("σ médio (geral): $(round(sd_media_geral, digits=1)) anos\n" *
             "σ médio (serv): $(round(sd_media_serv, digits=1)) anos",
             :right, 9, :gray40)
    )])

    nome_arquivo = "idade_filho_sd_$(lowercase(sexo)).png"
    salvar_plot(p, nome_arquivo)
end

# ============================================================================
# SUMÁRIO
# ============================================================================

println("\n" * "=" ^ 70)
println("✓ Gráficos gerados com sucesso!")
println("=" ^ 70)
println("\nArquivos salvos em: $GRAFICOS_DIR")
println("\nGráficos gerados:")
println("  1. prevalencia_filho_*.png - P(ter filho ≤ 24)")
println("  2. idade_filho_mais_novo_*.png - Idade do filho mais novo")
println("  3. n_filhos_medio_*.png - Número médio de filhos")
println("  4. idade_filho_sd_*.png - Desvio-padrão da idade")
println("=" ^ 70)
