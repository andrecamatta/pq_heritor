"""
Módulo Atuarial - Cálculos de Encargo para Função Heritor

Funções para calcular o encargo atuarial (em anos de benefício) do valor
presente das pensões por morte, usando tábuas de mortalidade AT-2012 IAM Basic.

Uso:
```julia
include("src/Atuarial.jl")
using .Atuarial

encargo = calcular_encargo_heritor(60, "Masculino", n_samples=100_000)
```
"""
module Atuarial

using MortalityTables
using DataFrames
using Statistics
using CSV

# Carregar módulo Heritor para amostragem
include("Heritor.jl")
using .Heritor

export carregar_tabua_iam2012
export calcular_anuidade_vitalicia
export calcular_anuidade_temporaria
export calcular_percentual_pensao
export calcular_encargo_heritor
export calcular_reserva_pensao
export calcular_expectativa_vida

# ============================================================================
# CONSTANTES
# ============================================================================

# IDs das tábuas 2012 IAM Basic no mort.SOA.org
const TABUA_IAM2012_MALE = 2585
const TABUA_IAM2012_FEMALE = 2582

# Taxa de juros padrão (6% a.a.)
const TAXA_JUROS_PADRAO = 0.06

# Cache de tábuas (evita recarregar)
const TABELAS_CACHE = Dict{String, Any}()

# ============================================================================
# CARREGAR TÁBUAS DE MORTALIDADE
# ============================================================================

"""
    carregar_tabua_iam2012(sexo::String)

Carrega tábua de mortalidade AT-2012 IAM Basic por sexo.

# Argumentos
- `sexo::String`: "Masculino" ou "Feminino"

# Retorna
- Objeto de tábua do MortalityTables.jl

# Exemplo
```julia
tabua_male = carregar_tabua_iam2012("Masculino")
```
"""
function carregar_tabua_iam2012(sexo::String)
    # Verificar cache
    if haskey(TABELAS_CACHE, sexo)
        return TABELAS_CACHE[sexo]
    end

    # Determinar ID da tábua
    tabua_id = if sexo == "Masculino"
        TABUA_IAM2012_MALE
    elseif sexo == "Feminino"
        TABUA_IAM2012_FEMALE
    else
        error("Sexo deve ser 'Masculino' ou 'Feminino', recebido: '$sexo'")
    end

    # Carregar tábua da SOA
    tabua = MortalityTables.table(tabua_id)

    # Cachear para reuso
    TABELAS_CACHE[sexo] = tabua

    return tabua
end

# ============================================================================
# CÁLCULO DE ANUIDADES
# ============================================================================

"""
    calcular_anuidade_vitalicia(idade::Int, sexo::String; taxa_juros::Float64=TAXA_JUROS_PADRAO)

Calcula anuidade vitalícia (valor presente de R\$ 1/ano até morte).

Usa fórmula atuarial padrão:
ä_x = Σ v^t × t_p_x  (t=0 até ω-x)

# Argumentos
- `idade::Int`: Idade atual do beneficiário
- `sexo::String`: "Masculino" ou "Feminino"
- `taxa_juros::Float64`: Taxa de desconto anual (default: 6%)

# Retorna
- `Float64`: Valor presente da anuidade vitalícia (em anos de benefício)

# Exemplo
```julia
# Mulher de 55 anos
a_vitalicia = calcular_anuidade_vitalicia(55, "Feminino", taxa_juros=0.06)
# Resultado: ~14.2 anos (exemplo)
```
"""
function calcular_anuidade_vitalicia(idade::Int, sexo::String;
                                       taxa_juros::Float64=TAXA_JUROS_PADRAO)
    # Validar idade
    @assert idade >= 0 && idade <= 120 "Idade deve estar entre 0 e 120 anos"

    # Carregar tábua
    tabua = carregar_tabua_iam2012(sexo)

    # Obter idade máxima (ω)
    omega = MortalityTables.omega(tabua)

    # Fator de desconto
    v = 1.0 / (1.0 + taxa_juros)

    # Calcular anuidade due (pagamento no início)
    # ä_x = Σ v^t × t_p_x para t=0 até (ω-x)
    anuidade = 0.0
    t_p_x = 1.0  # 0_p_x = 1 (probabilidade de sobreviver 0 anos = 1)

    for t in 0:(omega - idade)
        # Adicionar termo: v^t × t_p_x
        anuidade += (v^t) * t_p_x

        # Atualizar probabilidade de sobrevivência para próximo ano
        # t+1_p_x = t_p_x × (1 - q_{x+t})
        if (idade + t) < omega
            q_xt = tabua[idade + t]  # Probabilidade de morte em idade x+t
            t_p_x *= (1.0 - q_xt)  # Probabilidade de sobreviver mais um ano
        else
            break  # Chegou na idade máxima
        end
    end

    return Float64(anuidade)
end

"""
    calcular_anuidade_temporaria(idade::Int, sexo::String, anos::Int;
                                   taxa_juros::Float64=TAXA_JUROS_PADRAO)

Calcula anuidade temporária (valor presente de R\$ 1/ano por N anos ou até morte).

Usa fórmula atuarial padrão:
ä_x:n = Σ v^t × t_p_x  (t=0 até min(n-1, ω-x))

# Argumentos
- `idade::Int`: Idade atual do beneficiário
- `sexo::String`: "Masculino" ou "Feminino"
- `anos::Int`: Número de anos da anuidade
- `taxa_juros::Float64`: Taxa de desconto anual (default: 6%)

# Retorna
- `Float64`: Valor presente da anuidade temporária (em anos de benefício)

# Exemplo
```julia
# Criança de 18 anos receberá até 24 anos (6 anos)
a_temp = calcular_anuidade_temporaria(18, "Feminino", 6, taxa_juros=0.06)
# Resultado: ~5.2 anos (exemplo)
```
"""
function calcular_anuidade_temporaria(idade::Int, sexo::String, anos::Int;
                                        taxa_juros::Float64=TAXA_JUROS_PADRAO)
    # Validações
    @assert idade >= 0 && idade <= 120 "Idade deve estar entre 0 e 120 anos"
    @assert anos >= 0 "Número de anos deve ser >= 0"

    # Se anos = 0, retornar 0 (sem benefício)
    if anos == 0
        return 0.0
    end

    # Carregar tábua
    tabua = carregar_tabua_iam2012(sexo)

    # Obter idade máxima (ω)
    omega = MortalityTables.omega(tabua)

    # Fator de desconto
    v = 1.0 / (1.0 + taxa_juros)

    # Calcular anuidade temporária
    # ä_x:n = Σ v^t × t_p_x para t=0 até min(n-1, ω-x)
    anuidade = 0.0
    t_p_x = 1.0  # 0_p_x = 1

    # Duração efetiva: menor entre anos solicitados e anos até ω
    duracao = min(anos, omega - idade + 1)

    for t in 0:(duracao - 1)
        # Adicionar termo: v^t × t_p_x
        anuidade += (v^t) * t_p_x

        # Atualizar probabilidade de sobrevivência
        if (idade + t) < omega && t < (duracao - 1)
            q_xt = tabua[idade + t]
            t_p_x *= (1.0 - q_xt)
        else
            break
        end
    end

    return Float64(anuidade)
end

# ============================================================================
# CÁLCULO DE PERCENTUAL DE PENSÃO
# ============================================================================

"""
    calcular_percentual_pensao(n_dependentes::Int)

Calcula percentual de pensão segundo regra: 50% + 10% por dependente (max 100%).

# Argumentos
- `n_dependentes::Int`: Número total de dependentes (cônjuge + filhos)

# Retorna
- `Float64`: Percentual de pensão (entre 0.0 e 1.0)

# Regra
- Base: 50%
- Adicional: +10% por cada dependente (cônjuge conta como 1)
- Limite: 100%

# Exemplos
```julia
calcular_percentual_pensao(0)  # 0.0 (sem dependentes)
calcular_percentual_pensao(1)  # 0.6 (50% + 10%)
calcular_percentual_pensao(3)  # 0.8 (50% + 30%)
calcular_percentual_pensao(10) # 1.0 (limitado a 100%)
```
"""
function calcular_percentual_pensao(n_dependentes::Int)
    @assert n_dependentes >= 0 "Número de dependentes deve ser >= 0"

    if n_dependentes == 0
        return 0.0
    end

    # 50% base + 10% por dependente
    pct = 0.50 + 0.10 * n_dependentes

    # Limitar a 100%
    return min(pct, 1.0)
end

# ============================================================================
# FUNÇÃO PRINCIPAL: ENCARGO HERITOR
# ============================================================================

"""
    calcular_encargo_heritor(idade_servidor::Int, sexo_servidor::String;
                              n_samples::Int=10_000,
                              taxa_juros::Float64=TAXA_JUROS_PADRAO,
                              seed::Union{Int,Nothing}=nothing)

Calcula encargo atuarial (em anos de benefício) do valor presente das pensões.

Usa amostragem Monte Carlo para simular beneficiários e calcula o valor
presente esperado das pensões futuras, expresso em "anos de benefício".

# Argumentos
- `idade_servidor::Int`: Idade do servidor no momento da morte (15-90)
- `sexo_servidor::String`: "Masculino" ou "Feminino"

# Argumentos opcionais
- `n_samples::Int`: Número de amostras Monte Carlo (default: 10,000)
- `taxa_juros::Float64`: Taxa de desconto anual (default: 6%)
- `seed::Union{Int,Nothing}`: Seed para reprodutibilidade

# Retorna
`DataFrame` com estatísticas:
- `encargo_medio`: Encargo médio em anos de benefício
- `encargo_mediano`: Mediana do encargo
- `encargo_p10`, `encargo_p90`: Percentis 10% e 90%
- `percentual_pensao_medio`: % médio de pensão
- `n_amostras`: Número de amostras simuladas

# Metodologia
1. Amostra características dos beneficiários (via `Heritor.samplear_caracteristicas_heritor`)
2. Para cada amostra:
   - Calcula n_dependentes = (casado ? 1 : 0) + n_filhos
   - Calcula % pensão = min(50% + 10% × n_dep, 100%)
   - Se casado: encargo_cônjuge = % × anuidade_vitalicia(idade_cônjuge)
   - Para cada filho: encargo_filho = % × anuidade_temporaria(idade_filho, até 24 anos)
   - encargo_total = encargo_cônjuge + Σ encargo_filhos
3. Agrega estatísticas das amostras

# Exemplo
```julia
# Servidor homem de 60 anos
resultado = calcular_encargo_heritor(60, "Masculino", n_samples=100_000, taxa_juros=0.06)

# Interpretação:
# encargo_medio = 8.5 → "O custo das pensões equivale a 8.5 anos de benefício
#                        ao valor presente com taxa de 6% a.a."
```

# Ver também
- `Heritor.samplear_caracteristicas_heritor`: Amostragem de beneficiários
- `calcular_anuidade_vitalicia`: Anuidade para cônjuge
- `calcular_anuidade_temporaria`: Anuidade para filhos
"""
function calcular_encargo_heritor(idade_servidor::Int, sexo_servidor::String;
                                    n_samples::Int=10_000,
                                    taxa_juros::Float64=TAXA_JUROS_PADRAO,
                                    seed::Union{Int,Nothing}=nothing)
    # ========================================================================
    # VALIDAÇÕES
    # ========================================================================
    @assert idade_servidor >= 15 && idade_servidor <= 90 "Idade deve estar entre 15 e 90 anos"
    @assert sexo_servidor in ["Masculino", "Feminino"] "Sexo deve ser 'Masculino' ou 'Feminino'"
    @assert n_samples > 0 "n_samples deve ser > 0"
    @assert taxa_juros > 0 && taxa_juros < 1 "taxa_juros deve estar entre 0 e 1"

    # ========================================================================
    # AMOSTRAR BENEFICIÁRIOS
    # ========================================================================
    println("\n📊 Amostrando características dos beneficiários...")
    amostras = Heritor.samplear_caracteristicas_heritor(
        idade_servidor, sexo_servidor,
        n_samples=n_samples,
        seed=seed
    )

    # ========================================================================
    # CALCULAR ENCARGO PARA CADA AMOSTRA
    # ========================================================================
    println("💰 Calculando encar Atuarial para $(n_samples) amostras...")

    encargos = Vector{Float64}(undef, n_samples)
    percentuais_pensao = Vector{Float64}(undef, n_samples)

    for i in 1:n_samples
        amostra = amostras[i, :]

        # ====================================================================
        # 1. CALCULAR NÚMERO DE DEPENDENTES
        # ====================================================================
        n_dependentes = 0
        if amostra.casado
            n_dependentes += 1  # Cônjuge conta como 1 dependente
        end
        n_dependentes += amostra.n_filhos

        # ====================================================================
        # 2. CALCULAR PERCENTUAL DE PENSÃO
        # ====================================================================
        pct_pensao = calcular_percentual_pensao(n_dependentes)
        percentuais_pensao[i] = pct_pensao

        # ====================================================================
        # 3. CALCULAR ENCARGO
        # ====================================================================
        encargo_total = 0.0

        # 3.1. Encargo do cônjuge (anuidade vitalícia)
        if amostra.casado && !ismissing(amostra.idade_conjuge)
            idade_conj = round(Int, amostra.idade_conjuge)
            # Sexo do cônjuge é oposto ao do servidor
            sexo_conj = sexo_servidor == "Masculino" ? "Feminino" : "Masculino"

            anuidade_conj = calcular_anuidade_vitalicia(
                idade_conj, sexo_conj, taxa_juros=taxa_juros
            )

            encargo_total += pct_pensao * anuidade_conj
        end

        # 3.2. Encargo dos filhos (anuidade temporária até 24 anos)
        if amostra.tem_filho && !ismissing(amostra.idade_filho_mais_novo)
            idade_filho = round(Int, amostra.idade_filho_mais_novo)

            # Calcular anos até 24
            anos_ate_24 = max(0, 24 - idade_filho)

            if anos_ate_24 > 0
                # Assumir distribuição 50% masculino, 50% feminino
                # (Simplificação: usar média das duas tábuas)
                anuidade_filho_m = calcular_anuidade_temporaria(
                    idade_filho, "Masculino", anos_ate_24, taxa_juros=taxa_juros
                )
                anuidade_filho_f = calcular_anuidade_temporaria(
                    idade_filho, "Feminino", anos_ate_24, taxa_juros=taxa_juros
                )

                anuidade_filho_media = (anuidade_filho_m + anuidade_filho_f) / 2.0

                # Multiplicar pelo número de filhos
                encargo_total += pct_pensao * anuidade_filho_media * amostra.n_filhos
            end
        end

        encargos[i] = encargo_total
    end

    # ========================================================================
    # CALCULAR ESTATÍSTICAS
    # ========================================================================
    println("📈 Agregando estatísticas...")

    resultado = DataFrame(
        encargo_medio = mean(encargos),
        encargo_mediano = median(encargos),
        encargo_p10 = quantile(encargos, 0.10),
        encargo_p90 = quantile(encargos, 0.90),
        encargo_min = minimum(encargos),
        encargo_max = maximum(encargos),
        percentual_pensao_medio = mean(percentuais_pensao),
        n_amostras = n_samples
    )

    return resultado
end

# ============================================================================
# FUNÇÕES DE RESERVA MATEMÁTICA (SERVIDOR VIVO)
# ============================================================================

"""
    calcular_expectativa_vida(idade::Int, sexo::String)

Calcula expectativa de vida completa e_x para idade x.

# Argumentos
- `idade::Int`: Idade atual
- `sexo::String`: "Masculino" ou "Feminino"

# Retorna
- `Float64`: Expectativa de vida em anos

# Fórmula
e_x = Σ t_p_x (soma das probabilidades de sobrevivência)
"""
function calcular_expectativa_vida(idade::Int, sexo::String)
    # Carregar tábua
    tabua = carregar_tabua_iam2012(sexo)
    omega = MortalityTables.omega(tabua)

    # Calcular e_x = Σ t_p_x
    ex = 0.0
    t_p_x = 1.0

    for t in 1:(omega - idade)
        if (idade + t - 1) < omega
            q_t = tabua[idade + t - 1]
            t_p_x *= (1.0 - q_t)
            ex += t_p_x
        else
            break
        end
    end

    return ex
end

"""
    calcular_prob_deixar_pensao(idade::Int, sexo::String, tabua)

Calcula probabilidade de deixar ≥1 dependente ao morrer (média ponderada futura).

Aproximação: usa conjugalidade média nas idades futuras ponderada por
probabilidade de morrer em cada idade.

# Argumentos
- `idade::Int`: Idade atual do servidor
- `sexo::String`: "Masculino" ou "Feminino"
- `tabua`: Tábua de mortalidade

# Retorna
- `Float64`: Probabilidade (0 a 1)
"""
function calcular_prob_deixar_pensao(idade::Int, sexo::String, tabua)
    # Carregar dados de conjugalidade
    arquivo_conj = joinpath(dirname(@__FILE__), "..", "resultados", "conjugalidade_credivel.csv")

    if !isfile(arquivo_conj)
        @warn "Arquivo de conjugalidade não encontrado. Retornando estimativa padrão."
        return 0.6  # Estimativa padrão
    end

    df_conj = CSV.read(arquivo_conj, DataFrame)
    omega = MortalityTables.omega(tabua)

    # Calcular média ponderada por probabilidade de morte
    prob_total = 0.0
    peso_total = 0.0
    t_p_x = 1.0

    for t in 0:(omega - idade)
        idade_t = idade + t

        # Buscar P(casado) nessa idade
        if idade_t >= 15 && idade_t <= 90
            conj_row = filter(row -> row.idade == idade_t &&
                                      row.sexo == sexo, df_conj)

            if nrow(conj_row) > 0
                p_casado = conj_row[1, :P_suavizado] / 100.0
            else
                p_casado = 0.6  # Default
            end
        else
            p_casado = 0.0
        end

        # Peso = probabilidade de morrer nessa idade
        if idade_t < omega
            q_t = tabua[idade_t]
        else
            q_t = 1.0
        end

        peso = t_p_x * q_t
        prob_total += peso * p_casado
        peso_total += peso

        # Atualizar sobrevivência
        t_p_x *= (1.0 - q_t)
    end

    return prob_total / peso_total
end

"""
    calcular_reserva_pensao(idade_atual::Int, sexo::String;
                             taxa_juros::Float64=TAXA_JUROS_PADRAO)

Calcula reserva matemática de pensão para servidor VIVO.

Integra probabilidade de morte do servidor (tábua AT-2012 IAM Basic)
com função heritor (encargo condicional à morte em cada idade).

# Fórmula
Reserva(x) = Σ_{t=0}^{ω-x} v^t × t_p_x × q_{x+t} × Heritor(x+t)

Onde:
- v^t = fator de desconto
- t_p_x = probabilidade de sobreviver de x até x+t
- q_{x+t} = probabilidade de morrer em idade x+t
- Heritor(x+t) = encargo se morrer em idade x+t

# Argumentos
- `idade_atual::Int`: Idade atual do servidor VIVO (15-90 anos)
- `sexo::String`: "Masculino" ou "Feminino"
- `taxa_juros::Float64`: Taxa de desconto anual (default: 6%)

# Retorna
DataFrame com:
- `idade_atual`: Idade atual do servidor
- `sexo`: Sexo do servidor
- `reserva_total`: Reserva total em anos de benefício
- `reserva_por_ano_vida`: Reserva normalizada por expectativa de vida
- `expectativa_vida`: Expectativa de vida residual
- `prob_deixar_pensao`: Probabilidade de deixar ≥1 dependente

# Exemplo
```julia
# Servidor homem vivo, 55 anos
reserva = calcular_reserva_pensao(55, "Masculino")
# reserva_total ≈ 2.5 anos (valor presente do direito de pensão)
```

# Ver também
- `calcular_encargo_heritor`: Encargo condicional à morte em idade x
- `calcular_expectativa_vida`: Expectativa de vida e_x
"""
function calcular_reserva_pensao(idade_atual::Int, sexo::String;
                                  taxa_juros::Float64=TAXA_JUROS_PADRAO)
    # ========================================================================
    # VALIDAÇÕES
    # ========================================================================
    @assert idade_atual >= 15 && idade_atual <= 90 "Idade deve estar entre 15 e 90 anos"
    @assert sexo in ["Masculino", "Feminino"] "Sexo deve ser 'Masculino' ou 'Feminino'"
    @assert taxa_juros > 0 && taxa_juros < 1 "taxa_juros deve estar entre 0 e 1"

    # ========================================================================
    # CARREGAR DADOS
    # ========================================================================

    # Tábua de mortalidade do servidor
    tabua = carregar_tabua_iam2012(sexo)
    omega = MortalityTables.omega(tabua)
    v = 1.0 / (1.0 + taxa_juros)

    # Carregar encargos heritor pré-calculados
    arquivo_heritor = joinpath(dirname(@__FILE__), "..", "resultados", "encargo_heritor.csv")

    if !isfile(arquivo_heritor)
        error("Arquivo encargo_heritor.csv não encontrado. Execute primeiro: julia 17_calcular_encargo_tabela.jl")
    end

    df_heritor = CSV.read(arquivo_heritor, DataFrame)

    # ========================================================================
    # CALCULAR RESERVA
    # ========================================================================

    reserva = 0.0
    t_p_x = 1.0  # Probabilidade de estar vivo hoje = 1

    for t in 0:(omega - idade_atual)
        idade_morte = idade_atual + t

        # Probabilidade de morrer em idade_morte
        if idade_morte < omega
            q_morte = tabua[idade_morte]
        else
            q_morte = 1.0  # Morte certa em omega
        end

        # Buscar encargo heritor para essa idade de morte
        encargo_row = filter(row -> row.idade == idade_morte &&
                                     row.sexo == sexo, df_heritor)

        if nrow(encargo_row) > 0
            encargo = encargo_row[1, :encargo_medio]
        else
            # Se não tiver (idades fora de 30-80), assumir zero
            encargo = 0.0
        end

        # Adicionar contribuição: v^t × P(sobreviver t anos) × P(morrer) × Encargo
        reserva += (v^t) * t_p_x * q_morte * encargo

        # Atualizar P(sobreviver até t+1)
        t_p_x *= (1.0 - q_morte)
    end

    # ========================================================================
    # CALCULAR MÉTRICAS ADICIONAIS
    # ========================================================================

    expectativa_vida = calcular_expectativa_vida(idade_atual, sexo)
    prob_pensao = calcular_prob_deixar_pensao(idade_atual, sexo, tabua)

    # Reserva por ano de vida (normalizada)
    reserva_por_ano = expectativa_vida > 0 ? reserva / expectativa_vida : 0.0

    # ========================================================================
    # RETORNAR RESULTADO
    # ========================================================================

    return DataFrame(
        idade_atual = [idade_atual],
        sexo = [sexo],
        reserva_total = [reserva],
        reserva_por_ano_vida = [reserva_por_ano],
        expectativa_vida = [expectativa_vida],
        prob_deixar_pensao = [prob_pensao]
    )
end

end  # module Atuarial
