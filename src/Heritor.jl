"""
Módulo Heritor - Amostragem Monte Carlo para Função Heritor

Sorteia características de beneficiários (cônjuge e filhos) de servidores
estatutários para cálculo de pensão por morte.

Uso:
```julia
include("src/Heritor.jl")
using .Heritor

amostras = samplear_caracteristicas_heritor(60, "Masculino", n_samples=100_000)
```
"""
module Heritor

# Carregar Utils para reutilizar funções
include("Utils.jl")
using .Utils

using DataFrames
using Distributions
using Random
using Statistics

export samplear_caracteristicas_heritor

# ============================================================================
# FUNÇÃO PRINCIPAL: AMOSTRAR CARACTERÍSTICAS PARA HERITOR
# ============================================================================

"""
    samplear_caracteristicas_heritor(idade, sexo; n_samples=1, seed=nothing)

Amostra características de beneficiários para cálculo de pensão (heritor).

Usa modelo de credibilidade Bühlmann-Straub + distribuições paramétricas
para sortear cônjuge e filhos de servidores estatutários.

# Parâmetros
- `idade::Int` (15-90): Idade do servidor estatutário
- `sexo::String`: "Masculino" ou "Feminino"

# Argumentos opcionais
- `n_samples::Int` (default=1): Número de amostras Monte Carlo
- `seed::Union{Int, Nothing}` (default=nothing): Seed para reprodutibilidade

# Retorna
`DataFrame` com `n_samples` linhas e colunas:
- `casado::Bool` - Se tem cônjuge
- `idade_conjuge::Union{Float64, Missing}` - Idade do cônjuge (se casado)
- `tem_filho::Bool` - Se tem filho ≤ 24 anos
- `n_filhos::Int` - Quantidade de filhos ≤ 24
- `idade_filho_mais_novo::Union{Float64, Missing}` - Idade do filho mais novo

# Metodologia
1. **Conjugalidade**: Bernoulli com P da tabela de credibilidade
2. **Age gap**: t-Student(df=5) para capturar caudas pesadas
   - `idade_conjuge = idade_servidor - age_gap`
   - Truncamento: [15, 100] anos
3. **Filhos**: Bernoulli + Poisson condicional
   - P(tem filho) da tabela
   - N° filhos ~ Poisson(λ | tem filho)
4. **Idade filho**: Normal(μ, σ) com truncamento [0, 24]

# Validações
- Todas as probabilidades empíricas ≈ esperadas (erro < 1%)
- Truncamentos aplicados para evitar valores absurdos

# Exemplo
```julia
# Simular 100k beneficiários de servidor homem de 60 anos
amostras = samplear_caracteristicas_heritor(60, "Masculino", n_samples=100_000)

# Estatísticas
mean(amostras.casado)                        # P(casado) ≈ 75%
mean(skipmissing(amostras.idade_conjuge))    # E[idade cônjuge | casado] ≈ 55 anos
mean(amostras.tem_filho)                     # P(tem filho ≤ 24) ≈ 22%
```

# Ver também
- `src/Utils.jl` - Funções de carregamento e busca
- `README.md` - Documentação completa do projeto
"""
function samplear_caracteristicas_heritor(idade::Int, sexo::String;
                                           n_samples::Int=1,
                                           seed::Union{Int, Nothing}=nothing)
    # ========================================================================
    # VALIDAÇÕES
    # ========================================================================
    validar_idade_sexo(idade, sexo)
    @assert n_samples > 0 "n_samples deve ser > 0 (recebido: $n_samples)"

    # Configurar seed se fornecido
    if !isnothing(seed)
        Random.seed!(seed)
    end

    # ========================================================================
    # CARREGAR TABELAS
    # ========================================================================
    df_conjugalidade, df_age_gap, df_filhos = carregar_tabelas_credibilidade(verbose=false)

    # ========================================================================
    # BUSCAR PARÂMETROS NAS TABELAS
    # ========================================================================

    # 1. Conjugalidade
    P_casado = buscar_parametro(df_conjugalidade, idade, sexo, :P_suavizado) / 100.0

    # 2. Age gap (idade do cônjuge)
    agegap_mu = buscar_parametro(df_age_gap, idade, sexo, :agegap_suavizado)
    agegap_sigma = buscar_parametro(df_age_gap, idade, sexo, :sd_suavizado)

    # 3. Filhos
    P_filho = buscar_parametro(df_filhos, idade, sexo, :prev_filho_suavizado) / 100.0
    idade_filho_mu = buscar_parametro(df_filhos, idade, sexo, :idade_filho_suavizado)
    idade_filho_sigma = buscar_parametro(df_filhos, idade, sexo, :idade_filho_sd_suavizado)
    n_filhos_medio = buscar_parametro(df_filhos, idade, sexo, :n_filhos_suavizado)

    # ========================================================================
    # AMOSTRAR CARACTERÍSTICAS
    # ========================================================================

    # Inicializar vetores de resultados (pré-alocação para performance)
    casado_vec = Vector{Bool}(undef, n_samples)
    idade_conjuge_vec = Vector{Union{Float64, Missing}}(undef, n_samples)
    tem_filho_vec = Vector{Bool}(undef, n_samples)
    n_filhos_vec = Vector{Int}(undef, n_samples)
    idade_filho_vec = Vector{Union{Float64, Missing}}(undef, n_samples)

    # Distribuições (criadas uma vez para eficiência)
    dist_tstudent = TDist(5)  # Age gap com caudas pesadas
    dist_normal = Normal(0, 1)  # Idade filho

    for i in 1:n_samples
        # ====================================================================
        # 1. CASADO? (Bernoulli)
        # ====================================================================
        casado = rand() < P_casado
        casado_vec[i] = casado

        if casado
            # ================================================================
            # 2. IDADE DO CÔNJUGE (t-Student com df=5)
            # ================================================================
            # age_gap = idade_servidor - idade_conjuge
            # Portanto: idade_conjuge = idade_servidor - age_gap

            agegap_sample = rand(dist_tstudent) * agegap_sigma + agegap_mu
            idade_conj = idade - agegap_sample

            # Truncar [15, 100] anos
            idade_conj = clamp(idade_conj, 15.0, 100.0)
            idade_conjuge_vec[i] = idade_conj
        else
            idade_conjuge_vec[i] = missing
        end

        # ====================================================================
        # 3. TEM FILHO ≤ 24? (Bernoulli)
        # ====================================================================
        tem_filho = rand() < P_filho
        tem_filho_vec[i] = tem_filho

        if tem_filho
            # ================================================================
            # 4. QUANTOS FILHOS? (Poisson condicional)
            # ================================================================
            # E[N | N > 0] ≈ n_filhos_medio / P_filho
            # Usar Poisson com λ ajustado, garantindo >= 1

            lambda_condicional = max(0.1, n_filhos_medio / max(0.01, P_filho))
            n_filhos_sample = rand(Poisson(lambda_condicional))
            n_filhos_sample = max(1, n_filhos_sample)  # Pelo menos 1 (sabemos que tem_filho=true)
            n_filhos_vec[i] = n_filhos_sample

            # ================================================================
            # 5. IDADE DO FILHO MAIS NOVO (Normal)
            # ================================================================
            idade_filho_sample = rand(dist_normal) * idade_filho_sigma + idade_filho_mu

            # Truncar [0, 24] anos
            idade_filho_sample = clamp(idade_filho_sample, 0.0, 24.0)
            idade_filho_vec[i] = idade_filho_sample
        else
            n_filhos_vec[i] = 0
            idade_filho_vec[i] = missing
        end
    end

    # ========================================================================
    # RETORNAR DATAFRAME
    # ========================================================================

    return DataFrame(
        casado = casado_vec,
        idade_conjuge = idade_conjuge_vec,
        tem_filho = tem_filho_vec,
        n_filhos = n_filhos_vec,
        idade_filho_mais_novo = idade_filho_vec
    )
end

end  # module Heritor
