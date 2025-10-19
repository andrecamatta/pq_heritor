# Metodologia Técnica - Função Heritor

Documentação técnica detalhada do modelo atuarial de pensão por morte.

## Sumário

1. [Modelo de Credibilidade](#modelo-de-credibilidade)
2. [Pesos Amostrais](#pesos-amostrais)
3. [Identificação de Cônjuge](#identificação-de-cônjuge)
4. [Servidor Público](#servidor-público)
5. [Age Gap](#age-gap)
6. [Filhos Dependentes](#filhos-dependentes)
7. [Distribuições Paramétricas para Simulação Monte Carlo](#distribuições-paramétricas-para-simulação-monte-carlo)
8. [Encargo Atuarial](#encargo-atuarial)
9. [Reserva Matemática](#reserva-matemática)
10. [Variáveis do IBGE](#variáveis-do-ibge)

---

## Modelo de Credibilidade

### Bühlmann-Straub + Média Móvel

**Problema**: Servidores têm amostras pequenas em algumas idades → estimativas voláteis (ex: 100% ou 0%).

**Solução**: Combinar dados de servidores com população geral (estável) preservando diferença sistemática, seguido de suavização via média móvel ponderada.

**Fundamentação**: Método atuarial reconhecido desde 1904 (Fórmula de Spencer). Ver `DECISAO_FINAL_CONJUGALIDADE.md` para detalhes sobre métodos alternativos testados (GLM, Splines) e por que foram rejeitados.

### Método (2 Etapas)

**Etapa 1: Credibilidade Bühlmann-Straub**

1. **Estimar shift sistemático Δ** (por sexo):
   ```
   Δ = média(P_serv - P_geral) onde n_serv ≥ 30
   ```
   - Masculino: Δ = +1.55%
   - Feminino: Δ = -0.64%

2. **Ajustar população geral**:
   ```
   P_geral_ajustado = P_geral + Δ
   ```

3. **Aplicar credibilidade**:
   ```
   Z[idade] = n_serv / (n_serv + k)
   k = √(média(n_serv))

   P_credível = Z × P_serv_obs + (1-Z) × P_geral_ajustado
   ```

**Etapa 2: Média Móvel Ponderada**

4. **Suavizar com média móvel** (remove oscilações):
   ```
   janela = 5          # vizinhos: idade ± 2
   peso_prior = 0.3    # 30% ancoragem na pop geral
   n_iteracoes = 3     # 3 passadas de suavização

   Para cada idade:
     - Média ponderada dos vizinhos (pesos triangulares)
     - Combinar com pop geral (30%)
     - Repetir 3 vezes
   ```

### Interpretação de Z

- **n pequeno** → Z baixo → usa mais P_geral_ajustado (estável)
- **n grande** → Z alto → usa mais P_serv_obs (específico)
- Jovens/idosos: Z ≈ 0.3 (usa 70% referência)
- Adultos: Z ≈ 0.9 (usa 90% observado)

**Resultado**: Estimativas estáveis, suaves e não enviesadas para uso atuarial.

### Implementação

- **Arquivo**: `08_credibilidade_servidores.jl`
- **Resultado**: `resultados/conjugalidade_credivel.csv`
- **Coluna usar**: `P_suavizado`

### Métodos Alternativos Testados

Ver `_old/` para detalhes:

- ❌ **GLM Polinômios**: Sobe nas extremidades (idades 85-90)
- ❌ **Natural Splines**: Serrilhamento com dados ruidosos

---

## Pesos Amostrais

**Todos os cálculos usam pesos amostrais** para garantir representatividade populacional:

- **PNADC 2023**: V1032
- **PNAD 2011**: V4729

### Exemplo Correto

```julia
# CORRETO (com pesos):
prop = sum(peso[casados]) / sum(peso[total])

# ERRADO (sem pesos):
prop = count(casados) / count(total)  # NÃO USAR!
```

**Justificativa**: Plano amostral complexo do IBGE requer ponderação para inferência populacional.

---

## Identificação de Cônjuge

### PNADC 2023

Variável: **V2005** (Condição no domicílio)

- `01` = Pessoa de referência (chefe)
- `02` = Cônjuge de sexo diferente
- `03` = Cônjuge de mesmo sexo

**Regra**: Uma pessoa tem cônjuge se existe `V2005 ∈ {02, 03}` no mesmo domicílio (UPA + V1008 + V1014).

### Implementação

Ver `src/Utils.jl` - função `criar_tabua_conjugalidade()`

---

## Servidor Público

### Critério de Identificação

**PNADC 2023**: `V4028 = 5`
- Trabalhador do setor público - estatutário (excluindo militares, celetistas)

**PNAD 2011**: Verificar dicionário oficial do IBGE

### População de Interesse

Apenas servidores públicos estatutários civis.

---

## Age Gap

### Definição

Para cada par (pessoa de referência + cônjuge):

```
age_gap = idade_referência - idade_cônjuge
```

- **Positivo**: referência mais velha que cônjuge
- **Negativo**: cônjuge mais velho que referência
- **Zero**: mesma idade

### Análise

- Calcula age gap médio ponderado por idade e sexo da **pessoa de referência**
- Compara população geral vs servidores
- Aplica **mesmo modelo de credibilidade Bühlmann-Straub**

### Aplicação para Função Heritor

Amostragem Monte Carlo da idade do cônjuge beneficiário:

```
age_gap ~ μ(idade, sexo) + σ(idade, sexo) × T(df=5)
idade_cônjuge = idade_servidor - age_gap
```

Onde:
- `μ, σ`: parâmetros suavizados (credibilidade Bühlmann-Straub)
- `T(df=5)`: distribuição t-Student com 5 graus de liberdade
- Truncamento final: [15, 100] anos

**Exemplo Monte Carlo** (servidor homem, 60 anos):
- Parâmetros: μ ≈ 4.8 anos, σ ≈ 8.5 anos
- Simulando 10.000 cenários:
  - **P50** (mediana): ~55 anos
  - **P10-P90**: 46-64 anos
  - Variância captura incerteza demográfica
- Resultado: distribuição de encargos (não valor único)

---

## Filhos Dependentes

### Critério de Elegibilidade

Filho é dependente para pensão se:
- Idade ≤ 24 anos (critério legal comum)
- Reside no mesmo domicílio

### Variáveis Analisadas

Por idade e sexo do responsável:
1. **P(ter ≥1 filho)**: Probabilidade de ter ao menos um filho dependente
2. **E[n_filhos | n>0]**: Número esperado de filhos (condicional)
3. **E[idade_filho_mais_novo | n>0]**: Idade esperada do mais novo
4. **SD[idade_filho]**: Desvio padrão da idade

### Implementação

- Scripts: `09_processar_filhos.jl`, `10_tabua_filhos.jl`, `11_credibilidade_filhos.jl`
- Resultado: `resultados/filhos_credivel.csv`

---

## Distribuições Paramétricas para Simulação Monte Carlo

Após obter parâmetros suavizados (μ, σ) via credibilidade Bühlmann-Straub, usamos distribuições paramétricas para amostrar características de beneficiários em simulações atuariais.

### Age Gap (Idade do Cônjuge)

**Distribuição**: t-Student com 5 graus de liberdade

```
age_gap ~ μ + σ × T(df=5)
idade_cônjuge = idade_servidor - age_gap
```

**Fundamentação**:
- Análise exploratória (`06_analise_distribuicao_age_gap.jl`) mostrou:
  - **Curtose alta** (2-7): Caudas mais pesadas que Normal (curtose ≈ 0)
  - **Testes de normalidade**: Maioria rejeita hipótese nula (Anderson-Darling p < 0.05)
  - **Casais extremos**: Diferenças ±20-30 anos mais frequentes que Normal preveria

**Truncamento**: [15, 100] anos para idade final do cônjuge
- Remove caudas absurdas (bebês, 120+ anos)
- Afeta < 0.5% das amostras
- Preserva caudas pesadas dentro de limites biológicos

**Comparação com Normal**:

| Característica | Normal | t-Student(df=5) |
|----------------|--------|-----------------|
| Caudas | Leves (exponenciais) | Pesadas (polinomiais) |
| Curtose | 0 | 6 |
| P(\|X\| > 3σ) | ~0.3% | ~1-2% |

### Idade dos Filhos

**Distribuição**: Normal

```
idade_filho ~ Normal(μ, σ)
```

**Truncamento**: [0, 24] anos
- Garante elegibilidade legal para pensão
- Remove valores impossíveis (negativos, adultos)

### Outras Variáveis

**Bernoulli** (casado, tem_filho):
```
casado ~ Bernoulli(P_suavizado)
tem_filho ~ Bernoulli(prev_filho_suavizado)
```

**Poisson condicional** (n_filhos | tem_filho):
```
n_filhos ~ Poisson(λ) com λ = n_filhos_medio / P_filho
n_filhos ≥ 1  (condicional)
```

### Implementação

- **Módulo**: `src/Heritor.jl` - função `samplear_caracteristicas_heritor()`
- **Script age gap**: `07_samplear_age_gap.jl`
- **Análise**: `resultados/age_gap_diagnostico.txt`

### Referências

- Anderson-Darling: Stephens (1974). "EDF Statistics for Goodness of Fit"
- t-Student para caudas pesadas: Fama (1965). "Portfolio Analysis in a Stable Paretian Market"

---

## Encargo Atuarial

### Definição

**Encargo** = Valor presente do custo total de pensões, expresso em "anos de benefício".

### Cálculo

Para servidor que morre em idade `x`:

```
Encargo(x, sexo) = E[VP_pensões]

Onde VP_pensões depende de:
1. Cônjuge (se casado):
   - Anuidade vitalícia: ä_y (y = idade cônjuge)
   - % Pensão: 50% + 10% × n_dependentes (max 100%)

2. Filhos (≤ 24 anos):
   - Anuidade temporária: ä_z:n (z = idade filho, n = anos até 24)
   - % Pensão: mesmo rateio
```

### Componentes Técnicos

**Anuidade vitalícia** (cônjuge):
```
ä_y = Σ v^t × t_p_y    (t=0 até ω-y)
```

**Anuidade temporária** (filho):
```
ä_z:n = Σ v^t × t_p_z  (t=0 até min(n, ω-z))
```

Onde:
- `v = 1/(1+i)` = fator de desconto (i = 6% a.a.)
- `t_p_x` = probabilidade de sobreviver t anos (tábua AT-2012 IAM Basic)
- `ω` = idade máxima da tábua

### Tábua de Mortalidade

**AT-2012 IAM Basic** (SOA - Society of Actuaries):
- Masculino: TableID 2585
- Feminino: TableID 2582

**Fonte**: MortalityTables.jl (oficial)

### Unidade "Anos de Benefício"

**Interpretação**: Encargo de 9.8 anos significa que o custo das pensões equivale a 9.8 anos de pagamento integral do benefício (a valor presente).

**Conversão para R$**:
```
Custo_R$ = Encargo (anos) × Benefício_anual (R$/ano)
```

### Implementação

- Módulo: `src/Atuarial.jl`
- Função: `calcular_encargo_heritor(idade, sexo)`
- Script tabela: `14_calcular_encargo_tabela.jl`

---

## Reserva Matemática

### Definição

**Reserva** = Valor presente esperado do custo de pensões para servidor **VIVO** de idade x.

### Diferença vs Encargo

| Métrica | Encargo Heritor | Reserva Matemática |
|---------|-----------------|-------------------|
| Condição | **SE** morrer em idade x | **DADO QUE** está vivo em x |
| Tipo | Condicional | Incondicional (esperado) |
| Magnitude | Alto (~5-10 anos) | Baixo (~0.2-0.8 anos) |
| Uso | Análise de risco | Provisão técnica |

### Fórmula Atuarial

```
Reserva(x, sexo) = Σ_{t=0}^{ω-x} v^t × t_p_x × q_{x+t} × Heritor(x+t, sexo)
```

Onde:
- `v^t` = fator de desconto
- `t_p_x` = prob. sobreviver de x até x+t
- `q_{x+t}` = prob. morrer em idade x+t
- `Heritor(x+t)` = encargo se morrer em x+t (pré-calculado)

### Interpretação

A reserva integra o encargo condicional (por idade de morte) ponderado pelas probabilidades de:
1. Sobreviver até aquela idade
2. Morrer naquela idade

**Por que Reserva << Encargo?**

1. Probabilidade de morte diluída ao longo de muitos anos
2. Desconto temporal reduz contribuições distantes
3. Encargo decresce com idade (filhos crescem)

### Implementação

- Módulo: `src/Atuarial.jl`
- Função: `calcular_reserva_pensao(idade, sexo)`
- Script: `16_calcular_reserva_pensao.jl`

---

## Variáveis do IBGE

### PNADC 2023

| Variável | Descrição |
|----------|-----------|
| **V2007** | Sexo (1=Masculino, 2=Feminino) |
| **V2009** | Idade (anos completos) |
| **V2005** | Condição no domicílio (02/03 = cônjuge) |
| **V4028** | Posição na ocupação (5 = servidor estatutário) |
| **V1032** | Peso amostral |
| **V1008** | Número do domicílio |
| **V1014** | Número da entrevista (pessoa) |

### PNAD 2011

| Variável | Descrição |
|----------|-----------|
| **V0302** | Sexo (2=Masculino, 4=Feminino) ⚠️ **DIFERENTE!** |
| **V8005** | Idade (anos completos) |
| **V0401** | Condição no domicílio (02 = cônjuge) |
| **V4706** | Posição na ocupação (verificar dicionário) |
| **V4729** | Peso amostral |

⚠️ **ATENÇÃO**: Códigos de sexo são **DIFERENTES** entre PNAD 2011 e PNADC 2023!

---

## Referências Técnicas

1. **Bühlmann, H. & Straub, E.** (1970). "Glaubwürdigkeit für Schadensätze". Mitteilungen der Vereinigung Schweizerischer Versicherungsmathematiker.

2. **Spencer, J.** (1904). "On the Graduation of Rates of Sickness and Mortality". Institute of Actuaries.

3. **SOA** (Society of Actuaries). (2012). "2012 Individual Annuity Mortality Basic Table".

4. **IBGE**. Pesquisa Nacional por Amostra de Domicílios Contínua - PNADC 2023.

5. **Fórmulas atuariais**: Bowers et al. (1997). "Actuarial Mathematics" (2nd ed.).

---

**Última atualização**: 2025-10-19
