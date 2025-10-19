#!/usr/bin/env julia
# Módulo de Amostragem de Age Gap para Monte Carlo
#
# Uso: Função heritor - estimar idade do cônjuge beneficiário de pensão
#
# Baseado em análise de distribuição (09a_analise_distribuicao_age_gap.jl):
# - Curtose alta (2-7) → caudas pesadas
# - Maioria dos testes rejeita normalidade
# - Recomendação: t-Student > Normal

using CSV
using DataFrames
using Distributions
using Statistics
using Random

println("=" ^ 70)
println("MÓDULO DE AMOSTRAGEM: AGE GAP")
println("=" ^ 70)

# ============================================================================
# CARREGAR DADOS SUAVIZADOS
# ============================================================================

RESULTADOS_DIR = "resultados"
arquivo_age_gap = joinpath(RESULTADOS_DIR, "age_gap_credivel.csv")

if !isfile(arquivo_age_gap)
    println("\nERRO: Arquivo não encontrado: $arquivo_age_gap")
    println("Execute primeiro: julia 09_age_gap_servidores.jl")
    exit(1)
end

println("\nCarregando parâmetros suavizados...")
df_age_gap = CSV.read(arquivo_age_gap, DataFrame)

# Criar dicionário para lookup rápido: (idade, sexo) => (μ, σ)
PARAMS_DICT = Dict{Tuple{Int, String}, Tuple{Float64, Float64}}()

for row in eachrow(df_age_gap)
    if !ismissing(row.agegap_suavizado) && !ismissing(row.sd_suavizado)
        key = (row.idade, row.sexo)
        μ = row.agegap_suavizado
        σ = row.sd_suavizado
        PARAMS_DICT[key] = (μ, σ)
    end
end

println("✓ Parâmetros carregados: $(length(PARAMS_DICT)) combinações (idade, sexo)")

# ============================================================================
# FUNÇÃO PRINCIPAL: SAMPLEAR AGE GAP
# ============================================================================

"""
    samplear_age_gap(idade::Int, sexo::String, n_samples::Int=10000;
                     distribuicao::Symbol=:tstudent, df_tstudent::Int=5,
                     truncar::Bool=true, idade_min::Float64=15.0, idade_max::Float64=100.0)

Amostra age gap para simulações Monte Carlo da função heritor.

# Argumentos
- `idade`: Idade do servidor (15-90)
- `sexo`: "Masculino" ou "Feminino"
- `n_samples`: Número de amostras (padrão: 10000)
- `distribuicao`: Distribuição a usar
  - `:normal` - Normal(μ, σ)
  - `:tstudent` - t-Student com df graus de liberdade (RECOMENDADO)
  - `:empirica` - Amostragem da distribuição empírica (NOT IMPLEMENTED)
- `df_tstudent`: Graus de liberdade para t-Student (padrão: 5)
- `truncar`: Truncar distribuição para idades REALISTAS? (padrão: true)
- `idade_min`: Idade mínima REALISTA do cônjuge (padrão: 15.0 anos)
  - 15 anos: Idade mínima nos dados PNADC + limite legal brasileiro
- `idade_max`: Idade máxima REALISTA do cônjuge (padrão: 100.0 anos)
  - 100 anos: Limite biológico razoável

⚠️ IMPORTANTE: `idade_min` e `idade_max` são limites para IDADE DO CÔNJUGE, não age gap!

# Truncamento
Quando `truncar=true` e `distribuicao=:tstudent`:
- t-Student é truncada ANTES de samplear (não pós-processamento)
- Garante que idade_cônjuge ∈ [idade_min, idade_max]
- Método: Truncated(TDist(df), limites normalizados)
- Impacto: Remove <0.5% de amostras extremas (caudas absurdas)

# Retorna
- `Vector{Float64}`: Amostras de age gap

# Uso atuarial
```julia
# Servidor homem de 60 anos falece
idade_servidor = 60
sexo = "Masculino"

# Monte Carlo: 10k cenários de idade do cônjuge
age_gaps = samplear_age_gap(idade_servidor, sexo, 10_000)
idades_conjuge = idade_servidor .- age_gaps

# Estatísticas
println("Cônjuge esperado:")
println("  Média: \$(mean(idades_conjuge)) anos")
println("  P10: \$(quantile(idades_conjuge, 0.1)) anos")
println("  P50: \$(quantile(idades_conjuge, 0.5)) anos")
println("  P90: \$(quantile(idades_conjuge, 0.9)) anos")

# Usar em função heritor:
# Para cada idade_conjuge[i]:
#   - Calcular expectativa de vida do beneficiário
#   - Calcular valor presente da pensão
#   - ...
vp_pensao = mean([calcular_vp(ic) for ic in idades_conjuge])
```

# Fundamentação
Baseado em análise exploratória (09a_analise_distribuicao_age_gap.jl):
- Curtose: 2-7 (caudas pesadas)
- Testes Anderson-Darling: rejeitam normalidade (p < 0.05) na maioria das faixas
- Recomendação: t-Student (df=5) captura caudas pesadas melhor que Normal

# Referências
- Análise: resultados/age_gap_diagnostico.txt
- Parâmetros: resultados/age_gap_credivel.csv (colunas agegap_suavizado, sd_suavizado)
"""
function samplear_age_gap(idade::Int, sexo::String, n_samples::Int=10000;
                          distribuicao::Symbol=:tstudent, df_tstudent::Int=5,
                          truncar::Bool=true, idade_min::Float64=15.0, idade_max::Float64=100.0)

    # Validar inputs
    if !(sexo in ["Masculino", "Feminino"])
        error("Sexo deve ser 'Masculino' ou 'Feminino', recebido: $sexo")
    end

    if idade < 15 || idade > 90
        @warn "Idade fora do intervalo [15, 90]: $idade. Extrapolando..."
    end

    # Obter parâmetros (μ, σ)
    key = (idade, sexo)

    if !haskey(PARAMS_DICT, key)
        # Idade sem dados: procurar vizinho mais próximo
        idades_disponiveis = [k[1] for k in keys(PARAMS_DICT) if k[2] == sexo]

        if isempty(idades_disponiveis)
            error("Nenhum dado disponível para sexo=$sexo")
        end

        idade_proxima = idades_disponiveis[argmin(abs.(idades_disponiveis .- idade))]
        @warn "Idade $idade ($sexo) sem dados. Usando idade $idade_proxima."

        key = (idade_proxima, sexo)
    end

    μ, σ = PARAMS_DICT[key]

    # Samplear da distribuição escolhida
    if distribuicao == :normal
        # Normal(μ, σ)
        dist = Normal(μ, σ)
        samples = rand(dist, n_samples)

    elseif distribuicao == :tstudent
        # t-Student: X ~ μ + σ * T(df)
        # onde T(df) ~ t-Student com df graus de liberdade

        if truncar
            # Truncar para garantir idades REALISTAS do cônjuge
            # idade_cônjuge = idade_servidor - age_gap
            # Queremos: idade_min <= idade_cônjuge <= idade_max
            # Portanto: idade - idade_max <= age_gap <= idade - idade_min

            age_gap_min = idade - idade_max  # ex: 60 - 100 = -40
            age_gap_max = idade - idade_min  # ex: 60 - 15 = 45

            # Truncar t-Student padronizada
            t_min = (age_gap_min - μ) / σ
            t_max = (age_gap_max - μ) / σ

            # Samplear de t-Student truncada
            dist_t_trunc = Truncated(TDist(df_tstudent), t_min, t_max)
            samples_t = rand(dist_t_trunc, n_samples)
            samples = μ .+ σ .* samples_t
        else
            # Sem truncamento (para comparação)
            dist_t = TDist(df_tstudent)
            samples_t = rand(dist_t, n_samples)
            samples = μ .+ σ .* samples_t
        end

    elseif distribuicao == :empirica
        error("Distribuição empírica ainda não implementada")

    else
        error("Distribuição desconhecida: $distribuicao. Use :normal, :tstudent ou :empirica")
    end

    return samples
end

# ============================================================================
# FUNÇÃO AUXILIAR: IDADE DO CÔNJUGE
# ============================================================================

"""
    samplear_idade_conjuge(idade_servidor::Int, sexo_servidor::String, n_samples::Int=10000;
                           kwargs...)

Amostra IDADE DO CÔNJUGE (não age gap).

Retorna idades do cônjuge: idade_servidor - age_gap

# Exemplo
```julia
idade_conjuge = samplear_idade_conjuge(60, "Masculino", 10_000)
```
"""
function samplear_idade_conjuge(idade_servidor::Int, sexo_servidor::String, n_samples::Int=10000;
                                kwargs...)
    age_gaps = samplear_age_gap(idade_servidor, sexo_servidor, n_samples; kwargs...)
    idades_conjuge = idade_servidor .- age_gaps

    return idades_conjuge
end

# ============================================================================
# FUNÇÃO AUXILIAR: ESTATÍSTICAS DA DISTRIBUIÇÃO
# ============================================================================

"""
    get_parametros_age_gap(idade::Int, sexo::String)

Retorna parâmetros (μ, σ) suavizados para idade e sexo.

# Retorna
- `(μ, σ)`: Tupla com média e desvio-padrão suavizados

# Exemplo
```julia
μ, σ = get_parametros_age_gap(60, "Masculino")
println("Age gap esperado: μ=\$μ anos, σ=\$σ anos")
```
"""
function get_parametros_age_gap(idade::Int, sexo::String)
    key = (idade, sexo)

    if !haskey(PARAMS_DICT, key)
        # Procurar vizinho
        idades_disponiveis = [k[1] for k in keys(PARAMS_DICT) if k[2] == sexo]

        if isempty(idades_disponiveis)
            error("Nenhum dado disponível para sexo=$sexo")
        end

        idade_proxima = idades_disponiveis[argmin(abs.(idades_disponiveis .- idade))]
        @warn "Idade $idade ($sexo) sem dados. Usando idade $idade_proxima."

        key = (idade_proxima, sexo)
    end

    return PARAMS_DICT[key]
end

# ============================================================================
# EXEMPLO DE USO (se executado diretamente)
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    println("\n" * "=" ^ 70)
    println("EXEMPLO DE USO")
    println("=" ^ 70)

    # Cenário: Servidor homem de 60 anos falece
    idade_servidor = 60
    sexo_servidor = "Masculino"

    println("\n📋 Cenário:")
    println("  Servidor: $sexo_servidor, $idade_servidor anos")
    println("  Questão: Qual a idade esperada do cônjuge beneficiário?")

    # Obter parâmetros
    μ, σ = get_parametros_age_gap(idade_servidor, sexo_servidor)
    println("\n📊 Parâmetros suavizados:")
    println("  μ (age gap médio): $(round(μ, digits=2)) anos")
    println("  σ (desvio-padrão): $(round(σ, digits=2)) anos")

    # Monte Carlo: 10k cenários
    println("\n🎲 Simulação Monte Carlo (10.000 cenários):")

    # Comparar t-Student COM e SEM truncamento
    println("\n  === t-Student (df=5) SEM truncamento ===")
    idades_conjuge_sem_trunc = samplear_idade_conjuge(
        idade_servidor, sexo_servidor, 10_000,
        distribuicao=:tstudent, df_tstudent=5, truncar=false
    )

    println("    Idade do cônjuge (anos):")
    println("      Média: $(round(mean(idades_conjuge_sem_trunc), digits=1))")
    println("      Mediana: $(round(median(idades_conjuge_sem_trunc), digits=1))")
    println("      P10: $(round(quantile(idades_conjuge_sem_trunc, 0.10), digits=1))")
    println("      P90: $(round(quantile(idades_conjuge_sem_trunc, 0.90), digits=1))")
    println("      Min/Max: $(round(minimum(idades_conjuge_sem_trunc), digits=1)) / $(round(maximum(idades_conjuge_sem_trunc), digits=1))")

    # Quantos cônjuges com idades ABSURDAS?
    prop_absurdo = mean((idades_conjuge_sem_trunc .< 15) .| (idades_conjuge_sem_trunc .> 100)) * 100
    println("      ⚠️  Probabilidade idade ABSURDA (<15 ou >100): $(round(prop_absurdo, digits=2))%")

    println("\n  === t-Student (df=5) COM truncamento [15, 100] ===")
    idades_conjuge_com_trunc = samplear_idade_conjuge(
        idade_servidor, sexo_servidor, 10_000,
        distribuicao=:tstudent, df_tstudent=5, truncar=true
    )

    println("    Idade do cônjuge (anos):")
    println("      Média: $(round(mean(idades_conjuge_com_trunc), digits=1))")
    println("      Mediana: $(round(median(idades_conjuge_com_trunc), digits=1))")
    println("      P10: $(round(quantile(idades_conjuge_com_trunc, 0.10), digits=1))")
    println("      P90: $(round(quantile(idades_conjuge_com_trunc, 0.90), digits=1))")
    println("      Min/Max: $(round(minimum(idades_conjuge_com_trunc), digits=1)) / $(round(maximum(idades_conjuge_com_trunc), digits=1))")
    println("      ✓ Todas idades entre [15, 100] (REALISTICO)")

    println("\n📌 Impacto do Truncamento:")
    println("  - Remove caudas ABSURDAS (bebês como cônjuges, 120+ anos)")
    println("  - Afeta apenas ~$(round(prop_absurdo, digits=2))% das amostras")
    println("  - Preserva caudas pesadas dentro de limites biológicos")
    println("  - RECOMENDADO para cálculos atuariais realistas")

    println("\n" * "=" ^ 70)
    println("NEXT STEPS: Usar em função heritor")
    println("=" ^ 70)

    println("""
Para cada cenário de idade do cônjuge:
  1. Calcular expectativa de vida (tábua de mortalidade)
  2. Calcular fluxo de pagamentos de pensão
  3. Calcular valor presente
  4. Média dos 10k cenários = reserva técnica esperada

Exemplo:
```julia
using ActuarialFunctions  # Ou pacote similar

idades_conjuge = samplear_idade_conjuge(60, "Masculino", 10_000)

vp_pensoes = zeros(10_000)
for (i, idade_conj) in enumerate(idades_conjuge)
    # Expectativa de vida
    ex = expectativa_vida(idade_conj, "Feminino")  # Assumindo servidor homem → cônjuge mulher

    # Valor presente da pensão (simplificado)
    vp_pensoes[i] = calcular_vp_pensao(idade_conj, ex, pensao_anual=12000.0)
end

reserva_esperada = mean(vp_pensoes)
reserva_p90 = quantile(vp_pensoes, 0.90)  # Conservador

println("Reserva técnica esperada: R\$ \$(reserva_esperada)")
println("Reserva técnica P90 (conservador): R\$ \$(reserva_p90)")
```
""")
end
