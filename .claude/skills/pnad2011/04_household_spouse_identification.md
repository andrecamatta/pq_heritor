# PNAD 2011 - Identificação de Cônjuges no Domicílio

## Como Identificar se uma Pessoa Tem Cônjuge

Na PNAD 2011, a identificação de cônjuge é feita através da variável **V0401 (Condição no domicílio)**.

## Lógica de Identificação

### Para a Pessoa de Referência (Chefe)

Uma pessoa de referência (V0401 = 01) **tem cônjuge** se existir outra pessoa no mesmo domicílio com **V0401 = 02**.

### Para o Cônjuge

Uma pessoa com V0401 = 02 **é cônjuge** da pessoa de referência do domicílio.

### Outras Condições

Pessoas com V0401 ∈ {03, 04, 05, 06, 07, 08} geralmente não têm cônjuge identificado na pesquisa (filho, agregado, etc.).

⚠️ **Limitação**: A estrutura da PNAD/PNADC não identifica cônjuge de filho(a) que more junto com os pais.

## Implementação em Julia

### Método 1: Marcação Simples por Domicílio

```julia
using DataFrames

function identificar_conjuges_pnad2011!(df::DataFrame)
    """
    Marca quem tem cônjuge no domicílio

    Adiciona coluna: tem_conjuge (Bool)
    """

    # Criar chave do domicílio
    df.domicilio_id = string.(df.UF) .* "_" .* string.(df.V0102) .* "_" .* string.(df.V0103)

    # Inicializar
    df.tem_conjuge = false

    # Para cada domicílio
    for dom_id in unique(df.domicilio_id)
        # Pessoas do domicílio
        idx_dom = df.domicilio_id .== dom_id
        pessoas_dom = df[idx_dom, :]

        # Verificar se há cônjuge (V0401 = 02)
        tem_pessoa_conjuge = any(pessoas_dom.V0401 .== 02)

        if tem_pessoa_conjuge
            # Marcar pessoa de referência como tendo cônjuge
            idx_ref = idx_dom .&& (df.V0401 .== 01)
            df[idx_ref, :tem_conjuge] .= true

            # Marcar cônjuge como tendo cônjuge
            idx_conj = idx_dom .&& (df.V0401 .== 02)
            df[idx_conj, :tem_conjuge] .= true
        end
    end

    return df
end

# Uso
df = identificar_conjuges_pnad2011!(df)
```

### Método 2: Agregação por Domicílio (Mais Eficiente)

```julia
using DataFrames

function identificar_conjuges_agrupado!(df::DataFrame)
    """
    Identifica cônjuges usando groupby (mais eficiente)
    """

    # Chave do domicílio
    df.domicilio_id = string.(df.UF) .* "_" .* string.(df.V0102) .* "_" .* string.(df.V0103)

    # Por domicílio, verificar se há cônjuge
    dom_conjuges = combine(groupby(df, :domicilio_id)) do sdf
        DataFrame(tem_conjugue_no_dom = any(sdf.V0401 .== 02))
    end

    # Juntar de volta ao dataframe principal
    df = leftjoin(df, dom_conjuges, on = :domicilio_id)

    # Pessoa tem cônjuge se:
    # - É pessoa de referência (01) E há cônjuge no domicílio
    # - OU é cônjuge (02)
    df.tem_conjuge = (df.V0401 .== 01 .&& df.tem_conjugue_no_dom) .||
                      (df.V0401 .== 02)

    select!(df, Not(:tem_conjugue_no_dom))  # Remover coluna temporária

    return df
end
```

## Identificação de Pares (Chefe + Cônjuge)

Para análise de **age gap** (diferença de idade entre cônjuges), precisamos parear:

```julia
function extrair_pares_conjuges(df::DataFrame)
    """
    Extrai pares de cônjuges com suas idades

    Retorna DataFrame com:
    - domicilio_id
    - idade_ref (pessoa de referência)
    - sexo_ref
    - idade_conj (cônjuge)
    - sexo_conj
    - age_gap (idade_ref - idade_conj)
    - peso
    """

    df.domicilio_id = string.(df.UF) .* "_" .* string.(df.V0102) .* "_" .* string.(df.V0103)

    pares = DataFrame(
        domicilio_id = String[],
        idade_ref = Int[],
        sexo_ref = Int[],
        idade_conj = Int[],
        sexo_conj = Int[],
        age_gap = Int[],
        peso = Float64[]
    )

    for dom_id in unique(df.domicilio_id)
        pessoas = df[df.domicilio_id .== dom_id, :]

        # Pessoa de referência
        ref = filter(p -> p.V0401 == 01, pessoas)
        if nrow(ref) == 0
            continue
        end
        ref = ref[1, :]

        # Cônjuge
        conj = filter(p -> p.V0401 == 02, pessoas)
        if nrow(conj) == 0
            continue  # Sem cônjuge
        end
        conj = conj[1, :]

        # Adicionar par
        push!(pares, (
            dom_id,
            ref.V8005,        # Idade referência
            ref.V0302,        # Sexo referência
            conj.V8005,       # Idade cônjuge
            conj.V0302,       # Sexo cônjuge
            ref.V8005 - conj.V8005,  # Age gap
            ref.V4729         # Peso (usar peso da referência)
        ))
    end

    return pares
end

# Uso
pares = extrair_pares_conjuges(df)
```

## Validações Importantes

### 1. Domicílios com Múltiplos Cônjuges

⚠️ Em teoria, cada domicílio deveria ter no máximo 1 cônjuge. Verificar anomalias:

```julia
function validar_conjuges(df::DataFrame)
    """
    Verifica se há domicílios com múltiplos cônjuges
    """

    df.domicilio_id = string.(df.UF) .* "_" .* string.(df.V0102) .* "_" .* string.(df.V0103)

    # Contar cônjuges por domicílio
    contagem = combine(groupby(df, :domicilio_id)) do sdf
        DataFrame(n_conjuges = count(sdf.V0401 .== 02))
    end

    # Domicílios com mais de 1 cônjuge
    problemas = filter(row -> row.n_conjuges > 1, contagem)

    if nrow(problemas) > 0
        @warn "Encontrados $(nrow(problemas)) domicílios com múltiplos cônjuges!"
        println("Exemplos:")
        println(first(problemas, 5))
    else
        println("✓ Validação OK: No máximo 1 cônjuge por domicílio")
    end

    return contagem
end
```

### 2. Domicílios Unipessoais

Domicílios com 1 pessoa (V0301 = 01) não devem ter cônjuge:

```julia
# Verificar
df_uni = filter(row -> row.V0301 == 01, df)
n_com_conjuge = count(df_uni.tem_conjuge)

if n_com_conjuge > 0
    @warn "Domicílios unipessoais com cônjuge: $n_com_conjuge (erro nos dados?)"
end
```

### 3. Sexo dos Cônjuges

Verificar distribuição de casais por composição de sexo:

```julia
pares = extrair_pares_conjuges(df)

# Criar categoria
pares.tipo_casal = ifelse.(
    pares.sexo_ref .== pares.sexo_conj,
    "Mesmo sexo",
    "Sexo diferente"
)

println("Distribuição de casais:")
println(combine(groupby(pares, :tipo_casal), nrow => :n))
```

## Filtros Recomendados para Tábuas

Para tábuas de conjugalidade robustas:

```julia
function filtrar_para_tabuas(df::DataFrame)
    """
    Filtra registros para análise de conjugalidade
    """

    # 1. Idade entre 15 e 90 anos
    filter!(row -> 15 <= row.V8005 <= 90, df)

    # 2. Peso válido
    filter!(row -> row.V4729 > 0, df)

    # 3. Sexo válido
    filter!(row -> row.V0302 ∈ [2, 4], df)

    # 4. Condição no domicílio válida (01-08)
    filter!(row -> 1 <= row.V0401 <= 8, df)

    return df
end
```

## Uso em Tábuas de Conjugalidade

### Proporção de Pessoas com Cônjuge por Idade e Sexo

```julia
function calcular_tabua_conjugalidade_pnad2011(df::DataFrame)
    """
    Calcula proporção de pessoas com cônjuge, ponderada
    """

    # Identificar cônjuges
    identificar_conjuges_pnad2011!(df)

    # Agrupar por sexo e idade
    tabua = combine(groupby(df, [:V0302, :V8005])) do sdf
        # Total ponderado
        total_pond = sum(sdf.V4729)

        # Com cônjuge ponderado
        com_conjuge_pond = sum(sdf.V4729[sdf.tem_conjuge])

        # Proporção
        prop = total_pond > 0 ? com_conjuge_pond / total_pond * 100 : 0.0

        DataFrame(
            prop_com_conjuge = prop,
            n_total_pond = total_pond,
            n_amostra = nrow(sdf)
        )
    end

    # Adicionar labels
    tabua.sexo = ifelse.(tabua.V0302 .== 2, "Masculino", "Feminino")
    rename!(tabua, :V8005 => :idade)

    return tabua
end
```

## Comparação com PNADC 2023

A lógica é **idêntica**, mas com nomes de variáveis diferentes:

| Conceito | PNAD 2011 | PNADC 2023 |
|----------|-----------|------------|
| Condição no domicílio | V0401 | V2005 |
| Pessoa de referência | V0401 = 01 | V2005 = 01 |
| Cônjuge | V0401 = 02 | V2005 = 02 ou 03* |
| Idade | V8005 | V2009 |
| Sexo | V0302 | V2007 |
| Peso | V4729 | V1032 |

\* PNADC 2023 distingue cônjuge de sexo diferente (02) e mesmo sexo (03)

## Referências

- IBGE (2012). *Dicionário de Variáveis PNAD 2011*.
- `.claude/skills/pnadc2023/04_household_spouse_identification.md` (mesmo conceito)

---

**Última atualização**: 2025-10-17
**Status**: ⚠️ Lógica baseada em padrão PNAD/PNADC - verificar códigos no dicionário oficial
