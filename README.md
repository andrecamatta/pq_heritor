# Função Heritor - Cálculo Atuarial de Pensão por Morte

Modelo completo para **cálculo atuarial de pensão por morte de servidores estatutários**, utilizando dados reais da PNAD Contínua 2023 (IBGE) e tábuas de mortalidade SOA.

---

## ⚠️ IMPORTANTE: Dados Reais

Este projeto **NÃO utiliza dados sintéticos**. É obrigatório baixar os microdados oficiais:
- **PNADC 2023** (principal) - [Download via IBGE](https://www.ibge.gov.br/estatisticas/sociais/trabalho/9171-pesquisa-nacional-por-amostra-de-domicilios-continua-mensal.html)
- **PNAD 2011** (opcional, validação temporal)

**Aplicação**: Amostragem Monte Carlo para cálculo de reservas técnicas de pensão por morte.

---

## Estrutura do Projeto

```
pq_heritor/
├── src/                         # Módulos reutilizáveis
│   ├── Utils.jl                 # Funções auxiliares
│   ├── Heritor.jl               # Amostragem Monte Carlo de beneficiários
│   ├── Atuarial.jl              # Cálculo de encargo e reserva atuarial
│   ├── Credibilidade.jl         # Modelo Bühlmann-Straub
│   └── AgeGap.jl                # Análise de age gap
│
├── docs/                        # Documentação técnica
│   └── METODOLOGIA.md           # Metodologia detalhada
│
├── 00_download_pnadc2023.sh     # Script de download
├── 01-17_*.jl                   # 17 scripts de análise
├── run_pipeline.jl              # Pipeline automatizado
│
├── dados/                       # Dados brutos (não versionados)
│   ├── pnadc_2023_processado.csv
│   └── pnadc_2023_filhos.csv
│
└── resultados/                  # Saídas geradas (não versionadas)
    ├── *.csv                    # Tabelas de resultados
    └── graficos/                # Gráficos PNG
```

---

## Requisitos

- **Julia** ≥ 1.10
- **Dependências**: CSV, DataFrames, Statistics, Plots, MortalityTables

---

## Instalação

### 1. Clonar Repositório

```bash
git clone <repo-url>
cd pq_heritor
```

### 2. Ativar Ambiente

```bash
julia --project=.
```

No REPL Julia:
```julia
using Pkg
Pkg.instantiate()
```

### 3. Baixar Dados IBGE

```bash
./00_download_pnadc2023.sh
```

Ou baixe manualmente de:
- [PNADC 2023 - FTP IBGE](ftp://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_continua/Anual/Microdados/2023/)

---

## Uso

### Pipeline Completo (Recomendado)

Executa todos os 17 scripts em sequência:

```bash
julia --project=. run_pipeline.jl
```

### Execução Manual por Fase

**Fase 1: Conjugalidade** (scripts 01-04)
```bash
julia --project=. 01_processar_dados.jl
julia --project=. 02_tabua_conjugalidade.jl
julia --project=. 03_grafico_prevalencia_simples.jl
julia --project=. 04_credibilidade_servidores.jl
```

**Fase 2: Age Gap** (scripts 05-08)
```bash
julia --project=. 05_age_gap_servidores.jl
julia --project=. 06_analise_distribuicao_age_gap.jl
julia --project=. 07_samplear_age_gap.jl
julia --project=. 08_grafico_age_gap.jl
```

**Fase 3: Filhos** (scripts 09-12)
```bash
julia --project=. 09_processar_filhos.jl
julia --project=. 10_tabua_filhos.jl
julia --project=. 11_credibilidade_filhos.jl
julia --project=. 12_grafico_filhos.jl
```

**Fase 4: Heritor** (script 13)
```bash
julia --project=. 13_samplear_heritor.jl
```

**Fase 5: Encargo Atuarial** (scripts 14-15)
```bash
julia --project=. 14_calcular_encargo_tabela.jl
julia --project=. 15_grafico_encargo.jl
```

**Fase 6: Reserva Matemática** (scripts 16-17)
```bash
julia --project=. 16_calcular_reserva_pensao.jl
julia --project=. 17_grafico_reserva_pensao.jl
```

### Scripts Individuais

Consulte `run_pipeline.jl` para lista completa e ordem de execução.

---

## Arquivos Gerados

### Tabelas CSV (`resultados/`)

| Arquivo | Descrição |
|---------|-----------|
| `tabua_conjugalidade.csv` | Prevalência de casados por idade/sexo |
| `conjugalidade_credivel.csv` | Estimativas estabilizadas (usar `P_suavizado`) |
| `age_gap_observado.csv` | Age gap bruto |
| `age_gap_credivel.csv` | Age gap estabilizado |
| `tabua_filhos.csv` | Distribuição de filhos ≤24 anos |
| `filhos_credivel.csv` | Estimativas estabilizadas de filhos |
| `encargo_heritor.csv` | Encargo atuarial por idade/sexo |
| `encargo_sensibilidade_taxa.csv` | Sensibilidade à taxa de juros (4%-8%) |
| `reserva_pensao.csv` | Reserva matemática por idade/sexo |

### Gráficos PNG (`resultados/graficos/`)

9 gráficos gerados automaticamente:

**Conjugalidade e Age Gap** (4 gráficos):
- `prevalencia_masculino.png`, `prevalencia_feminino.png`
- `age_gap_masculino.png`, `age_gap_feminino.png`

**Encargo Atuarial** (5 gráficos):
- `encargo_masculino.png`, `encargo_feminino.png`
- `encargo_comparacao_sexos.png`
- `percentual_pensao.png`
- `sensibilidade_taxa_juros.png`

**Reserva Matemática** (4 gráficos):
- `reserva_total.png`
- `expectativa_vida.png`
- `prob_deixar_pensao.png`
- `reserva_vs_encargo.png`

---

## Metodologia

Este projeto utiliza **modelo de credibilidade Bühlmann-Straub** combinado com **suavização por média móvel** para estabilizar estimativas em amostras pequenas, preservando diferenças sistemáticas entre servidores públicos e população geral.

### Principais Características

- **Pesos amostrais**: Todos os cálculos respeitam o plano amostral complexo do IBGE
- **Credibilidade**: Combina dados observados com prior ajustado
- **Suavização**: 3 passadas de média móvel com janela 5 (idade ± 2)
- **Tábua de mortalidade**: AT-2012 IAM Basic (SOA)
- **Taxa de desconto**: 6% a.a.

Para detalhes técnicos completos, consulte **[`docs/METODOLOGIA.md`](docs/METODOLOGIA.md)**.

---

## Módulos Principais (`src/`)

### `Heritor.jl`
Amostragem Monte Carlo completa de beneficiários:
- Conjugalidade (casado/solteiro)
- Age gap (idade do cônjuge)
- Filhos dependentes (≤ 24 anos)

```julia
using .Heritor
amostras = samplear_caracteristicas_heritor(60, "Masculino", n_samples=10_000)
```

### `Atuarial.jl`
Cálculo de encargo e reserva atuarial:

**Encargo** (custo SE morrer em idade x):
```julia
using .Atuarial
encargo = calcular_encargo_heritor(60, "Masculino", taxa_juros=0.06)
```

**Reserva** (custo esperado para servidor vivo):
```julia
reserva = calcular_reserva_pensao(60, "Masculino", taxa_juros=0.06)
```

### `Credibilidade.jl`
Modelo Bühlmann-Straub para estabilização de estimativas.

---

## Conceitos-Chave

### Encargo Atuarial
Valor presente do custo de pensões **SE** o servidor morrer em idade x, expresso em "anos de benefício".

- **Unidade**: Anos de benefício (VP normalizado)
- **Conversão**: `Custo_R$ = Encargo × Benefício_anual`
- **Componentes**: Cônjuge (vitalício) + Filhos (até 24 anos)

### Reserva Matemática
Valor presente **esperado** do custo de pensões para servidor **VIVO** de idade x.

- **Diferença vs Encargo**: Integra probabilidade de morte em todas as idades futuras
- **Magnitude**: Reserva << Encargo (~6-8% do encargo condicional)
- **Uso**: Provisão técnica, orçamento de longo prazo

---

## Documentação Adicional

- **[`docs/METODOLOGIA.md`](docs/METODOLOGIA.md)** - Metodologia técnica detalhada
- **`DECISAO_FINAL_CONJUGALIDADE.md`** - Fundamentação de escolhas metodológicas
- **`.claude/skills/`** - Skills de documentação PNADC/PNAD

---

## Referências

1. **IBGE** - [PNAD Contínua 2023](https://www.ibge.gov.br/estatisticas/sociais/trabalho/9171-pesquisa-nacional-por-amostra-de-domicilios-continua-mensal.html)
2. **SOA** - [2012 Individual Annuity Mortality Basic Table](https://www.soa.org/)
3. **Bühlmann & Straub** (1970) - "Glaubwürdigkeit für Schadensätze"
4. **Bowers et al.** (1997) - "Actuarial Mathematics" (2nd ed.)

---

**Última atualização**: 2025-10-19
**Status**: Modelo completo (Encargo + Reserva)
**Dados**: PNADC 2023 (IBGE) + AT-2012 IAM Basic (SOA)
