#!/usr/bin/env julia
# Cálculo de Tabela de Encargo Atuarial por Idade e Sexo
# Calcula encargo para idades 30-80 anos (ano a ano) para Masculino e Feminino

using DataFrames
using CSV
using Statistics
using Printf

println("=" ^ 70)
println("CÁLCULO DE TABELA DE ENCARGO ATUARIAL")
println("=" ^ 70)

# ============================================================================
# CONFIGURAÇÃO
# ============================================================================

# Carregar módulo Atuarial
include("src/Atuarial.jl")
using .Atuarial

# Diretórios
RESULTADOS_DIR = "resultados"
if !isdir(RESULTADOS_DIR)
    mkpath(RESULTADOS_DIR)
end

ARQUIVO_ENCARGO = joinpath(RESULTADOS_DIR, "encargo_heritor.csv")
ARQUIVO_SENSIBILIDADE = joinpath(RESULTADOS_DIR, "encargo_sensibilidade_taxa.csv")

# Parâmetros
IDADE_MIN = 30
IDADE_MAX = 80
N_SAMPLES = 10_000  # Amostras Monte Carlo por combinação idade-sexo
TAXA_PADRAO = 0.06  # 6% a.a.
SEED = 42           # Para reprodutibilidade

# Sensibilidade à taxa
TAXAS_TESTE = [0.04, 0.05, 0.06, 0.07, 0.08]
IDADES_REPRESENTATIVAS = [40, 50, 60, 70]

# ============================================================================
# CÁLCULO PRINCIPAL: ENCARGO POR IDADE E SEXO
# ============================================================================

println("\n" * "=" ^ 70)
println("CÁLCULO DO ENCARGO ATUARIAL")
println("=" ^ 70)
println("\nParâmetros:")
println("  Idades: $IDADE_MIN-$IDADE_MAX anos (ano a ano)")
println("  Sexos: Masculino, Feminino")
println("  Amostras: $(N_SAMPLES) por combinação")
println("  Taxa padrão: $(100*TAXA_PADRAO)% a.a.")
println("  Total de cálculos: $((IDADE_MAX - IDADE_MIN + 1) * 2)")

# DataFrame para armazenar resultados
resultados = DataFrame(
    idade = Int[],
    sexo = String[],
    encargo_medio = Float64[],
    encargo_mediano = Float64[],
    encargo_p10 = Float64[],
    encargo_p90 = Float64[],
    encargo_min = Float64[],
    encargo_max = Float64[],
    percentual_pensao_medio = Float64[],
    n_amostras = Int[]
)

# Loop por sexo e idade
total_calculos = (IDADE_MAX - IDADE_MIN + 1) * 2
contador = 0

for sexo in ["Masculino", "Feminino"]
    println("\n" * "-" ^ 70)
    println("Processando: $sexo")
    println("-" ^ 70)

    for idade in IDADE_MIN:IDADE_MAX
        global contador += 1

        # Progress bar simples
        progresso = round(100 * contador / total_calculos, digits=1)
        print("\r[$contador/$total_calculos - $progresso%] Calculando: $sexo, $idade anos...")
        flush(stdout)

        # Calcular encargo
        resultado = calcular_encargo_heritor(
            idade, sexo,
            n_samples=N_SAMPLES,
            taxa_juros=TAXA_PADRAO,
            seed=SEED + contador  # Seed diferente para cada cálculo
        )

        # Adicionar ao DataFrame
        push!(resultados, (
            idade = idade,
            sexo = sexo,
            encargo_medio = resultado.encargo_medio[1],
            encargo_mediano = resultado.encargo_mediano[1],
            encargo_p10 = resultado.encargo_p10[1],
            encargo_p90 = resultado.encargo_p90[1],
            encargo_min = resultado.encargo_min[1],
            encargo_max = resultado.encargo_max[1],
            percentual_pensao_medio = resultado.percentual_pensao_medio[1],
            n_amostras = N_SAMPLES
        ))
    end
end

println("\n\n✓ Cálculos concluídos!")

# ============================================================================
# SALVAR TABELA PRINCIPAL
# ============================================================================

println("\n" * "=" ^ 70)
println("SALVANDO RESULTADOS")
println("=" ^ 70)

CSV.write(ARQUIVO_ENCARGO, resultados)
println("\n✓ Tabela salva: $ARQUIVO_ENCARGO")
println("  Registros: $(nrow(resultados))")
println("  Colunas: $(join(names(resultados), ", "))")

# ============================================================================
# ANÁLISE DE SENSIBILIDADE À TAXA DE JUROS
# ============================================================================

println("\n" * "=" ^ 70)
println("ANÁLISE DE SENSIBILIDADE À TAXA DE JUROS")
println("=" ^ 70)
println("\nCalculando encargo para diferentes taxas...")
println("  Taxas: $(join(map(t -> "$(100*t)%", TAXAS_TESTE), ", "))")
println("  Idades: $(join(IDADES_REPRESENTATIVAS, ", ")) anos")
println("  Sexos: Masculino, Feminino")

sensibilidade = DataFrame(
    taxa_juros = Float64[],
    idade = Int[],
    sexo = String[],
    encargo_medio = Float64[]
)

total_sens = length(TAXAS_TESTE) * length(IDADES_REPRESENTATIVAS) * 2
contador_sens = 0

for taxa in TAXAS_TESTE
    for idade in IDADES_REPRESENTATIVAS
        for sexo in ["Masculino", "Feminino"]
            global contador_sens += 1

            print("\r[$contador_sens/$total_sens] Taxa $(100*taxa)%, $sexo $idade anos...")
            flush(stdout)

            resultado = calcular_encargo_heritor(
                idade, sexo,
                n_samples=N_SAMPLES,
                taxa_juros=taxa,
                seed=SEED + 1000 + contador_sens
            )

            push!(sensibilidade, (
                taxa_juros = 100 * taxa,  # Converter para percentual
                idade = idade,
                sexo = sexo,
                encargo_medio = resultado.encargo_medio[1]
            ))
        end
    end
end

println("\n\n✓ Análise de sensibilidade concluída!")

# Salvar tabela de sensibilidade
CSV.write(ARQUIVO_SENSIBILIDADE, sensibilidade)
println("\n✓ Tabela de sensibilidade salva: $ARQUIVO_SENSIBILIDADE")
println("  Registros: $(nrow(sensibilidade))")

# ============================================================================
# RESUMO ESTATÍSTICO
# ============================================================================

println("\n" * "=" ^ 70)
println("RESUMO ESTATÍSTICO - ENCARGO ATUARIAL")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados_sexo = filter(row -> row.sexo == sexo, resultados)

    println("\n$sexo:")
    println("  Encargo médio geral: $(round(mean(dados_sexo.encargo_medio), digits=2)) anos")
    println("  Faixa: $(round(minimum(dados_sexo.encargo_medio), digits=2)) - $(round(maximum(dados_sexo.encargo_medio), digits=2)) anos")

    # Idade com maior encargo
    idx_max = argmax(dados_sexo.encargo_medio)
    idade_max = dados_sexo.idade[idx_max]
    encargo_max = dados_sexo.encargo_medio[idx_max]

    println("  Pico: $(round(encargo_max, digits=2)) anos aos $idade_max anos de idade")
    println("  % pensão médio: $(round(100 * mean(dados_sexo.percentual_pensao_medio), digits=1))%")
end

# Comparação entre sexos
println("\nComparação:")
dados_masc = filter(row -> row.sexo == "Masculino", resultados)
dados_fem = filter(row -> row.sexo == "Feminino", resultados)

dif_media = mean(dados_fem.encargo_medio) - mean(dados_masc.encargo_medio)
println("  Diferença (Fem - Masc): $(round(dif_media, digits=2)) anos")
println("    → Mulheres têm $(dif_media > 0 ? "maior" : "menor") encargo médio")

# ============================================================================
# SENSIBILIDADE À TAXA
# ============================================================================

println("\n" * "=" ^ 70)
println("RESUMO - SENSIBILIDADE À TAXA DE JUROS")
println("=" ^ 70)

for idade in IDADES_REPRESENTATIVAS
    println("\nIdade $idade anos:")

    for sexo in ["Masculino", "Feminino"]
        dados_sensibilidade = filter(row -> row.idade == idade && row.sexo == sexo, sensibilidade)

        if nrow(dados_sensibilidade) > 0
            println("  $sexo:")
            for row in eachrow(dados_sensibilidade)
                println("    $(row.taxa_juros)%: $(round(row.encargo_medio, digits=2)) anos")
            end
        end
    end
end

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

println("\n" * "=" ^ 70)
println("✓ TABELAS GERADAS COM SUCESSO!")
println("=" ^ 70)

println("\nArquivos salvos:")
println("  1. $ARQUIVO_ENCARGO")
println("     → Encargo por idade e sexo ($(nrow(resultados)) registros)")
println("\n  2. $ARQUIVO_SENSIBILIDADE")
println("     → Sensibilidade à taxa de juros ($(nrow(sensibilidade)) registros)")

println("\n💡 Próximo passo:")
println("   julia --project=. 18_grafico_encargo.jl")
println("=" ^ 70)
