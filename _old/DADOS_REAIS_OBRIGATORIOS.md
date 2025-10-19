# ⚠️ DADOS REAIS SÃO OBRIGATÓRIOS

## Este Projeto NÃO Usa Dados Sintéticos

Todos os scripts deste projeto foram configurados para **EXIGIR dados reais** do IBGE. Não há fallback para dados sintéticos.

## Como Obter os Dados

### PNADC 2023 (Obrigatório)

```bash
./00_download_pnadc2023.sh
```

Ou baixe manualmente:
- URL: https://www.ibge.gov.br/estatisticas/sociais/trabalho/9171-pesquisa-nacional-por-amostra-de-domicilios-continua-mensal.html
- Colocar em: `dados/PNADC_2023_visita1.txt`

### PNAD 2011 (Para Análise Temporal)

```bash
./01_baixar_pnad2011.sh
```

Ou baixe manualmente:
- URL: https://www.ibge.gov.br/estatisticas/sociais/trabalho/9127-pesquisa-nacional-por-amostra-de-domicilios.html
- Colocar em: `dados/PES2011.txt`

## O Que Acontece Sem Dados Reais

Se você tentar executar os scripts sem dados reais, verá:

```
ERRO: Nenhum arquivo de dados encontrado!

Para usar dados reais da PNADC 2023:
  1. Execute: ./00_download_pnadc2023.sh
  2. Ou forneça arquivo CSV em: dados/PNADC_2023.csv

O arquivo deve conter as seguintes colunas:
  - V2007: Sexo (1=Masculino, 2=Feminino)
  - V2009: Idade (anos completos)
  - V2005: Condição no domicílio (02 ou 03 = cônjuge)
  - V4028: Posição na ocupação (5 = servidor público)
  - V1032: Peso amostral
```

E o script será **interrompido com exit(1)**.

## Por Que Apenas Dados Reais?

1. **Rigor Acadêmico**: Análises atuariais exigem dados reais
2. **Pesos Amostrais**: Essenciais para estimativas populacionais corretas
3. **Confiabilidade**: Dados sintéticos não representam a realidade brasileira
4. **Aplicação Real**: Este projeto é para cálculos de pensão (função heritor)

## Arquivos Modificados

Os seguintes arquivos foram ajustados para **remover** dados sintéticos:

1. **`01_processar_dados.jl`**:
   - Removida toda geração sintética
   - Agora exige dados reais ou `exit(1)`

2. **`03_tabua_age_gap.jl`**:
   - Removida simulação de estrutura domiciliar
   - Usa apenas estrutura real da PNADC (V2005)

3. **README.md**:
   - Alertas claros sobre obrigatoriedade de dados reais
   - Instruções de download destacadas

## Variáveis Essenciais nos Dados Reais

### PNADC 2023

| Variável | Uso | Crítico? |
|----------|-----|----------|
| **V1032** | Peso amostral | ✅ SIM |
| **V2007** | Sexo | ✅ SIM |
| **V2009** | Idade | ✅ SIM |
| **V2005** | Condição no domicílio (cônjuge) | ✅ SIM |
| **V4028** | Servidor público | ✅ SIM |
| **UF** | Unidade da Federação | ⚠️ Para age gap |
| **V1008** | Número do domicílio | ⚠️ Para age gap |

### PNAD 2011

| Variável | Uso | Crítico? |
|----------|-----|----------|
| **V4729** | Peso amostral | ✅ SIM |
| **V0302** | Sexo (2/4, não 1/2!) | ✅ SIM |
| **V8005** | Idade | ✅ SIM |
| **V0401** | Condição no domicílio (cônjuge) | ✅ SIM |
| **V4706** | Servidor público (código a verificar) | ✅ SIM |
| **UF** | Unidade da Federação | ⚠️ Para age gap |
| **V0102/V0103** | Identificação do domicílio | ⚠️ Para age gap |

## Verificação Rápida

Para verificar se seus dados têm as variáveis corretas:

```bash
# PNADC 2023 (após processar)
julia -e 'using CSV, DataFrames; df = CSV.read("dados/pnadc_2023_processado.csv", DataFrame); println(names(df))'

# Deve mostrar: sexo, idade, peso, servidor, casado, etc.
```

## Suporte

Se tiver problemas para obter os dados:

1. Consulte `.claude/skills/pnadc2023/01_data_structure.md`
2. Consulte `.claude/skills/pnad2011/02_reading_data.md`
3. Verifique o dicionário de variáveis do IBGE

---

**Mensagem**: Este projeto é sério e destinado a uso atuarial real. Dados sintéticos foram completamente removidos.
