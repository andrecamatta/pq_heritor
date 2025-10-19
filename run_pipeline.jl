#!/usr/bin/env julia
# Pipeline Completo - Tábua de Conjugalidade e Age Gap
# Versão refatorada usando módulos compartilhados (src/)

println("\n")
println("╔" * "═"^70 * "╗")
println("║" * " "^5 * "PIPELINE COMPLETO - FUNÇÃO HERITOR E RESERVA (v3.0)" * " "^9 * "║")
println("║" * " "^5 * "População Geral vs. Servidores Públicos (PNADC 2023)" * " "^11 * "║")
println("║" * " "^8 * "Conjugalidade → Age Gap → Filhos → Encargo → Reserva" * " "^7 * "║")
println("╚" * "═"^70 * "╝")
println("\n")

# Verificar se estamos no ambiente correto
if !isfile("Project.toml")
    println("❌ ERRO: Execute este script no diretório raiz do projeto!")
    exit(1)
end

# Ativar ambiente do projeto
using Pkg
Pkg.activate(".")

println("📦 Verificando dependências...")
try
    Pkg.instantiate()
    println("✅ Dependências instaladas\n")
catch e
    println("❌ Erro ao instalar dependências: $e")
    exit(1)
end

# Criar diretórios necessários
println("📁 Criando diretórios...")
mkpath("dados")
mkpath("resultados")
mkpath("resultados/graficos")
println("✅ Diretórios criados\n")

# Scripts do pipeline (em ordem de execução)
pipeline_scripts = [
    # Fase 1: Conjugalidade
    "01_processar_dados.jl",
    "02_tabua_conjugalidade.jl",
    "03_grafico_prevalencia_simples.jl",
    "04_credibilidade_servidores.jl",

    # Fase 2: Age Gap
    "05_age_gap_servidores.jl",
    "06_analise_distribuicao_age_gap.jl",
    "07_samplear_age_gap.jl",
    "08_grafico_age_gap.jl",

    # Fase 3: Filhos
    "09_processar_filhos.jl",
    "10_tabua_filhos.jl",
    "11_credibilidade_filhos.jl",
    "12_grafico_filhos.jl",

    # Fase 4: Heritor (amostragem de beneficiários)
    "13_samplear_heritor.jl",

    # Fase 5: Encargo Atuarial
    "14_calcular_encargo_tabela.jl",
    "15_grafico_encargo.jl",

    # Fase 6: Reserva Matemática
    "16_calcular_reserva_pensao.jl",
    "17_grafico_reserva_pensao.jl"
]

# Descrições dos scripts
descricoes = Dict(
    # Fase 1: Conjugalidade
    "01_processar_dados.jl" => "Processar microdados PNADC 2023",
    "02_tabua_conjugalidade.jl" => "Calcular tábua de conjugalidade (com pesos amostrais)",
    "03_grafico_prevalencia_simples.jl" => "Gerar gráficos de prevalências",
    "04_credibilidade_servidores.jl" => "Aplicar credibilidade Bühlmann-Straub + suavização",

    # Fase 2: Age Gap
    "05_age_gap_servidores.jl" => "Calcular μ(idade) e σ(idade) de age gap com credibilidade",
    "06_analise_distribuicao_age_gap.jl" => "Análise exploratória (Normal vs t-Student)",
    "07_samplear_age_gap.jl" => "Teste de amostragem Monte Carlo",
    "08_grafico_age_gap.jl" => "Gerar gráficos de age gap",

    # Fase 3: Filhos
    "09_processar_filhos.jl" => "Processar dados de filhos (PNADC 2023)",
    "10_tabua_filhos.jl" => "Calcular tábua de filhos (n_filhos, idade)",
    "11_credibilidade_filhos.jl" => "Aplicar credibilidade Bühlmann-Straub",
    "12_grafico_filhos.jl" => "Gerar gráficos de filhos",

    # Fase 4: Heritor
    "13_samplear_heritor.jl" => "Teste de amostragem completa de beneficiários",

    # Fase 5: Encargo Atuarial
    "14_calcular_encargo_tabela.jl" => "Calcular encargo atuarial (30-80 anos, ambos sexos)",
    "15_grafico_encargo.jl" => "Gerar gráficos de encargo (5 gráficos)",

    # Fase 6: Reserva Matemática
    "16_calcular_reserva_pensao.jl" => "Calcular reserva matemática (servidor vivo)",
    "17_grafico_reserva_pensao.jl" => "Gerar gráficos de reserva (4 gráficos)"
)

# Executar pipeline
total = length(pipeline_scripts)
sucessos = 0
falhas = 0

for (i, script) in enumerate(pipeline_scripts)
    println("\n" * "━"^70)
    println("[$i/$total] $(descricoes[script])")
    println("━"^70)

    if !isfile(script)
        println("⚠️  Script não encontrado: $script (pulando)")
        continue
    end

    try
        # Executar script
        include(script)
        sucessos += 1
        println("\n✅ [$i/$total] Concluído: $script")
    catch e
        falhas += 1
        println("\n❌ [$i/$total] ERRO em $script:")
        println("   $e")

        # Perguntar se deve continuar
        print("\n⚠️  Continuar com próximo script? (s/n): ")
        resposta = readline()
        if lowercase(strip(resposta)) != "s"
            println("\n🛑 Pipeline interrompido pelo usuário.")
            break
        end
    end
end

# Resumo final
println("\n\n" * "╔" * "═"^70 * "╗")
println("║" * " "^22 * "RESUMO DO PIPELINE" * " "^28 * "║")
println("╠" * "═"^70 * "╣")
println("║  ✅ Scripts executados com sucesso: $sucessos/$total" * " "^(50 - length("$sucessos/$total")) * "║")
if falhas > 0
    println("║  ❌ Scripts com falhas: $falhas/$total" * " "^(56 - length("$falhas/$total")) * "║")
end
println("╚" * "═"^70 * "╝")

if falhas == 0
    println("\n🎉 Pipeline concluído com sucesso!")
    println("\n📊 Resultados gerados:")
    println("   - Tábuas: resultados/*.csv")
    println("   - Gráficos: resultados/graficos/*.png")
    println("   - Diagnósticos: resultados/*.txt")
    println("\n📌 Próximo passo: Revisar resultados/conjugalidade_credivel.csv e age_gap_credivel.csv")
else
    println("\n⚠️  Pipeline concluído com $falhas erro(s).")
    println("   Revise as mensagens acima para detalhes.")
end

println("\n")
