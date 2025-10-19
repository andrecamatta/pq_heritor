"""
Módulo de Credibilidade Bühlmann-Straub

Funções compartilhadas para aplicação do modelo de credibilidade
atuarial nos dados de conjugalidade e age gap.

Uso:
```julia
include("src/Credibilidade.jl")
using .Credibilidade
```
"""
module Credibilidade

using Statistics

export suavizar_com_prior
export calcular_shift
export calcular_parametro_k
export calcular_credibilidade

# ============================================================================
# FUNÇÃO PRINCIPAL: SUAVIZAÇÃO COM PRIOR
# ============================================================================

"""
    suavizar_com_prior(valores, prior; janela=5, peso_prior=0.3, n_iteracoes=3)

Suaviza curva usando média móvel ponderada + ancoragem no prior.

# Argumentos
- `valores`: Curva a suavizar (P_credível ou age gap credível)
- `prior`: Referência para ancoragem (P_geral_ajustado)
- `janela`: Tamanho da janela de suavização (padrão: 5)
- `peso_prior`: Força da ancoragem no prior, 0-1 (padrão: 0.3)
- `n_iteracoes`: Número de passadas de suavização (padrão: 3)

# Retorna
- `Vector{Float64}`: Curva suavizada

# Detalhes
Este é um método de suavização atuarial clássico (Fórmula de Spencer, 1904).
Combina:
1. Média móvel local (pesos triangulares)
2. Ancoragem em referência externa (population drift)

# Aplicação
Usado após credibilidade Bühlmann-Straub para:
- Remover oscilações residuais
- Preservar tendência da população geral
- Gerar curvas plausíveis para uso em projeções
"""
function suavizar_com_prior(valores::AbstractVector{T},
                            prior::AbstractVector{S};
                            janela::Int=5,
                            peso_prior::Float64=0.3,
                            n_iteracoes::Int=3) where {T <: Union{Float64, Missing}, S <: Union{Float64, Missing}}
    # Validar inputs
    if length(valores) != length(prior)
        error("valores e prior devem ter mesmo tamanho")
    end

    if !(0.0 <= peso_prior <= 1.0)
        error("peso_prior deve estar em [0, 1]")
    end

    n = length(valores)

    # Converter para Float64, tratando missings
    suavizado = Float64[]
    for i in 1:n
        if ismissing(valores[i])
            # Se missing, usar prior
            push!(suavizado, ismissing(prior[i]) ? 0.0 : Float64(prior[i]))
        else
            push!(suavizado, Float64(valores[i]))
        end
    end

    # Aplicar suavização iterativa
    for iter in 1:n_iteracoes
        novo = copy(suavizado)

        for i in 1:n
            # Janela de vizinhos
            i_min = max(1, i - janela÷2)
            i_max = min(n, i + janela÷2)

            # Pesos triangulares (maior peso no centro)
            pesos = Float64[]
            indices = Int[]
            for j in i_min:i_max
                dist = abs(j - i)
                peso = max(0.0, 1.0 - dist / (janela/2))
                push!(pesos, peso)
                push!(indices, j)
            end

            # Normalizar pesos
            pesos ./= sum(pesos)

            # Média ponderada dos vizinhos
            valor_local = sum(suavizado[indices] .* pesos)

            # Combinar: local + prior
            prior_value = ismissing(prior[i]) ? valor_local : Float64(prior[i])
            novo[i] = (1 - peso_prior) * valor_local + peso_prior * prior_value
        end

        suavizado = novo
    end

    return suavizado
end

# ============================================================================
# FUNÇÕES AUXILIARES: CREDIBILIDADE
# ============================================================================

"""
    calcular_shift(valores_grupo, valores_referencia, filtro_confiavel)

Calcula shift sistemático Δ entre grupo e referência.

# Argumentos
- `valores_grupo`: Valores observados do grupo (ex: P_serv)
- `valores_referencia`: Valores da referência (ex: P_geral)
- `filtro_confiavel`: Máscara booleana para observações confiáveis (ex: n >= 30)

# Retorna
- `Float64`: Δ = mean(grupo - referência) onde filtro_confiavel é true

# Uso
```julia
idx_confiavel = n_serv .>= 30
Δ = calcular_shift(P_serv, P_geral, idx_confiavel)
```
"""
function calcular_shift(valores_grupo::AbstractVector{T},
                       valores_referencia::AbstractVector{S},
                       filtro_confiavel::AbstractVector{Bool}) where {T <: Union{Float64, Missing}, S <: Union{Float64, Missing}}
    # Filtrar observações confiáveis
    grupo_filtrado = Float64[]
    ref_filtrada = Float64[]

    for i in 1:length(filtro_confiavel)
        if filtro_confiavel[i] && !ismissing(valores_grupo[i]) && !ismissing(valores_referencia[i])
            push!(grupo_filtrado, Float64(valores_grupo[i]))
            push!(ref_filtrada, Float64(valores_referencia[i]))
        end
    end

    if isempty(grupo_filtrado)
        @warn "Nenhuma observação confiável para calcular shift. Retornando 0.0"
        return 0.0
    end

    diferencas = grupo_filtrado .- ref_filtrada
    return mean(diferencas)
end

"""
    calcular_parametro_k(tamanhos_amostra)

Calcula parâmetro k para credibilidade Bühlmann-Straub.

# Argumentos
- `tamanhos_amostra`: Vetor com tamanhos amostrais (ex: n_serv)

# Retorna
- `Float64`: k = √(mean(tamanhos_amostra positivos))

# Fundamentação
k representa a "resistência" à mudança entre prior e observado.
Quanto maior k, mais peso precisa ter n para confiar nos dados observados.

# Uso
```julia
k = calcular_parametro_k(n_serv)
Z = n ./ (n .+ k)  # Peso para observado
```
"""
function calcular_parametro_k(tamanhos_amostra::AbstractVector{<:Real})
    # Filtrar amostras positivas
    ns_positivos = filter(x -> x > 0, tamanhos_amostra)

    if isempty(ns_positivos)
        @warn "Nenhuma amostra positiva. Retornando k padrão: 50.0"
        return 50.0
    end

    n_medio = mean(ns_positivos)
    k = sqrt(n_medio)

    return k
end

"""
    calcular_credibilidade(n, k)

Calcula peso de credibilidade Z = n / (n + k).

# Argumentos
- `n`: Tamanho amostral
- `k`: Parâmetro de credibilidade (calculado por `calcular_parametro_k`)

# Retorna
- `Float64`: Z ∈ [0, 1] - peso para observação

# Interpretação
- Z ≈ 0: n pequeno → usar mais prior (referência)
- Z ≈ 1: n grande → usar mais observado
- Z = 0.5: n = k (equilíbrio)

# Uso
```julia
k = calcular_parametro_k(n_serv)
Z = calcular_credibilidade(n, k)
P_credivel = Z * P_obs + (1 - Z) * P_prior
```
"""
function calcular_credibilidade(n::Real, k::Real)
    if n < 0
        error("n deve ser não-negativo, recebido: $n")
    end

    if k <= 0
        error("k deve ser positivo, recebido: $k")
    end

    Z = n / (n + k)
    return Z
end

end  # module Credibilidade
