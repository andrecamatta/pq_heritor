# PNAD 2011 - Overview

## O que é a PNAD 2011?

A **Pesquisa Nacional por Amostra de Domicílios (PNAD) 2011** é a última edição da PNAD tradicional (anual) antes da transição para a **PNAD Contínua** (iniciada em 2012). É fundamental para análise temporal ao comparar com PNADC 2023.

### Características Principais

- **Ano de referência**: 2011 (última semana de setembro)
- **Abrangência**: Todo o território nacional
- **Tipo**: Pesquisa amostral domiciliar
- **Periodicidade**: Anual (descontinuada após 2015)
- **Sucessora**: PNAD Contínua (2012-presente)

## Por que usar PNAD 2011?

### Para Análise Atuarial de Conjugalidade

1. **Tendência Temporal (2011-2023)**
   - 12 anos de diferença permitem análise de mudanças no padrão de conjugalidade
   - Essencial para projeções futuras (2024-2040+)
   - Captura efeitos de mudanças sociais e econômicas

2. **Validação de Modelos**
   - Permite testar estabilidade dos diferenciais entre servidores públicos e população geral
   - Identifica se padrões são consistentes ao longo do tempo

3. **Projeções Mais Robustas**
   - Métodos atuariais exigem séries históricas
   - Extrapolação baseada em dois pontos temporais é mais confiável que ponto único

## Diferenças Importantes vs PNADC 2023

### 1. Estrutura dos Dados

| Aspecto | PNAD 2011 | PNADC 2023 |
|---------|-----------|------------|
| **Formato** | Arquivo de largura fixa (FWF) | Arquivo de largura fixa (FWF) |
| **Trimestre** | Anual (setembro) | Trimestral (4 visitas) |
| **Organização** | Por domicílio e pessoa | Por domicílio, pessoa e visita |
| **Abrangência** | Exceto zona rural da Região Norte | Todo o território nacional |

### 2. Variáveis (Nomes Diferentes!)

⚠️ **ATENÇÃO**: Os códigos das variáveis mudaram entre PNAD 2011 e PNADC 2023.

**Variáveis Críticas para Conjugalidade**:

| Conceito | PNAD 2011 | PNADC 2023 |
|----------|-----------|------------|
| Sexo | **V0302** | V2007 |
| Idade | **V8005** | V2009 |
| Condição no domicílio | **V0401** | V2005 |
| Peso amostral | **V4729** ou **V4619** | V1032 |
| Ocupação | **V4805** | V4028 |
| Posição na ocupação | **V4706** | V4009 |

**Importante**: Os códigos de condição no domicílio também podem diferir. Verificar se:
- PNAD 2011: V0401 = 02 (cônjuge) ou outro código?
- PNADC 2023: V2005 = 02 (cônjuge sexo diferente) ou 03 (cônjuge mesmo sexo)

### 3. Identificação de Servidor Público

**PNAD 2011**:
- Variável: **V4706** (Posição na ocupação)
- Código servidor público estatutário: verificar dicionário (provavelmente 05)

**PNADC 2023**:
- Variável: **V4028** (Posição na ocupação no trabalho principal - grupamento)
- Código: 5 = Trabalhador do setor público (exceto militar)
- Ou usar **V4009** (Posição na ocupação detalhada)

### 4. Pesos Amostrais

**PNAD 2011**:
- **V4729**: Peso da pessoa (provavelmente o mais adequado)
- **V4619**: Peso do domicílio
- Verificar documentação para confirmar qual usar

**PNADC 2023**:
- **V1032**: Peso do trimestre da pessoa (com calibração e pós-estratificação)

## Estrutura do Arquivo FWF

A PNAD 2011 usa formato de **largura fixa** (Fixed-Width Format):
- Cada linha representa uma pessoa
- Variáveis estão em posições fixas (colunas) específicas
- É necessário o **dicionário de variáveis** para extrair os dados

### Como Ler

```julia
# Exemplo (posições ilustrativas - verificar dicionário oficial!)
layout = Dict(
    :UF => (1:2),              # UF
    :V0302 => (3:3),           # Sexo
    :V8005 => (4:6),           # Idade
    :V0401 => (7:8),           # Condição no domicílio
    :V4706 => (9:9),           # Posição na ocupação
    :V4729 => (10:23)          # Peso da pessoa
)
```

## Fontes de Dados

### Download dos Microdados

1. **Site oficial do IBGE**:
   - [https://www.ibge.gov.br/estatisticas/sociais/trabalho/9127-pesquisa-nacional-por-amostra-de-domicilios.html](https://www.ibge.gov.br/estatisticas/sociais/trabalho/9127-pesquisa-nacional-por-amostra-de-domicilios.html)

2. **FTP do IBGE** (microdados históricos):
   - [ftp://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_anual/microdados/2011/](ftp://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_anual/microdados/2011/)

3. **Arquivos necessários**:
   - Microdados (arquivo .zip)
   - Dicionário de variáveis (layout FWF)
   - Documentação da pesquisa

## Próximos Passos na Skill

Os arquivos seguintes desta skill documentam:

1. `01_data_structure.md` - Estrutura detalhada dos arquivos
2. `02_reading_data.md` - Como ler arquivos FWF da PNAD 2011
3. `03_variables_dictionary.md` - Dicionário completo de variáveis (quando disponível)
4. `04_household_spouse_identification.md` - Identificação de cônjuges
5. `05_public_servants.md` - Identificação de servidores públicos
6. `06_probability_tables.md` - Cálculo de tábuas de conjugalidade
7. `07_differences_pnadc2023.md` - Comparação detalhada PNAD 2011 vs PNADC 2023
8. `08_harmonization.md` - Como harmonizar variáveis entre 2011 e 2023

## Limitações Conhecidas

1. **Zona Rural da Região Norte**: PNAD 2011 **não inclui** zona rural da Região Norte (PNADC 2023 inclui)
2. **Sem informação de união formal vs informal**: Ambas pesquisas identificam cônjuge, mas não separam casamento civil vs união estável
3. **Sem idade ao casar**: Nem PNAD 2011 nem PNADC 2023 têm idade ao primeiro casamento
4. **Sem duração da união**: Não há informação de tempo de união

## Referências

- IBGE (2012). *Pesquisa Nacional por Amostra de Domicílios 2011 - Microdados*. Rio de Janeiro: IBGE.
- IBGE. *Notas metodológicas da PNAD 2011*.
- IBGE. *Dicionário de variáveis da PNAD 2011*.

---

**Última atualização**: 2025-10-17
**Status**: ⚠️ Placeholders - Aguardando download de microdados e dicionário oficial para validação
