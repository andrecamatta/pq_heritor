#!/usr/bin/env julia
# Cálculo de Reserva Matemática de Pensão
# Para servidor VIVO de idade x, calcula valor presente do direito de pensão
#
# DIFERENÇA vs Função Heritor:
# - Heritor: Custo SE morrer em idade x (condicional)
# - Reserva: Valor esperado DADO QUE está vivo hoje

using DataFrames
using CSV
using Statistics
using Printf

println("=" ^ 70)
println("CÁLCULO DE RESERVA MATEMÁTICA DE PENSÃO")
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

ARQUIVO_RESERVA = joinpath(RESULTADOS_DIR, "reserva_pensao.csv")

# Parâmetros
IDADE_MIN = 30
IDADE_MAX = 80
TAXA_JUROS = 0.06  # 6% a.a.

# ============================================================================
# CÁLCULO PRINCIPAL: RESERVA POR IDADE E SEXO
# ============================================================================

println("\n" * "=" ^ 70)
println("CÁLCULO DA RESERVA DE PENSÃO")
println("=" ^ 70)
println("\nParâmetros:")
println("  Idades: $IDADE_MIN-$IDADE_MAX anos (ano a ano)")
println("  Sexos: Masculino, Feminino")
println("  Taxa: $(100*TAXA_JUROS)% a.a.")
println("  Total de cálculos: $((IDADE_MAX - IDADE_MIN + 1) * 2)")
println("\n💡 Interpretação:")
println("   Reserva = Valor presente esperado do custo de pensões")
println("   para um servidor VIVO de idade x hoje.")

# DataFrame para armazenar resultados
resultados = DataFrame(
    idade_atual = Int[],
    sexo = String[],
    reserva_total = Float64[],
    reserva_por_ano_vida = Float64[],
    expectativa_vida = Float64[],
    prob_deixar_pensao = Float64[]
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

        # Progress bar
        progresso = round(100 * contador / total_calculos, digits=1)
        print("\r[$contador/$total_calculos - $progresso%] Calculando: $sexo, $idade anos...")
        flush(stdout)

        # Calcular reserva
        res = calcular_reserva_pensao(idade, sexo, taxa_juros=TAXA_JUROS)

        # Adicionar ao DataFrame
        append!(resultados, res)
    end
end

println("\n\n✓ Cálculos concluídos!")

# ============================================================================
# SALVAR TABELA
# ============================================================================

println("\n" * "=" ^ 70)
println("SALVANDO RESULTADOS")
println("=" ^ 70)

CSV.write(ARQUIVO_RESERVA, resultados)
println("\n✓ Tabela salva: $ARQUIVO_RESERVA")
println("  Registros: $(nrow(resultados))")
println("  Colunas: $(join(names(resultados), ", "))")

# ============================================================================
# RESUMO ESTATÍSTICO
# ============================================================================

println("\n" * "=" ^ 70)
println("RESUMO ESTATÍSTICO - RESERVA DE PENSÃO")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados_sexo = filter(row -> row.sexo == sexo, resultados)

    println("\n$sexo:")
    println("  Reserva média geral: $(round(mean(dados_sexo.reserva_total), digits=2)) anos")
    println("  Faixa: $(round(minimum(dados_sexo.reserva_total), digits=2)) - $(round(maximum(dados_sexo.reserva_total), digits=2)) anos")

    # Idade com maior reserva
    idx_max = argmax(dados_sexo.reserva_total)
    idade_max = dados_sexo.idade_atual[idx_max]
    reserva_max = dados_sexo.reserva_total[idx_max]

    println("  Pico: $(round(reserva_max, digits=2)) anos aos $idade_max anos de idade")

    # Expectativa de vida média
    println("  Expectativa de vida média: $(round(mean(dados_sexo.expectativa_vida), digits=1)) anos")

    # Probabilidade média de deixar pensão
    println("  P(deixar pensão) médio: $(round(100 * mean(dados_sexo.prob_deixar_pensao), digits=1))%")
end

# Comparação entre sexos
println("\nComparação:")
dados_masc = filter(row -> row.sexo == "Masculino", resultados)
dados_fem = filter(row -> row.sexo == "Feminino", resultados)

dif_media = mean(dados_masc.reserva_total) - mean(dados_fem.reserva_total)
println("  Diferença (Masc - Fem): $(round(dif_media, digits=2)) anos")
println("    → Homens têm $(abs(dif_media) > 0.01 ? (dif_media > 0 ? "maior" : "menor") : "igual") reserva média")

# ============================================================================
# EXEMPLOS PRÁTICOS
# ============================================================================

println("\n" * "=" ^ 70)
println("EXEMPLOS DE APLICAÇÃO PRÁTICA")
println("=" ^ 70)

# Exemplo 1: Servidor homem 55 anos
exemplo_55m = filter(row -> row.idade_atual == 55 && row.sexo == "Masculino", resultados)
if nrow(exemplo_55m) > 0
    println("\n[Exemplo 1] Servidor Homem, 55 anos (VIVO hoje):")
    println("  Reserva: $(round(exemplo_55m[1, :reserva_total], digits=2)) anos de benefício")
    println("  Expectativa de vida: $(round(exemplo_55m[1, :expectativa_vida], digits=1)) anos")
    println("  P(deixar pensão): $(round(100 * exemplo_55m[1, :prob_deixar_pensao], digits=1))%")
    println("\n  💰 Aplicação:")
    println("     - Benefício anual: R\$ 10.000")
    println("     - Reserva por servidor: $(round(exemplo_55m[1, :reserva_total], digits=2)) × R\$ 10.000 = R\$ $(round(exemplo_55m[1, :reserva_total] * 10000, digits=0))")
    println("     - Para 1.000 servidores: R\$ $(round(exemplo_55m[1, :reserva_total] * 10000 * 1000 / 1e6, digits=1)) milhões")
end

# Exemplo 2: Servidora mulher 50 anos
exemplo_50f = filter(row -> row.idade_atual == 50 && row.sexo == "Feminino", resultados)
if nrow(exemplo_50f) > 0
    println("\n[Exemplo 2] Servidora Mulher, 50 anos (VIVA hoje):")
    println("  Reserva: $(round(exemplo_50f[1, :reserva_total], digits=2)) anos de benefício")
    println("  Expectativa de vida: $(round(exemplo_50f[1, :expectativa_vida], digits=1)) anos")
    println("  P(deixar pensão): $(round(100 * exemplo_50f[1, :prob_deixar_pensao], digits=1))%")
    println("\n  💰 Aplicação:")
    println("     - Benefício anual: R\$ 10.000")
    println("     - Reserva por servidora: $(round(exemplo_50f[1, :reserva_total], digits=2)) × R\$ 10.000 = R\$ $(round(exemplo_50f[1, :reserva_total] * 10000, digits=0))")
    println("     - Para 1.000 servidoras: R\$ $(round(exemplo_50f[1, :reserva_total] * 10000 * 1000 / 1e6, digits=1)) milhões")
end

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

println("\n" * "=" ^ 70)
println("✓ TABELA GERADA COM SUCESSO!")
println("=" ^ 70)

println("\nArquivo salvo:")
println("  $ARQUIVO_RESERVA")
println("  → Reserva de pensão por idade e sexo ($(nrow(resultados)) registros)")

println("\n💡 Próximo passo:")
println("   julia --project=. 20_grafico_reserva_pensao.jl")
println("\n💡 Diferença vs Função Heritor:")
println("   - Heritor (17): Custo SE morrer em idade x (condicional)")
println("   - Reserva (19): Valor esperado DADO QUE está vivo hoje")
println("=" ^ 70)
