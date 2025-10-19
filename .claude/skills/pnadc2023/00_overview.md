# PNADC 2023 - Visão Geral

## Sobre este Diretório de Skills

Este conjunto de skills ensina como trabalhar com os microdados da **PNAD Contínua 2023 Anual (Visita 5)** para análises demográficas, com foco em:
- População geral do Brasil
- Servidores públicos (federal, estadual, municipal)
- Composição familiar (cônjuge, filhos, idades)
- Tabelas de probabilidade segregadas por idade e sexo
- Integração com modelos demográficos

## Índice de Skills

### 📥 Dados e Parsing
- **[01_data_source.md](01_data_source.md)** - Como baixar os dados do IBGE
- **[02_parsing.md](02_parsing.md)** - Como parsear o arquivo Fixed-Width Format
- **[03_variables_dictionary.md](03_variables_dictionary.md)** - Dicionário completo de variáveis

### 👥 Identificação de Populações
- **[04_identify_servants.md](04_identify_servants.md)** - Como identificar servidores públicos por nível

### 👨‍👩‍👧‍👦 Análise Familiar
- **[05_family_composition.md](05_family_composition.md)** - Análise completa de composição familiar
- **[07_age_gap_analysis.md](07_age_gap_analysis.md)** - Diferença de idade entre cônjuges

### 📊 Tabelas e Modelos
- **[06_probability_tables.md](06_probability_tables.md)** - Metodologia para tabelas de probabilidade
- **[08_integration_models.md](08_integration_models.md)** - Integração com modelos demográficos existentes

### 💡 Prática
- **[09_examples.md](09_examples.md)** - Exemplos completos de código Julia

## Fluxo de Trabalho Típico

### 1. Primeira vez: Baixar dados
```bash
cd conjugality  # ou onde o script está
./00_download_pnadc2023.sh
```
Consulte: [01_data_source.md](01_data_source.md)

### 2. Parsear e filtrar população
```julia
# Ler dados brutos
pessoas = ler_pnadc("../data_pnadc2023/PNADC_2023_visita5.txt")

# Filtrar servidores
servidores = filter(p -> p.servidor_estatutario == 1, pessoas)
```
Consulte: [02_parsing.md](02_parsing.md) e [04_identify_servants.md](04_identify_servants.md)

### 3. Analisar composição familiar
```julia
# Identificar cônjuges
casais = identificar_casais(pessoas)

# Identificar filhos
familias = identificar_filhos(pessoas)
```
Consulte: [05_family_composition.md](05_family_composition.md)

### 4. Gerar tabelas de probabilidade
```julia
# Conjugalidade por idade e sexo
prob_conjugal = calcular_conjugalidade(pessoas)

# Age gap
age_gaps = calcular_age_gap(casais)
```
Consulte: [06_probability_tables.md](06_probability_tables.md)

### 5. Integrar com modelos existentes
```julia
# Usar modelos do projeto
include("age_gap/age_gap_model.jl")
mu_gap(40, sex=:M)
```
Consulte: [08_integration_models.md](08_integration_models.md)

## Quando Usar Cada Skill

| Tarefa | Skill Recomendada |
|--------|-------------------|
| Baixar dados pela primeira vez | 01_data_source |
| Entender estrutura do arquivo | 02_parsing, 03_variables_dictionary |
| Identificar servidores municipais | 04_identify_servants |
| Ver quem tem cônjuge por idade | 05_family_composition, 06_probability_tables |
| Calcular diferença de idade entre casais | 07_age_gap_analysis |
| Ver probabilidade de ter filhos | 05_family_composition, 06_probability_tables |
| Idade do filho mais novo | 05_family_composition |
| Comparar com modelos PNAD 2011 | 08_integration_models |
| Ver exemplo completo funcionando | 09_examples |

## Convenções Usadas

### Nomenclatura de Variáveis
- **V2007**: Sexo (1=Homem, 2=Mulher)
- **V2009**: Idade em anos completos
- **V2005**: Condição no domicílio
- **V4028**: Servidor público estatutário
- **V4014**: Área do trabalho (federal/estadual/municipal)
- **V1032**: Peso amostral COM calibração (Censo 2022)

### Códigos Importantes
- **Servidor**: V4028 = '1'
- **Cônjuge**: V2005 = '02'
- **Filho**: V2005 = '03'
- **Federal**: V4014 = '3'
- **Estadual**: V4014 = '2'
- **Municipal**: V4014 = '1'

## Limitações Conhecidas

⚠️ **Identificação de servidores municipais**
- V4014 (área do trabalho) pode ter dados esparsos
- Ver discussão completa em [04_identify_servants.md](04_identify_servants.md)

⚠️ **Comparabilidade PNAD 2011 vs PNADC 2023**
- São pesquisas diferentes
- Ver análise em `conjugality/RELATORIO_PNADC2023.md`

⚠️ **Identificação de filhos**
- V2005 agrupa filho + enteado
- Não distingue filho biológico de enteado

## Arquivos de Referência no Projeto

### Scripts Funcionais
- `conjugality/01_pnadc2023_empirical_conjugality.jl` - Parser completo
- `conjugality/03_age_gap_pnadc2023.jl` - Age gap
- `conjugality/00_download_pnadc2023.sh` - Download

### Modelos Demográficos
- `age_gap/age_gap_model.jl` - Modelo de diferença de idade
- `at_least_one_child/at_least_one_child_model.jl` - Probabilidade de filho
- `youngest_child/youngest_child_age_model.jl` - Idade do filho mais novo

### Documentação
- `conjugality/RELATORIO_PNADC2023.md` - Análise 2011 vs 2023
- `README_metodologia.md` - Metodologia do projeto

## Suporte

Para dúvidas ou problemas:
1. Consulte o skill específico no índice acima
2. Veja exemplos em [09_examples.md](09_examples.md)
3. Consulte scripts de referência no projeto
4. Verifique documentação IBGE no FTP
