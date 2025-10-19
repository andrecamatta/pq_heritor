# Parsing - Leitura do Arquivo PNADC 2023

## Formato do Arquivo

O arquivo `PNADC_2023_visita5.txt` está em **Fixed-Width Format (FWF)**:
- Cada linha = 1 pessoa
- Cada variável ocupa posição fixa na linha
- Total de ~4000 caracteres por linha
- ~560.000 linhas (pessoas)
- Encoding: Latin-1 (ISO-8859-1)

## Estrutura Básica do Parser

### Esqueleto Julia

```julia
using DataFrames

# Constantes de posições FWF (baseadas no input SAS)
const POS_UPA = 12        # 9 chars
const LEN_UPA = 9
const POS_V2007 = 94      # 1 char (sexo)
const LEN_V2007 = 1
# ... etc

# Struct para armazenar dados
struct Pessoa
    domicilio_id::String
    pessoa_id::String
    idade::Int
    sexo::Int
    condicao_dom::Int
    peso::Float64
end

# Função de extração de campo
function extrair_campo(linha::String, pos::Int, len::Int)
    if length(linha) < pos + len - 1
        return ""
    end
    return strip(linha[pos:pos+len-1])
end

# Parser principal
function ler_pnadc(arquivo::String)
    pessoas = Pessoa[]

    open(arquivo, "r") do f
        for linha in eachline(f)
            # Extrair campos
            # Validar
            # Converter tipos
            # Armazenar
        end
    end

    return pessoas
end
```

## Posições das Variáveis Essenciais

### Identificação
```julia
const POS_UPA = 12        # Unidade Primária Amostragem (9 chars)
const LEN_UPA = 9
const POS_V1008 = 28      # Número do domicílio (2 chars)
const LEN_V1008 = 2
const POS_V1014 = 30      # Painel (2 chars)
const LEN_V1014 = 2
const POS_V2003 = 90      # Número da pessoa (2 chars)
const LEN_V2003 = 2
```

### Demografia
```julia
const POS_V2007 = 94      # Sexo: 1=Homem, 2=Mulher (1 char)
const LEN_V2007 = 1
const POS_V2009 = 103     # Idade em anos (3 chars)
const LEN_V2009 = 3
const POS_V2010 = 106     # Cor ou raça (1 char)
const LEN_V2010 = 1
const POS_UF = 6          # Unidade da Federação (2 chars)
const LEN_UF = 2
```

### Domicílio
```julia
const POS_V2005 = 92      # Condição no domicílio (2 chars)
const LEN_V2005 = 2       # 01=Responsável, 02=Cônjuge, 03=Filho, etc
const POS_V2001 = 88      # Número de pessoas no domicílio (2 chars)
const LEN_V2001 = 2
```

### Trabalho
```julia
const POS_V4028 = 183     # Servidor público estatutário (1 char)
const LEN_V4028 = 1       # 1=Sim, 2=Não
const POS_V4014 = 154     # Área do trabalho (1 char)
const LEN_V4014 = 1       # 1=Municipal, 2=Estadual, 3=Federal
```

### Peso Amostral
```julia
const POS_V1032 = 58      # Peso COM calibração Censo 2022 (15 chars)
const LEN_V1032 = 15
```

## Parser Completo - Exemplo Funcional

**Arquivo de referência**: `conjugality/01_pnadc2023_empirical_conjugality.jl`

```julia
#!/usr/bin/env julia

using DataFrames

# ============================================================================
# CONSTANTES DE POSIÇÕES FWF
# ============================================================================

const POS_UPA = 12
const LEN_UPA = 9
const POS_V1008 = 28
const LEN_V1008 = 2
const POS_V1014 = 30
const LEN_V1014 = 2
const POS_V1032 = 58
const LEN_V1032 = 15
const POS_V2003 = 90
const LEN_V2003 = 2
const POS_V2005 = 92
const LEN_V2005 = 2
const POS_V2007 = 94
const LEN_V2007 = 1
const POS_V2009 = 103
const LEN_V2009 = 3

# ============================================================================
# ESTRUTURA DE DADOS
# ============================================================================

struct Pessoa
    domicilio_id::String
    pessoa_id::String
    idade::Int
    sexo::Int          # 1=Homem, 2=Mulher
    condicao_dom::Int  # 01=Responsável, 02=Cônjuge, 03=Filho, etc.
    peso::Float64
end

# ============================================================================
# FUNÇÕES DE PARSING
# ============================================================================

function extrair_campo(linha::String, pos::Int, len::Int)
    """Extrai campo do FWF (posições 1-indexed)"""
    if length(linha) < pos + len - 1
        return ""
    end
    return strip(linha[pos:pos+len-1])
end

function ler_pnadc(arquivo::String)
    """
    Parser principal do PNADC 2023.

    Retorna: (pessoas, n_linhas, n_erros)
    """
    pessoas_local = Pessoa[]
    n_linhas = 0
    n_erros = 0

    open(arquivo, "r") do f
        for linha in eachline(f)
            n_linhas += 1

            # Progresso a cada 100k linhas
            if n_linhas % 100_000 == 0
                print("\rLinhas processadas: $(n_linhas ÷ 1000)k")
            end

            try
                # Extrair campos
                upa = extrair_campo(linha, POS_UPA, LEN_UPA)
                v1008 = extrair_campo(linha, POS_V1008, LEN_V1008)
                v1014 = extrair_campo(linha, POS_V1014, LEN_V1014)
                v2003 = extrair_campo(linha, POS_V2003, LEN_V2003)
                v2005_str = extrair_campo(linha, POS_V2005, LEN_V2005)
                v2007_str = extrair_campo(linha, POS_V2007, LEN_V2007)
                v2009_str = extrair_campo(linha, POS_V2009, LEN_V2009)
                v1032_str = extrair_campo(linha, POS_V1032, LEN_V1032)

                # Validar campos não-vazios
                if isempty(upa) || isempty(v2007_str) || isempty(v2009_str)
                    continue
                end

                # Converter para tipos apropriados
                idade = parse(Int, v2009_str)
                sexo = parse(Int, v2007_str)
                condicao = parse(Int, v2005_str)
                peso = parse(Float64, v1032_str)

                # Validar valores plausíveis
                if sexo ∉ [1, 2] || idade < 0 || idade > 120 || peso <= 0
                    continue
                end

                # Criar IDs compostos
                domicilio_id = string(upa, v1008, v1014)
                pessoa_id = string(domicilio_id, v2003)

                # Armazenar pessoa
                push!(pessoas_local, Pessoa(
                    domicilio_id,
                    pessoa_id,
                    idade,
                    sexo,
                    condicao,
                    peso
                ))

            catch e
                n_erros += 1
            end
        end
    end

    println()  # Nova linha após progresso
    return (pessoas_local, n_linhas, n_erros)
end

# ============================================================================
# USO
# ============================================================================

# Ler arquivo
data_file = "../data_pnadc2023/PNADC_2023_visita5.txt"
pessoas, n_linhas, n_erros = ler_pnadc(data_file)

println("Total de linhas: $n_linhas")
println("Pessoas válidas: $(length(pessoas))")
println("Erros/descartadas: $n_erros")
```

## Conversão para DataFrame

```julia
# Converter para DataFrame para análises
df = DataFrame(
    domicilio_id = [p.domicilio_id for p in pessoas],
    pessoa_id = [p.pessoa_id for p in pessoas],
    idade = [p.idade for p in pessoas],
    sexo = [p.sexo for p in pessoas],
    condicao_dom = [p.condicao_dom for p in pessoas],
    peso = [p.peso for p in pessoas]
)

# Adicionar labels descritivos
df[!, :sexo_label] = map(s -> s == 1 ? "Homem" : "Mulher", df.sexo)

# Salvar
using CSV
CSV.write("pnadc2023_parsed.csv", df)
```

## Otimizações de Performance

### 1. Pré-alocação
```julia
# Estimar tamanho baseado em contagem de linhas
n_linhas_estimado = 600_000
pessoas = Vector{Pessoa}(undef, n_linhas_estimado)
idx = 1
```

### 2. Processamento Paralelo (Avançado)
```julia
using Base.Threads

# Dividir arquivo em chunks
# Processar cada chunk em thread separada
# Combinar resultados
```

### 3. Filtros Antecipados
```julia
# Se só precisa de servidores, filtrar logo
if v4028_str != "1"
    continue  # Pular não-servidores
end
```

## Validações Recomendadas

### Após Parsing
```julia
# Verificar distribuição de sexo
println("Distribuição por sexo:")
println(countmap(df.sexo))
# Esperado: ~52% mulheres, ~48% homens

# Verificar distribuição de idade
println("Idade média: $(mean(df.idade))")
println("Idade mediana: $(median(df.idade))")
# Esperado: ~30-35 anos

# Verificar pesos
println("Peso médio: $(mean(df.peso))")
println("Peso total: $(sum(df.peso))")
# Peso total deve ser próximo da população brasileira (~203 milhões em 2023)

# Verificar domicílios únicos
n_dominios = length(unique(df.domicilio_id))
println("Domicílios únicos: $n_dominios")
# Esperado: ~137.000 domicílios
```

## Tratamento de Erros Comuns

### Problema: Encoding incorreto
```julia
# Solução: especificar encoding
open(arquivo, "r", enc"ISO-8859-1") do f
    # ...
end
```

### Problema: Linha incompleta
```julia
# Já tratado na função extrair_campo
if length(linha) < pos + len - 1
    return ""  # Retorna vazio ao invés de erro
end
```

### Problema: Valor numérico inválido
```julia
# Usar tryparse ao invés de parse
idade_parsed = tryparse(Int, v2009_str)
if idade_parsed === nothing
    continue  # Pular registro inválido
end
```

## Debugging e Inspeção

### Ver linha raw
```julia
# Inspecionar linha específica
open(arquivo, "r") do f
    for (i, linha) in enumerate(eachline(f))
        if i == 1000  # Linha 1000
            println("Comprimento: $(length(linha))")
            println("Primeiros 200 chars:")
            println(linha[1:min(200, length(linha))])
            break
        end
    end
end
```

### Testar com subset
```julia
# Processar apenas primeiras N linhas para teste
function ler_pnadc_subset(arquivo::String, max_linhas::Int=10000)
    # ... mesmo código, mas com:
    if n_linhas >= max_linhas
        break
    end
end
```

## Referência do Input SAS

O arquivo `data_pnadc2023/input_PNADC_2023_visita5.txt` contém o dicionário completo de posições:

```sas
@0001 Ano   $4.   /* Ano de referência */
@0006 UF   $2.   /* Unidade da Federação */
@0012 UPA   $9.   /* Unidade Primária de Amostragem */
@0028 V1008   $2.   /* Número de seleção do domicílio */
...
@0094 V2007   $1.   /* Sexo */
@0103 V2009   3.   /* Idade na data de referência */
...
```

**Formato**: `@POSIÇÃO VARIÁVEL TIPO`
- `@0094` = posição 94 (1-indexed)
- `$1.` = string de 1 caractere
- `3.` = numérico de 3 caracteres

## Próximos Passos

Após o parsing:
1. **Filtrar populações**: Ver [04_identify_servants.md](04_identify_servants.md)
2. **Analisar família**: Ver [05_family_composition.md](05_family_composition.md)
3. **Gerar tabelas**: Ver [06_probability_tables.md](06_probability_tables.md)
4. **Exemplos completos**: Ver [09_examples.md](09_examples.md)
