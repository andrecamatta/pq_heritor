# PNAD 2011 - Estrutura dos Dados

## Organização dos Arquivos

### Arquivo Principal de Microdados

**Nome típico**: `PES2011.txt` ou `DOM2011.txt` + `PES2011.txt`

A PNAD 2011 pode ter:
- **Arquivo de domicílios** (DOM): Características do domicílio
- **Arquivo de pessoas** (PES): Características individuais

Para análise de conjugalidade, usamos principalmente o **arquivo de pessoas (PES)**.

## Estrutura de Registros

### Hierarquia dos Dados

```
UF (Unidade da Federação)
  └─ Controle (número de controle)
      └─ Série (número de série)
          └─ Ordem (número de ordem)
              └─ Domicílio
                  └─ Pessoa 1
                  └─ Pessoa 2
                  └─ ...
                  └─ Pessoa N
```

### Identificação Única

Cada pessoa é identificada pela combinação de:
- **UF**: Unidade da Federação (2 dígitos)
- **V0102**: Número de controle
- **V0103**: Número de série
- **V0300**: Número de ordem da pessoa no domicílio

**Chave única do domicílio**: `UF + V0102 + V0103`
**Chave única da pessoa**: `UF + V0102 + V0103 + V0300`

## Formato do Arquivo (FWF)

### Fixed-Width Format

Cada linha do arquivo representa **uma pessoa**.

Exemplo ilustrativo (posições aproximadas):
```
Colunas  Variável   Descrição
1-2      UF         Unidade da Federação
3-6      V0102      Número de controle
7-9      V0103      Número de série
10-11    V0300      Número de ordem
12-13    V0401      Condição no domicílio
14       V0302      Sexo
15-17    V8005      Idade
...
```

⚠️ **NOTA**: Posições exatas devem ser verificadas no dicionário oficial da PNAD 2011.

## Variáveis por Bloco Temático

### Bloco 1: Identificação

| Variável | Descrição | Tipo |
|----------|-----------|------|
| UF | Unidade da Federação | Numérico (2) |
| V0102 | Número de controle | Numérico |
| V0103 | Número de série | Numérico |
| V0300 | Número de ordem | Numérico (2) |
| V0301 | Número de pessoas no domicílio | Numérico (2) |

### Bloco 2: Características Demográficas

| Variável | Descrição | Códigos |
|----------|-----------|---------|
| **V0302** | Sexo | 2 = Masculino<br>4 = Feminino |
| **V8005** | Idade em anos | 000-999 |
| V0303 | Raça/Cor | 2=Branca, 4=Preta, 6=Amarela, 8=Parda, 0=Indígena |
| **V0401** | Condição no domicílio | Ver seção abaixo |

### Bloco 3: Condição no Domicílio (V0401)

⚠️ **Crítico para identificar cônjuges**

Códigos (verificar dicionário oficial):
- **01**: Pessoa de referência (chefe)
- **02**: Cônjuge/companheiro(a)
- **03**: Filho(a)
- **04**: Outro parente
- **05**: Agregado
- **06**: Pensionista
- **07**: Empregado doméstico
- **08**: Parente do empregado doméstico

**Para conjugalidade**: V0401 = **02** indica cônjuge.

### Bloco 4: Trabalho e Ocupação

| Variável | Descrição | Uso |
|----------|-----------|-----|
| V4706 | Posição na ocupação | Identificar servidor público |
| V4805 | Código da ocupação | CBO-Domiciliar |
| V4706 | Grupamento de atividade | Setor econômico |

**Posição na ocupação (V4706)** - verificar códigos:
- **05**: Servidor público estatutário (provável)
- Outros códigos para empregado setor privado, conta própria, etc.

### Bloco 5: Pesos Amostrais

| Variável | Descrição | Uso Recomendado |
|----------|-----------|-----------------|
| **V4729** | Peso da pessoa | **Usar este para análise de conjugalidade** |
| V4619 | Peso do domicílio | Usar para análise domiciliar |

## Estrutura para Análise de Conjugalidade

### Dados Necessários por Pessoa

```julia
struct PessoaPNAD2011
    uf::Int
    controle::Int
    serie::Int
    ordem::Int
    sexo::Int              # V0302
    idade::Int             # V8005
    condicao_dom::Int      # V0401
    posicao_ocup::Int      # V4706
    peso::Float64          # V4729
end
```

### Identificação de Casais no Domicílio

Para cada domicílio:
1. Identificar **pessoa de referência** (V0401 = 01)
2. Identificar **cônjuge** (V0401 = 02)
3. Calcular diferença de idade (age gap)

```julia
# Pseudocódigo
for domicilio in domicilios
    chefe = filter(p -> p.condicao_dom == 01, domicilio.pessoas)[1]
    conjuge = filter(p -> p.condicao_dom == 02, domicilio.pessoas)

    if length(conjuge) > 0
        conjuge = conjuge[1]
        age_gap = chefe.idade - conjuge.idade
    end
end
```

## Filtragem e Limpeza

### Filtros Recomendados

1. **Idade válida**: 15 ≤ idade ≤ 90
2. **Pesos válidos**: peso > 0
3. **Condição no domicílio**: valores válidos (01-08)

### Casos Especiais

1. **Domicílios unipessoais**: V0301 = 01 (uma pessoa)
2. **Múltiplos cônjuges**: Em teoria não deveria ocorrer, mas verificar dados
3. **Missing values**: Verificar como estão codificados (geralmente 9, 99, 999)

## Comparação com PNADC 2023

| Aspecto | PNAD 2011 | PNADC 2023 |
|---------|-----------|------------|
| **Arquivo** | PES2011.txt | PNADC_XXXXX_visita1.txt |
| **Chave domicílio** | UF+V0102+V0103 | UF+UPA+V1008+V1014 |
| **Pessoas/linha** | 1 pessoa = 1 linha | 1 pessoa = 1 linha |
| **Visitas** | Única (anual) | 4 visitas trimestrais |
| **Zona rural Norte** | ❌ Não inclui | ✅ Inclui |

## Tamanho Esperado dos Dados

### PNAD 2011
- **Domicílios**: ~150.000
- **Pessoas**: ~350.000
- **Tamanho do arquivo**: ~100-150 MB (FWF descompactado)

### Memória Necessária
- Julia DataFrame: ~500 MB - 1 GB de RAM
- Processamento: Recomendar 4 GB+ disponíveis

## Exemplo de Leitura (Pseudocódigo)

```julia
# Layout FWF (posições ilustrativas)
layout = Dict(
    :UF => (1:2),
    :V0102 => (3:6),
    :V0103 => (7:9),
    :V0300 => (10:11),
    :V0301 => (12:13),
    :V0401 => (14:15),
    :V0302 => (16:16),
    :V8005 => (17:19),
    :V4706 => (50:51),
    :V4729 => (100:113)  # 14 dígitos com decimais
)

# Ler arquivo
df = read_fwf("PES2011.txt", layout)

# Filtrar e processar
df = filter(row -> 15 <= row.V8005 <= 90, df)  # Idade válida
df = filter(row -> row.V4729 > 0, df)          # Peso válido
```

## Referências

- IBGE (2012). *Dicionário de variáveis da PNAD 2011*.
- IBGE (2012). *Layout de microdados da PNAD 2011*.

---

**Última atualização**: 2025-10-17
**Status**: ⚠️ Placeholders - Verificar posições exatas no dicionário oficial
