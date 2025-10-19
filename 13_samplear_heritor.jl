#!/usr/bin/env julia
# Amostragem Monte Carlo para Função Heritor
# Sorteia características de beneficiários (cônjuge e filhos) de servidores estatutários

using Statistics
using Printf

# Carregar módulo Heritor
include("src/Heritor.jl")
using .Heritor

println("=" ^ 70)
println("AMOSTRAGEM MONTE CARLO - Função Heritor")
println("=" ^ 70)

# ============================================================================
# EXEMPLOS DE USO E TESTES
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    println("\n" * "=" ^ 70)
    println("EXEMPLOS DE USO")
    println("=" ^ 70)

    # Exemplo 1: Servidor homem de 60 anos
    println("\n[Exemplo 1] Servidor: Homem, 60 anos (10k amostras)")
    println("─" ^ 70)

    amostras_60m = samplear_caracteristicas_heritor(60, "Masculino", n_samples=10_000, seed=42)

    println("\nCaracterísticas sorteadas:")
    println("  P(casado): $(round(100*mean(amostras_60m.casado), digits=1))%")

    idades_conj = collect(skipmissing(amostras_60m.idade_conjuge))
    if length(idades_conj) > 0
        println("  Idade média cônjuge (se casado): $(round(mean(idades_conj), digits=1)) anos")
        println("  Idade mediana cônjuge: $(round(median(idades_conj), digits=1)) anos")
        println("  Intervalo [P5, P95]: [$(round(quantile(idades_conj, 0.05), digits=1)), $(round(quantile(idades_conj, 0.95), digits=1))] anos")
    end

    println("\n  P(tem filho ≤ 24): $(round(100*mean(amostras_60m.tem_filho), digits=1))%")

    n_filhos_com = amostras_60m.n_filhos[amostras_60m.tem_filho]
    if length(n_filhos_com) > 0
        println("  N° médio filhos (se tem): $(round(mean(n_filhos_com), digits=2))")
        println("  N° mediano filhos: $(median(n_filhos_com))")
    end

    idades_filho = collect(skipmissing(amostras_60m.idade_filho_mais_novo))
    if length(idades_filho) > 0
        println("  Idade média filho mais novo (se tem): $(round(mean(idades_filho), digits=1)) anos")
        println("  Intervalo [P5, P95]: [$(round(quantile(idades_filho, 0.05), digits=1)), $(round(quantile(idades_filho, 0.95), digits=1))] anos")
    end

    # Exemplo 2: Servidora mulher de 45 anos
    println("\n\n[Exemplo 2] Servidora: Mulher, 45 anos (10k amostras)")
    println("─" ^ 70)

    amostras_45f = samplear_caracteristicas_heritor(45, "Feminino", n_samples=10_000, seed=123)

    println("\nCaracterísticas sorteadas:")
    println("  P(casado): $(round(100*mean(amostras_45f.casado), digits=1))%")

    idades_conj_f = collect(skipmissing(amostras_45f.idade_conjuge))
    if length(idades_conj_f) > 0
        println("  Idade média cônjuge (se casado): $(round(mean(idades_conj_f), digits=1)) anos")
        println("  Idade mediana cônjuge: $(round(median(idades_conj_f), digits=1)) anos")
        println("  Intervalo [P5, P95]: [$(round(quantile(idades_conj_f, 0.05), digits=1)), $(round(quantile(idades_conj_f, 0.95), digits=1))] anos")
    end

    println("\n  P(tem filho ≤ 24): $(round(100*mean(amostras_45f.tem_filho), digits=1))%")

    n_filhos_com_f = amostras_45f.n_filhos[amostras_45f.tem_filho]
    if length(n_filhos_com_f) > 0
        println("  N° médio filhos (se tem): $(round(mean(n_filhos_com_f), digits=2))")
        println("  N° mediano filhos: $(median(n_filhos_com_f))")
    end

    idades_filho_f = collect(skipmissing(amostras_45f.idade_filho_mais_novo))
    if length(idades_filho_f) > 0
        println("  Idade média filho mais novo (se tem): $(round(mean(idades_filho_f), digits=1)) anos")
        println("  Intervalo [P5, P95]: [$(round(quantile(idades_filho_f, 0.05), digits=1)), $(round(quantile(idades_filho_f, 0.95), digits=1))] anos")
    end

    # Exemplo 3: Pequena amostra para visualização
    println("\n\n[Exemplo 3] Visualização: 10 amostras para servidor homem de 55 anos")
    println("─" ^ 70)

    amostras_vis = samplear_caracteristicas_heritor(55, "Masculino", n_samples=10, seed=999)

    println("\nPrimeiras 10 amostras:")
    println(amostras_vis)

    println("\n" * "=" ^ 70)
    println("✓ Exemplos executados com sucesso!")
    println("=" ^ 70)
    println("\n💡 Para usar em seu código:")
    println("   include(\"src/Heritor.jl\")")
    println("   using .Heritor")
    println("   amostras = samplear_caracteristicas_heritor(idade, sexo, n_samples=100_000)")
    println("\n💡 Ou simplesmente:")
    println("   julia --project=. 15_samplear_heritor.jl")
    println("=" ^ 70)
end
