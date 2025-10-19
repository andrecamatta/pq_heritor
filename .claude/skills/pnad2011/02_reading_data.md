# PNAD 2011 - Leitura de Dados FWF

## Como Ler Arquivos de Largura Fixa (FWF)

A PNAD 2011 usa formato **Fixed-Width Format** onde cada variável ocupa posições específicas em cada linha.

## Método 1: Função Manual em Julia

### Implementação Básica

```julia
using DataFrames

function ler_fwf_pnad2011(arquivo::String, layout::Dict)
    """
    Lê arquivo FWF da PNAD 2011

    Parâmetros:
    - arquivo: caminho do arquivo PES2011.txt
    - layout: Dict com nome_variavel => (col_inicio:col_fim)

    Retorna:
    - DataFrame com as variáveis especificadas
    """

    # Ler todas as linhas
    linhas = readlines(arquivo)
    n_linhas = length(linhas)

    println("Total de registros: $n_linhas")

    # Criar DataFrame vazio
    df = DataFrame()

    # Extrair cada variável
    for (var_nome, posicoes) in layout
        println("Extraindo $var_nome (posições $posicoes)...")

        valores = String[]

        for linha in linhas
            if length(linha) >= maximum(posicoes)
                valor = strip(linha[posicoes])
                push!(valores, valor)
            else
                # Linha incompleta - usar missing
                push!(valores, "")
            end
        end

        df[!, var_nome] = valores
    end

    return df
end
```

### Uso

```julia
# Definir layout (posições a serem verificadas no dicionário oficial)
layout_pnad2011 = Dict(
    :UF => (1:2),
    :V0102 => (3:7),
    :V0103 => (8:10),
    :V0300 => (11:12),
    :V0302 => (13:13),      # Sexo
    :V8005 => (14:16),      # Idade
    :V0401 => (17:18),      # Condição no domicílio
    :V4706 => (50:51),      # Posição na ocupação (posição aproximada!)
    :V4729 => (100:113)     # Peso (posição aproximada!)
)

# Ler arquivo
df = ler_fwf_pnad2011("dados/PES2011.txt", layout_pnad2011)
```

## Método 2: Usando CSV.jl com Especificação de Posições

```julia
using CSV
using DataFrames

function ler_pnad2011_csv_format(arquivo::String)
    # CSV.jl não tem suporte nativo para FWF
    # Alternativa: pré-processar com Python ou R
    # Ou usar método manual acima
end
```

**Recomendação**: Para FWF, o método manual é mais direto em Julia.

## Conversão de Tipos de Dados

Após leitura, converter strings para tipos apropriados:

```julia
function converter_tipos_pnad2011!(df::DataFrame)
    """
    Converte tipos de dados após leitura FWF
    """

    # Identificação
    df.UF = parse.(Int, df.UF)
    df.V0102 = parse.(Int, df.V0102)
    df.V0103 = parse.(Int, df.V0103)
    df.V0300 = parse.(Int, df.V0300)

    # Demográficas
    df.V0302 = parse.(Int, df.V0302)  # Sexo
    df.V8005 = parse.(Int, df.V8005)  # Idade
    df.V0401 = parse.(Int, df.V0401)  # Condição no domicílio

    # Trabalho
    df.V4706 = parse.(Int, df.V4706)  # Posição na ocupação

    # Peso (cuidado com formato decimal!)
    # Pode ser: 123456789012.34 ou 12345678901234 (sem ponto decimal)
    # Verificar documentação!
    df.V4729 = parse.(Float64, df.V4729) ./ 100  # Se sem ponto decimal
    # OU
    # df.V4729 = parse.(Float64, df.V4729)  # Se já tiver ponto decimal

    return df
end

# Uso
df = ler_fwf_pnad2011("dados/PES2011.txt", layout_pnad2011)
converter_tipos_pnad2011!(df)
```

## Tratamento de Missing Values

### Códigos de Missing na PNAD 2011

Geralmente:
- **9** = missing (1 dígito)
- **99** = missing (2 dígitos)
- **999** = missing (3 dígitos)
- **Brancos** = não aplicável

```julia
function tratar_missing_pnad2011!(df::DataFrame)
    """
    Substitui códigos de missing por `missing`
    """

    # Idade: 999 = missing
    df.V8005 = replace(df.V8005, 999 => missing)

    # Posição na ocupação: 9 = missing (não aplicável - desocupado)
    df.V4706 = replace(df.V4706, 9 => missing)

    # Sexo: nunca deve ser missing
    # Condição no domicílio: nunca deve ser missing

    return df
end
```

## Filtragem e Validação

### Checklist de Validação

```julia
function validar_dados_pnad2011(df::DataFrame)
    """
    Valida dados após leitura
    """

    println("=== Validação dos Dados PNAD 2011 ===\n")

    # 1. Número de registros
    println("Total de registros: $(nrow(df))")

    # 2. Valores de sexo
    println("\nDistribuição de sexo (V0302):")
    println(countmap(df.V0302))
    # Esperado: 2 (Masculino) e 4 (Feminino)

    # 3. Idade
    println("\nIdade (V8005):")
    println("  Mínima: $(minimum(skipmissing(df.V8005)))")
    println("  Máxima: $(maximum(skipmissing(df.V8005)))")
    println("  Média: $(round(mean(skipmissing(df.V8005)), digits=1))")

    # 4. Condição no domicílio
    println("\nCondição no domicílio (V0401):")
    println(countmap(df.V0401))

    # 5. Pesos
    println("\nPeso (V4729):")
    println("  Mínimo: $(minimum(skipmissing(df.V4729)))")
    println("  Máximo: $(maximum(skipmissing(df.V4729)))")
    println("  Soma total: $(sum(skipmissing(df.V4729)))")
    # Soma deve ser próxima da população brasileira em 2011 (~195 milhões)

    # 6. Warnings
    if any(df.V0302 .∉ Ref([2, 4]))
        @warn "Valores inesperados em V0302 (Sexo)"
    end

    if any(df.V8005 .< 0 .|| df.V8005 .> 120)
        @warn "Idades fora do intervalo esperado"
    end

    println("\n" * "="^50)
end
```

## Script Completo de Leitura

### `scripts/ler_pnad2011.jl`

```julia
#!/usr/bin/env julia
# Script para ler microdados PNAD 2011

using DataFrames
using CSV
using Statistics

# === LAYOUT PNAD 2011 ===
# ⚠️ VERIFICAR POSIÇÕES NO DICIONÁRIO OFICIAL!

layout_pnad2011 = Dict(
    # Identificação
    :UF => (1:2),
    :V0102 => (3:7),        # Número de controle
    :V0103 => (8:10),       # Número de série
    :V0300 => (11:12),      # Número de ordem
    :V0301 => (13:14),      # Número de pessoas no domicílio

    # Demográficas
    :V0302 => (15:15),      # Sexo
    :V8005 => (16:18),      # Idade
    :V0401 => (19:20),      # Condição no domicílio

    # Trabalho (POSIÇÕES APROXIMADAS - VERIFICAR!)
    :V4706 => (50:51),      # Posição na ocupação

    # Peso (POSIÇÃO APROXIMADA - VERIFICAR!)
    :V4729 => (100:113)     # Peso da pessoa
)

# === FUNÇÃO DE LEITURA ===

function ler_fwf_pnad2011(arquivo::String, layout::Dict)
    linhas = readlines(arquivo)
    df = DataFrame()

    for (var_nome, posicoes) in layout
        valores = [length(linha) >= maximum(posicoes) ?
                   strip(linha[posicoes]) : ""
                   for linha in linhas]
        df[!, var_nome] = valores
    end

    return df
end

# === CONVERSÃO DE TIPOS ===

function converter_tipos!(df::DataFrame)
    df.UF = parse.(Int, df.UF)
    df.V0102 = parse.(Int, df.V0102)
    df.V0103 = parse.(Int, df.V0103)
    df.V0300 = parse.(Int, df.V0300)
    df.V0301 = parse.(Int, df.V0301)
    df.V0302 = parse.(Int, df.V0302)
    df.V8005 = parse.(Int, df.V8005)
    df.V0401 = parse.(Int, df.V0401)
    df.V4706 = parse.(Int, df.V4706)

    # Peso: verificar formato no dicionário!
    # Se sem ponto decimal: dividir por 100
    df.V4729 = parse.(Float64, df.V4729) ./ 100

    return df
end

# === PROCESSAMENTO ===

function processar_pnad2011(arquivo_entrada::String, arquivo_saida::String)
    println("=== Leitura PNAD 2011 ===\n")

    # Ler
    println("Lendo arquivo FWF: $arquivo_entrada")
    df = ler_fwf_pnad2011(arquivo_entrada, layout_pnad2011)
    println("✓ $(nrow(df)) registros lidos\n")

    # Converter tipos
    println("Convertendo tipos de dados...")
    converter_tipos!(df)
    println("✓ Tipos convertidos\n")

    # Criar variáveis auxiliares
    println("Criando variáveis auxiliares...")
    df.sexo = ifelse.(df.V0302 .== 2, "Masculino", "Feminino")
    df.idade = df.V8005
    df.tem_conjuge = df.V0401 .== 02
    df.servidor_publico = df.V4706 .== 05  # Verificar código!
    df.peso = df.V4729
    println("✓ Variáveis criadas\n")

    # Filtrar idades válidas
    println("Filtrando idades 15-90...")
    df = filter(row -> 15 <= row.idade <= 90, df)
    println("✓ $(nrow(df)) registros após filtro\n")

    # Salvar
    println("Salvando em: $arquivo_saida")
    CSV.write(arquivo_saida, df)
    println("✓ Arquivo salvo\n")

    # Resumo
    println("=== Resumo ===")
    println("Total de pessoas: $(nrow(df))")
    println("  Masculino: $(count(df.sexo .== "Masculino"))")
    println("  Feminino: $(count(df.sexo .== "Feminino"))")
    println("Com cônjuge: $(count(df.tem_conjuge))")
    println("Servidores públicos: $(count(df.servidor_publico))")
    println("População estimada: $(round(sum(df.peso) / 1_000_000, digits=1)) milhões")

    return df
end

# === EXECUÇÃO ===

if abspath(PROGRAM_FILE) == @__FILE__
    arquivo_entrada = "dados/PES2011.txt"
    arquivo_saida = "dados/pnad2011_processado.csv"

    df = processar_pnad2011(arquivo_entrada, arquivo_saida)
end
```

## Próximos Passos

Após leitura bem-sucedida:
1. Validar estrutura dos dados
2. Identificar cônjuges no domicílio (ver `04_household_spouse_identification.md`)
3. Calcular tábuas de conjugalidade (ver `06_probability_tables.md`)

## Referências

- IBGE (2012). *Dicionário de variáveis PNAD 2011*.
- IBGE (2012). *Layout de leitura dos microdados PNAD 2011*.

---

**Última atualização**: 2025-10-17
**Status**: ⚠️ Posições das variáveis são ilustrativas - verificar dicionário oficial
