"""
Módulo de Age Gap (Diferença de Idade entre Cônjuges)

Funções compartilhadas para análise de age gap em conjugalidade.

Uso:
```julia
include("src/AgeGap.jl")
using .AgeGap
```
"""
module AgeGap

using DataFrames

export extrair_pares_age_gap

# ============================================================================
# FUNÇÃO PRINCIPAL: EXTRAIR PARES DE CÔNJUGES
# ============================================================================

"""
    extrair_pares_age_gap(df::DataFrame)

Extrai pares de cônjuges com age gap dos microdados PNADC/PNAD.

# Estrutura esperada do DataFrame `df`
- `domicilio_id`: Identificador do domicílio
- `condicao_dom`: Condição no domicílio
  - 1: Pessoa de referência (chefe)
  - 2: Cônjuge de sexo diferente
  - 3: Cônjuge de mesmo sexo
- `idade`: Idade em anos completos
- `sexo`: Código de sexo (1=Masculino, 2=Feminino para PNADC 2023)
- `servidor`: Bool - é servidor público?
- `peso`: Peso amostral

# Retorna
`DataFrame` com colunas:
- `idade_ref`: Idade da pessoa de referência
- `sexo_ref`: Sexo da pessoa de referência
- `idade_conj`: Idade do cônjuge
- `age_gap`: Diferença de idade (idade_ref - idade_conj)
  - Positivo: referência mais velha que cônjuge
  - Negativo: cônjuge mais velho que referência
  - Zero: mesma idade
- `servidor_ref`: Pessoa de referência é servidor?
- `peso`: Peso amostral da pessoa de referência

# Detalhes de implementação
- Otimizado com `groupby` (evita loops nested lentos)
- Pre-aloca arrays para performance
- Filtra idades válidas: 15-90 anos para referência
- Remove pares com idade missing

# Aplicação
Usado para:
1. Análise exploratória de age gap (09a)
2. Cálculo de μ(idade, sexo) e σ(idade, sexo) com credibilidade (09)
3. Função heritor: estimar idade do beneficiário de pensão

# Exemplo
```julia
include("src/AgeGap.jl")
using .AgeGap

df = CSV.read("dados/pnadc_2023_processado.csv", DataFrame)
pares = extrair_pares_age_gap(df)

println("Pares encontrados: ", nrow(pares))
println("Age gap médio (geral): ", mean(pares.age_gap))
```
"""
function extrair_pares_age_gap(df::DataFrame)
    # Validar colunas necessárias
    required_cols = ["domicilio_id", "condicao_dom", "idade", "sexo", "servidor", "peso"]
    missing_cols = [col for col in required_cols if !(col in names(df))]

    if !isempty(missing_cols)
        error("Colunas ausentes no DataFrame: $missing_cols")
    end

    # Pre-alocar arrays (estimativa: 40% dos registros são pares)
    n_estimado = nrow(df) ÷ 3
    idade_ref_vec = Vector{Int}(undef, n_estimado)
    sexo_ref_vec = Vector{Int}(undef, n_estimado)
    idade_conj_vec = Vector{Int}(undef, n_estimado)
    age_gap_vec = Vector{Int}(undef, n_estimado)
    servidor_ref_vec = Vector{Bool}(undef, n_estimado)
    peso_vec = Vector{Float64}(undef, n_estimado)

    contador = 0

    # Agrupar por domicílio (MUITO mais rápido que unique + filter!)
    gdf = groupby(df, :domicilio_id)

    for pessoas in gdf
        # Identificar pessoa de referência (condicao_dom = 1)
        idx_ref = findfirst(==(1), pessoas.condicao_dom)
        if isnothing(idx_ref)
            continue
        end

        # Identificar cônjuge (condicao_dom = 2 ou 3)
        idx_conj = findfirst(x -> x in [2, 3], pessoas.condicao_dom)
        if isnothing(idx_conj)
            continue
        end

        # Validar idades
        idade_r = pessoas[idx_ref, :idade]
        idade_c = pessoas[idx_conj, :idade]

        if ismissing(idade_r) || ismissing(idade_c)
            continue
        end

        if idade_r < 15 || idade_r > 90
            continue
        end

        # Adicionar par
        contador += 1
        if contador > n_estimado
            # Expandir arrays se necessário (raro)
            resize!(idade_ref_vec, contador)
            resize!(sexo_ref_vec, contador)
            resize!(idade_conj_vec, contador)
            resize!(age_gap_vec, contador)
            resize!(servidor_ref_vec, contador)
            resize!(peso_vec, contador)
        end

        idade_ref_vec[contador] = idade_r
        sexo_ref_vec[contador] = pessoas[idx_ref, :sexo]
        idade_conj_vec[contador] = idade_c
        age_gap_vec[contador] = idade_r - idade_c
        servidor_ref_vec[contador] = pessoas[idx_ref, :servidor]
        peso_vec[contador] = pessoas[idx_ref, :peso]
    end

    # Truncar para tamanho real
    resize!(idade_ref_vec, contador)
    resize!(sexo_ref_vec, contador)
    resize!(idade_conj_vec, contador)
    resize!(age_gap_vec, contador)
    resize!(servidor_ref_vec, contador)
    resize!(peso_vec, contador)

    # Criar DataFrame
    return DataFrame(
        idade_ref = idade_ref_vec,
        sexo_ref = sexo_ref_vec,
        idade_conj = idade_conj_vec,
        age_gap = age_gap_vec,
        servidor_ref = servidor_ref_vec,
        peso = peso_vec
    )
end

end  # module AgeGap
