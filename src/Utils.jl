"""
Módulo de Utilidades Compartilhadas

Funções auxiliares usadas em múltiplos scripts do projeto.

Uso:
```julia
include("src/Utils.jl")
using .Utils
```
"""
module Utils

using CSV
using DataFrames
using Statistics

export carregar_tabelas_credibilidade
export buscar_parametro
export validar_idade_sexo

# ============================================================================
# CARREGAMENTO DE TABELAS
# ============================================================================

# Cache global das tabelas (carregadas uma vez por sessão)
const TABELAS_CARREGADAS = Ref(false)
const DF_CONJUGALIDADE = Ref{DataFrame}()
const DF_AGE_GAP = Ref{DataFrame}()
const DF_FILHOS = Ref{DataFrame}()

"""
    carregar_tabelas_credibilidade(; verbose=true)

Carrega as tabelas de credibilidade de conjugalidade, age gap e filhos.

Tabelas são carregadas uma vez e cacheadas globalmente para eficiência.

# Arquivos carregados
- `resultados/conjugalidade_credivel.csv`
- `resultados/age_gap_credivel.csv`
- `resultados/filhos_credivel.csv`

# Argumentos
- `verbose::Bool`: Mostrar mensagens de progresso (default: true)

# Retorna
Tupla `(df_conjugalidade, df_age_gap, df_filhos)` com os DataFrames

# Exemplo
```julia
include("src/Utils.jl")
using .Utils

df_conj, df_age, df_filhos = carregar_tabelas_credibilidade()
```
"""
function carregar_tabelas_credibilidade(; verbose::Bool=true)
    # Se já carregadas, retornar cache
    if TABELAS_CARREGADAS[]
        return (DF_CONJUGALIDADE[], DF_AGE_GAP[], DF_FILHOS[])
    end

    if verbose
        println("\n📂 Carregando tabelas de credibilidade...")
    end

    RESULTADOS_DIR = "resultados"

    # 1. Conjugalidade
    arquivo_conj = joinpath(RESULTADOS_DIR, "conjugalidade_credivel.csv")
    if !isfile(arquivo_conj)
        error("Arquivo não encontrado: $arquivo_conj\nExecute primeiro: julia 08_credibilidade_servidores.jl")
    end
    DF_CONJUGALIDADE[] = CSV.read(arquivo_conj, DataFrame)
    if verbose
        println("   ✓ Conjugalidade: $(nrow(DF_CONJUGALIDADE[])) registros")
    end

    # 2. Age gap
    arquivo_age = joinpath(RESULTADOS_DIR, "age_gap_credivel.csv")
    if !isfile(arquivo_age)
        error("Arquivo não encontrado: $arquivo_age\nExecute primeiro: julia 09_age_gap_servidores.jl")
    end
    DF_AGE_GAP[] = CSV.read(arquivo_age, DataFrame)
    if verbose
        println("   ✓ Age gap: $(nrow(DF_AGE_GAP[])) registros")
    end

    # 3. Filhos
    arquivo_filhos = joinpath(RESULTADOS_DIR, "filhos_credivel.csv")
    if !isfile(arquivo_filhos)
        error("Arquivo não encontrado: $arquivo_filhos\nExecute primeiro: julia 13_credibilidade_filhos.jl")
    end
    DF_FILHOS[] = CSV.read(arquivo_filhos, DataFrame)
    if verbose
        println("   ✓ Filhos: $(nrow(DF_FILHOS[])) registros")
    end

    TABELAS_CARREGADAS[] = true

    if verbose
        println("   ✅ Tabelas carregadas com sucesso!\n")
    end

    return (DF_CONJUGALIDADE[], DF_AGE_GAP[], DF_FILHOS[])
end

# ============================================================================
# BUSCA DE PARÂMETROS
# ============================================================================

"""
    buscar_parametro(df, idade, sexo, coluna)

Busca parâmetro na tabela por (idade, sexo).

Se não encontrar exatamente, usa interpolação linear dos vizinhos.

# Argumentos
- `df::DataFrame`: Tabela com colunas `idade`, `sexo` e `coluna`
- `idade::Int`: Idade a buscar (15-90)
- `sexo::String`: "Masculino" ou "Feminino"
- `coluna::Symbol`: Coluna a extrair (ex: `:P_suavizado`)

# Retorna
`Float64` com o valor do parâmetro

# Exemplo
```julia
P_casado = buscar_parametro(df_conjugalidade, 60, "Masculino", :P_suavizado)
```
"""
function buscar_parametro(df::DataFrame, idade::Int, sexo::String, coluna::Symbol)
    # Filtrar por sexo
    df_sexo = filter(row -> row.sexo == sexo, df)

    # Validar entrada (após filtrar para ter colunas corretas)
    if !(coluna in propertynames(df_sexo))
        error("Coluna $coluna não existe no DataFrame. Colunas disponíveis: $(propertynames(df_sexo))")
    end

    if nrow(df_sexo) == 0
        error("Nenhum registro encontrado para sexo '$sexo'")
    end

    # Tentar busca exata
    linha = filter(row -> row.idade == idade, df_sexo)

    if nrow(linha) > 0
        valor = linha[1, coluna]
        # Se missing ou NaN, usar vizinhos
        if !ismissing(valor) && (!(valor isa Number) || !isnan(valor))
            return Float64(valor)
        end
    end

    # Idade fora do range ou valor missing: usar vizinho/interpolação
    return buscar_vizinho(df_sexo, idade, coluna)
end

"""
    buscar_vizinho(df_sexo, idade, coluna)

Busca valor vizinho mais próximo ou interpola linearmente.

Função auxiliar para `buscar_parametro`.
"""
function buscar_vizinho(df_sexo::DataFrame, idade::Int, coluna::Symbol)
    idades_disponiveis = sort(df_sexo.idade)

    if idade < minimum(idades_disponiveis)
        # Usar mínimo disponível
        idx = findfirst(==(minimum(idades_disponiveis)), df_sexo.idade)
        return Float64(df_sexo[idx, coluna])
    elseif idade > maximum(idades_disponiveis)
        # Usar máximo disponível
        idx = findfirst(==(maximum(idades_disponiveis)), df_sexo.idade)
        return Float64(df_sexo[idx, coluna])
    else
        # Interpolação linear entre vizinhos
        idade_inf = maximum(filter(x -> x <= idade, idades_disponiveis))
        idade_sup = minimum(filter(x -> x >= idade, idades_disponiveis))

        if idade_inf == idade_sup
            idx = findfirst(==(idade_inf), df_sexo.idade)
            return Float64(df_sexo[idx, coluna])
        end

        # Valores dos vizinhos
        idx_inf = findfirst(==(idade_inf), df_sexo.idade)
        idx_sup = findfirst(==(idade_sup), df_sexo.idade)

        valor_inf = Float64(df_sexo[idx_inf, coluna])
        valor_sup = Float64(df_sexo[idx_sup, coluna])

        # Interpolação
        peso = (idade - idade_inf) / (idade_sup - idade_inf)
        return valor_inf * (1 - peso) + valor_sup * peso
    end
end

# ============================================================================
# VALIDAÇÕES
# ============================================================================

"""
    validar_idade_sexo(idade, sexo)

Valida idade e sexo com mensagens de erro informativas.

# Argumentos
- `idade::Int`: Idade a validar
- `sexo::String`: Sexo a validar

# Raises
`AssertionError` se validação falhar

# Exemplo
```julia
validar_idade_sexo(60, "Masculino")  # OK
validar_idade_sexo(10, "M")          # ERROR: Idade deve estar entre 15 e 90
```
"""
function validar_idade_sexo(idade::Int, sexo::String)
    @assert idade >= 15 && idade <= 90 "Idade deve estar entre 15 e 90 anos (recebido: $idade)"
    @assert sexo in ["Masculino", "Feminino"] "Sexo deve ser 'Masculino' ou 'Feminino' (recebido: '$sexo')"
    return true
end

end  # module Utils
