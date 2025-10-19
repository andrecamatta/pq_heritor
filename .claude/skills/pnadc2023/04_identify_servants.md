# Identificação de Servidores Públicos - PNADC 2023

## Visão Geral

O PNADC 2023 permite identificar servidores públicos através de duas variáveis principais:
- **V4028**: Servidor público estatutário (Sim/Não)
- **V4014**: Área do trabalho (Municipal/Estadual/Federal)

## Variáveis-Chave

| Variável | Posição | Valores | Significado |
|----------|---------|---------|-------------|
| **V4028** | 183 | 1=Sim, 2=Não | Servidor público estatutário |
| **V4014** | 154 | 1=Municipal, 2=Estadual, 3=Federal | Área do trabalho |
| **V4012** | 146 | 07=Militar/estatutário | Posição na ocupação |

## Método de Identificação

### 1. População Geral
```julia
# Todos os indivíduos da amostra
populacao_geral = pessoas
```

### 2. Servidores Estatutários (Todos os Níveis)
```julia
# Filtro: V4028 = '1'
servidores = filter(p -> p.servidor_estatutario == 1, pessoas)
```

### 3. Servidores por Nível Administrativo

```julia
# Municipal: V4028='1' AND V4014='1'
municipais = filter(p -> p.servidor_estatutario == 1 && p.area_trabalho == 1, pessoas)

# Estaduais: V4028='1' AND V4014='2'
estaduais = filter(p -> p.servidor_estatutario == 1 && p.area_trabalho == 2, pessoas)

# Federais: V4028='1' AND V4014='3'
federais = filter(p -> p.servidor_estatutario == 1 && p.area_trabalho == 3, pessoas)
```

## Parser com Identificação de Servidores

### Adicionar Campos ao Struct

```julia
struct Pessoa
    domicilio_id::String
    pessoa_id::String
    idade::Int
    sexo::Int
    condicao_dom::Int
    peso::Float64
    # Novos campos para trabalho
    servidor_estatutario::Union{Int, Missing}
    area_trabalho::Union{Int, Missing}
end
```

### Extração no Parser

```julia
function ler_pnadc(arquivo::String)
    pessoas_local = Pessoa[]

    const POS_V4028 = 183
    const LEN_V4028 = 1
    const POS_V4014 = 154
    const LEN_V4014 = 1

    open(arquivo, "r") do f
        for linha in eachline(f)
            # ... campos anteriores ...

            # Extrair variáveis de trabalho
            v4028_str = extrair_campo(linha, POS_V4028, LEN_V4028)
            v4014_str = extrair_campo(linha, POS_V4014, LEN_V4014)

            # Converter (permitir missing)
            servidor = isempty(v4028_str) ? missing : parse(Int, v4028_str)
            area = isempty(v4014_str) ? missing : parse(Int, v4014_str)

            push!(pessoas_local, Pessoa(
                domicilio_id,
                pessoa_id,
                idade,
                sexo,
                condicao,
                peso,
                servidor,
                area
            ))
        end
    end

    return pessoas_local
end
```

## Problema Conhecido: V4014 Frequentemente Vazia

### Contexto do Problema

**Descoberta Empírica** (documentada em `README_metodologia.md`):
- V4014 (área do trabalho) está **vazia em ~96.3%** dos casos na PNAD 2011
- V4033 (área similar) está vazia em ~99.9% na PNAD 2011
- Situação similar esperada no PNADC 2023

### Investigação Realizada no Projeto

Do arquivo `README_metodologia.md`:

> **2.1 Problema: Variável de Área (v9033) Majoritariamente Vazia**
>
> **Descoberta Empírica:**
> - v9033 (área do emprego: municipal/estadual/federal) está **vazia em 96.3%** dos casos
> - v9079 (área do emprego - referência anual) está **vazia em 99.9%** dos casos
>
> **Resultado da Investigação:**
> - ✓ O artigo CONFIRMA que conseguiram identificar 10.430 servidores municipais
> - ✓ Apresentam estatísticas separadas para Federal, Estadual e Municipal
> - ✗ O artigo NÃO documenta a metodologia específica (variáveis, critérios, código)

### Estratégias de Mitigação

#### Opção 1: Usar Apenas V4028 (Conservadora)
```julia
# Identifica TODOS servidores estatutários
# Não distingue municipal/estadual/federal
servidores_todos = filter(p -> !ismissing(p.servidor_estatutario) &&
                                p.servidor_estatutario == 1, pessoas)
```

**Vantagens:**
- ✓ Dados consistentes
- ✓ Amostra grande
- ✓ Variável confiável

**Desvantagens:**
- ✗ Não distingue níveis
- ✗ Mistura municipal com estadual e federal

#### Opção 2: Filtrar V4014 Não-Missing (Restritiva)
```julia
# Apenas servidores com V4014 preenchido
servidores_com_area = filter(p -> !ismissing(p.servidor_estatutario) &&
                                    p.servidor_estatutario == 1 &&
                                    !ismissing(p.area_trabalho), pessoas)

# Separar por nível
municipais = filter(p -> p.area_trabalho == 1, servidores_com_area)
estaduais = filter(p -> p.area_trabalho == 2, servidores_com_area)
federais = filter(p -> p.area_trabalho == 3, servidores_com_area)
```

**Vantagens:**
- ✓ Identifica nível específico
- ✓ Dados precisos

**Desvantagens:**
- ✗ Amostra muito pequena (~3-5% dos servidores)
- ✗ Possível viés de seleção

#### Opção 3: Análise por UF (Proxy Geográfico)
```julia
# Servidores por UF
using DataFrames
df_servidores = DataFrame(servidores_todos)

# Agrupar por UF
by_uf = combine(groupby(df_servidores, :uf),
                :peso => sum => :n_ponderado,
                nrow => :n_amostra)
```

**Vantagens:**
- ✓ Heterogeneidade regional
- ✓ Amostra completa

**Desvantagens:**
- ✗ Ainda não distingue municipal/estadual/federal dentro da UF

#### Opção 4: Integração com Dados Administrativos
```julia
# Combinar PNADC com RAIS, SIAPE, CADPREV
# (Requer acesso a dados administrativos)
```

**Vantagens:**
- ✓ Precisão máxima
- ✓ Cobertura completa

**Desvantagens:**
- ✗ Requer acesso a múltiplas fontes
- ✗ Complexidade de integração

## Estatísticas Descritivas

### Função de Análise

```julia
using Statistics

function analisar_servidores(servidores::Vector{Pessoa})
    println("="^70)
    println("ESTATÍSTICAS: SERVIDORES PÚBLICOS ESTATUTÁRIOS")
    println("="^70)

    # Total
    println("\nTotal de servidores: $(length(servidores))")
    println("População ponderada: $(round(Int, sum(p.peso for p in servidores)))")

    # Por sexo
    mulheres = filter(p -> p.sexo == 2, servidores)
    homens = filter(p -> p.sexo == 1, servidores)

    pct_mulheres = length(mulheres) / length(servidores) * 100
    println("\nSexo:")
    println("  Mulheres: $(length(mulheres)) ($(round(pct_mulheres, digits=1))%)")
    println("  Homens: $(length(homens)) ($(round(100-pct_mulheres, digits=1))%)")

    # Idade
    idades = [p.idade for p in servidores]
    println("\nIdade:")
    println("  Média: $(round(mean(idades), digits=1)) anos")
    println("  Mediana: $(round(median(idades), digits=1)) anos")
    println("  Mínimo: $(minimum(idades)) anos")
    println("  Máximo: $(maximum(idades)) anos")

    # Por nível (se disponível)
    com_area = filter(p -> !ismissing(p.area_trabalho), servidores)
    if !isempty(com_area)
        println("\nPor nível administrativo (subset com V4014 preenchido):")
        println("  Total com área identificada: $(length(com_area))")

        mun = count(p -> p.area_trabalho == 1, com_area)
        est = count(p -> p.area_trabalho == 2, com_area)
        fed = count(p -> p.area_trabalho == 3, com_area)

        println("  Municipal: $mun")
        println("  Estadual: $est")
        println("  Federal: $fed")
    else
        println("\n⚠️  V4014 (área) não disponível para nenhum servidor")
    end

    println("="^70)
end
```

## Validação e Checagem

### Verificar Consistência

```julia
# Total de pessoas
n_total = length(pessoas)

# Servidores estatutários
n_servidores = count(p -> !ismissing(p.servidor_estatutario) &&
                           p.servidor_estatutario == 1, pessoas)

pct_servidores = n_servidores / n_total * 100

println("População total: $n_total")
println("Servidores estatutários: $n_servidores ($(round(pct_servidores, digits=1))%)")
# Esperado: 10-15% da população ocupada
```

### Verificar Preenchimento de V4014

```julia
# Quantos servidores têm V4014 preenchido?
servidores = filter(p -> !ismissing(p.servidor_estatutario) &&
                          p.servidor_estatutario == 1, pessoas)

com_area = count(p -> !ismissing(p.area_trabalho), servidores)
pct_com_area = com_area / length(servidores) * 100

println("Servidores com V4014 preenchido: $com_area / $(length(servidores))")
println("Percentual: $(round(pct_com_area, digits=1))%")
# Esperado: 3-10% (baseado em experiência com PNAD 2011)
```

## Comparação com PNAD 2011

### Variáveis Equivalentes

| PNAD 2011 | PNADC 2023 | Descrição |
|-----------|------------|-----------|
| v9029 | V4028 | Servidor estatutário |
| v9033 | V4014 | Área do trabalho |
| v9079 | - | Área (referência anual) |

### Experiência do Projeto com PNAD 2011

Do arquivo `README_metodologia.md`:

> **2.2 Solução Adotada: Abordagem Conservadora**
>
> **Variável Utilizada:** `v9029 = '1'` (Funcionário público estatutário)
>
> **Justificativa:**
> 1. Identifica 96,182 servidores (26.8% da amostra PNAD)
> 2. Captura TODOS servidores públicos estatutários (municipal + estadual + federal)
> 3. Variável consistentemente preenchida
> 4. É a variável mais confiável disponível na PNAD 2011

## Recomendações

### Para Análise Geral de Servidores
✅ **Usar V4028 apenas**
- Identifica todos os servidores estatutários
- Amostra robusta e confiável
- Não distingue níveis

### Para Análise Específica por Nível
⚠️ **Usar V4014 com cautela**
- Verificar % de preenchimento primeiro
- Documentar limitação da amostra
- Considerar viés de seleção
- Validar resultados com fontes externas

### Para Pesquisa sobre Servidores Municipais Especificamente
💡 **Considerar integração com:**
- RAIS (Relação Anual de Informações Sociais)
- SIAPE (Sistema Integrado de Administração de Recursos Humanos)
- CADPREV (Cadastro Nacional de Entidades de Previdência)

## Exemplo Completo

```julia
# Ler dados
pessoas = ler_pnadc("../data_pnadc2023/PNADC_2023_visita5.txt")

# Filtrar servidores estatutários
servidores = filter(p -> !ismissing(p.servidor_estatutario) &&
                          p.servidor_estatutario == 1, pessoas)

# Análise descritiva
analisar_servidores(servidores)

# Verificar disponibilidade de V4014
println("\n" * "="^70)
println("DISPONIBILIDADE DA VARIÁVEL V4014 (Área)")
println("="^70)

com_area = filter(p -> !ismissing(p.area_trabalho), servidores)
pct = length(com_area) / length(servidores) * 100

println("Servidores com área identificada: $(length(com_area)) / $(length(servidores))")
println("Percentual: $(round(pct, digits=1))%")

if pct < 10
    println("\n⚠️  ALERTA: Menos de 10% dos servidores têm V4014 preenchido")
    println("Recomendação: Usar abordagem conservadora (V4028 apenas)")
else
    println("\n✓ V4014 parece utilizável para análise por nível")

    # Separar por nível
    municipais = filter(p -> p.area_trabalho == 1, com_area)
    estaduais = filter(p -> p.area_trabalho == 2, com_area)
    federais = filter(p -> p.area_trabalho == 3, com_area)

    println("  Municipal: $(length(municipais))")
    println("  Estadual: $(length(estaduais))")
    println("  Federal: $(length(federais))")
end
```

## Próximos Passos

Após identificar servidores:
1. **Composição familiar**: [05_family_composition.md](05_family_composition.md)
2. **Tabelas de probabilidade**: [06_probability_tables.md](06_probability_tables.md)
3. **Exemplos completos**: [09_examples.md](09_examples.md)
