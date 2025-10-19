# Metodologia da Tábua de Coorte Sintética

## Objetivo

Converter **prevalências observadas** (dados transversais) em **probabilidades de transição** (tábua de coorte sintética) para modelar dinâmica de conjugalidade.

**Aplicação**: Cálculos atuariais de pensão heritor - estimar probabilidade de servidor ter cônjuge em diferentes idades.

## Contexto

### O Problema

Dados da PNADC 2023 fornecem **proporções de casados por idade** (prevalência):
- Masculino 35 anos: 60% casados
- Masculino 36 anos: 62% casados

**Questão**: Como converter isso em:
- **Probabilidade** de um solteiro de 35 anos casar até 36?
- **Probabilidade** de um casado de 35 anos separar até 36?

### Por Que Não Basta a Prevalência?

A prevalência **não é uma probabilidade individual**:

```
Prevalência[35] = 60% → "60% dos homens de 35 estão casados HOJE"
                        ≠ "Um homem de 35 tem 60% de chance de casar"
```

Para cálculos atuariais, precisamos de **transições**:
- `q_casar[x]`: Prob. de casar entre x e x+1 (dado solteiro em x)
- `q_separar[x]`: Prob. de separar entre x e x+1 (dado casado em x)

## Metodologia

### Modelo de Dois Estados

Definimos dois estados mutuamente exclusivos:
1. **Solteiro** (nunca casou, separado, viúvo)
2. **Casado** (casado ou união estável)

**Transições permitidas**:
```
         q_casar[x]
Solteiro ────────────→ Casado
    ↑                      │
    └──────────────────────┘
       q_separar[x]
```

**Nota**: Ignoramos mortalidade (análise separada em tábua de mortalidade).

### Funções da Tábua

Definimos, para cada idade `x`:

| Função | Nome | Significado |
|--------|------|-------------|
| `l_solteiro[x]` | Proporção solteira | Proporção que permanece solteira até idade x |
| `l_casado[x]` | Proporção casada | Proporção casada na idade x |
| `q_casar[x]` | Prob. de casar | P(casar entre x e x+1 \| solteiro em x) |
| `q_separar[x]` | Prob. de separar | P(separar entre x e x+1 \| casado em x) |

**Restrições**:
- `l_solteiro[x] + l_casado[x] = 1` (todos estão em um dos estados)
- `0 ≤ q_casar[x] ≤ 1` e `0 ≤ q_separar[x] ≤ 1`

### Equações de Transição

A **recorrência** que conecta estados entre idades consecutivas:

```julia
l_solteiro[x+1] = l_solteiro[x] * (1 - q_casar[x]) + l_casado[x] * q_separar[x]
l_casado[x+1]   = l_solteiro[x] * q_casar[x]       + l_casado[x] * (1 - q_separar[x])
```

**Interpretação**:
- Solteiros em x+1 = solteiros que não casaram + casados que separaram
- Casados em x+1 = solteiros que casaram + casados que não separaram

### Relação com Prevalência Observada

A **prevalência** observada nos dados é:

```julia
P[x] = l_casado[x]
```

**Problema inverso**: Dados `P[x]` (observado), encontrar `q_casar[x]` e `q_separar[x]` tais que o modelo reproduza `P[x]`.

## Implementação

### Método 1: Primeira Diferença (Simplificado)

**Hipótese simplificadora**: `q_separar[x] ≈ 0` (separações são raras)

Então:
```julia
l_casado[x+1] ≈ l_casado[x] + l_solteiro[x] * q_casar[x]
```

Como `l_solteiro[x] = 1 - l_casado[x]` e `P[x] = l_casado[x]`:

```julia
P[x+1] ≈ P[x] + (1 - P[x]) * q_casar[x]
```

**Resolvendo para `q_casar[x]`**:

```julia
q_casar[x] = (P[x+1] - P[x]) / (1 - P[x])
```

**Limitações**:
- Funciona bem quando `P[x]` é crescente (idades jovens)
- Falha quando `P[x]` decresce (viuvez/separação nas idades mais velhas)
- Não estima `q_separar[x]` explicitamente

**Código**:
```julia
function estimar_q_casar_simples(prevalencias::Vector{Float64})
    n = length(prevalencias)
    q_casar = zeros(n-1)

    for x in 1:(n-1)
        dP = prevalencias[x+1] - prevalencias[x]
        denominador = 1.0 - prevalencias[x]

        if denominador > 0.01  # Evitar divisão por zero
            if dP > 0  # Crescimento = pessoas casando
                q_casar[x] = dP / denominador
            else  # Decrescimento = separação domina
                q_casar[x] = 0.0
            end
        else
            q_casar[x] = 0.0
        end

        # Limitar a [0, 0.5]
        q_casar[x] = clamp(q_casar[x], 0.0, 0.5)
    end

    return q_casar
end
```

### Método 2: Otimização Dois Estados (Completo)

**Objetivo**: Encontrar `q_casar[x]` e `q_separar[x]` que minimizem:

```julia
Erro = Σ (P_observada[x] - P_modelo[x])²
```

Onde `P_modelo[x]` é calculado via equações de transição.

**Algoritmo**: Gradiente descendente iterativo

1. **Inicialização**: Usar método simples para `q_casar`, zero para `q_separar`

2. **Forward Pass**: Calcular `l_solteiro[x]` e `l_casado[x]` dadas as taxas atuais

3. **Backward Pass**: Atualizar taxas usando gradientes:
   ```julia
   ∂Erro/∂q_casar[x]   ≈ -2 * erro[x+1] * l_solteiro[x]
   ∂Erro/∂q_separar[x] ≈ -2 * erro[x+1] * (-l_casado[x])

   q_casar[x]   += learning_rate * erro[x+1] * (l_solteiro[x] / total)
   q_separar[x] += learning_rate * erro[x+1] * (-l_casado[x] / total)
   ```

4. **Repetir** até convergência (MAE < 0.01%)

**Vantagens**:
- Estima ambas as taxas (`q_casar` e `q_separar`)
- Funciona em toda a faixa etária
- Minimiza erro globalmente

**Código**:
```julia
function estimar_taxas_dois_estados(prevalencias::Vector{Float64};
                                     max_iter::Int = 200,
                                     tol::Float64 = 1e-4)
    n = length(prevalencias)

    # Inicializar
    q_casar = estimar_q_casar_simples(prevalencias)
    q_separar = zeros(n-1)

    lr = 0.05  # Learning rate

    for iter in 1:max_iter
        # === FORWARD PASS ===
        l_solt = zeros(n)
        l_cas = zeros(n)

        l_solt[1] = 1.0 - prevalencias[1]
        l_cas[1] = prevalencias[1]

        for x in 1:(n-1)
            q_c = clamp(q_casar[x], 0.0, 0.99)
            q_s = clamp(q_separar[x], 0.0, 0.99)

            l_solt[x+1] = l_solt[x] * (1 - q_c) + l_cas[x] * q_s
            l_cas[x+1] = l_solt[x] * q_c + l_cas[x] * (1 - q_s)

            # Normalizar
            total = l_solt[x+1] + l_cas[x+1]
            if total > 0
                l_solt[x+1] /= total
                l_cas[x+1] /= total
            end
        end

        # Calcular erro
        P_modelo = l_cas
        erro = prevalencias .- P_modelo
        mae = mean(abs.(erro))

        # Convergência
        if mae < tol
            return (q_casar=q_casar, q_separar=q_separar,
                    l_solteiro=l_solt, l_casado=l_cas,
                    P_reconstruida=P_modelo, erro_abs=erro)
        end

        # === BACKWARD PASS ===
        for x in 1:(n-1)
            if l_solt[x] + l_cas[x] > 0
                grad_casar = l_solt[x] / (l_solt[x] + l_cas[x])
                grad_separar = -l_cas[x] / (l_solt[x] + l_cas[x])

                q_casar[x] += lr * erro[x+1] * grad_casar
                q_separar[x] += lr * erro[x+1] * grad_separar

                q_casar[x] = clamp(q_casar[x], 0.0, 0.99)
                q_separar[x] = clamp(q_separar[x], 0.0, 0.5)
            end
        end

        # Decaimento de learning rate
        if iter % 50 == 0
            lr *= 0.9
        end
    end

    # Retornar melhor resultado
    return (q_casar=q_casar, q_separar=q_separar,
            l_solteiro=l_solt, l_casado=l_cas,
            P_reconstruida=P_modelo, erro_abs=prevalencias .- P_modelo)
end
```

## Validação

### Critério de Convergência

O modelo é considerado válido se:

```julia
MAE = mean(|P_observada - P_reconstruida|) < 0.01  (1%)
```

### Verificações Adicionais

1. **Plausibilidade das taxas**:
   - `q_casar` deve ter pico entre 20-35 anos
   - `q_separar` deve ser pequeno (< 5% ao ano)

2. **Soma dos estados**:
   - `l_solteiro[x] + l_casado[x] = 1` para todo x

3. **Consistência temporal**:
   - Curvas suaves (sem saltos abruptos)

4. **Comparação com literatura**:
   - Idade média ao casar (Brasil: ~28 anos para homens, ~26 para mulheres)
   - Taxa de divórcio (Brasil: ~1.5% ao ano)

## Interpretação dos Resultados

### Curva de `q_casar[x]`

```
       q_casar (%)
         |
    15%  |     *
         |    / \
    10%  |   /   \
         |  /     \
     5%  | /       \___
         |/            \___
     0%  |─────────────────────→ idade
         15  20  25  30  35  40
```

**Interpretação**:
- Pico em ~25 anos: Idade mais comum de casamento
- Queda após 30: Menos solteiros disponíveis
- Assíntota ~0: Poucos casamentos após 40

### Curva de `l_solteiro[x]`

```
  l_solteiro (%)
         |
   100%  |●
         | \
    80%  |  \
         |   \
    60%  |    ●
         |      \
    40%  |       \
         |        ●____
    20%  |             ●──●
         |
     0%  |─────────────────────→ idade
         15  20  25  30  35  40
```

**Interpretação**:
- 100% aos 15: Todos solteiros
- Queda rápida 20-30: Período de casamentos
- Assíntota ~20%: Proporção que nunca casa

## Uso Prático: Função Heritor

### Cálculo de Pensão

Para servidor de idade `x`:

**1. Probabilidade de ter cônjuge**:
```julia
P_casado[x] = l_casado[x]
```

**2. Probabilidade de solteiro casar até idade `y`**:
```julia
P(casar até y | solteiro em x) = 1 - (l_solteiro[y] / l_solteiro[x])
```

**3. Valor esperado de pensão heritor**:
```julia
VPL_heritor = Σ P_casado[x] * beneficio[x] * v^(x - idade_atual)
```

Onde:
- `beneficio[x]`: Valor da pensão na idade x
- `v`: Fator de desconto atuarial

**4. Integração com age gap**:
```julia
# Para cada idade do servidor
idade_conjuge_esperada = idade_servidor - age_gap_medio[idade_servidor]

# Usar tábua de mortalidade do cônjuge
prob_conjuge_vivo = l_x[idade_conjuge] / l_x[idade_conjuge_atual]

# Pensão considerando ambos
VPL_pensao = P_casado * prob_conjuge_vivo * beneficio * v^t
```

## Limitações

### 1. Dados Transversais

Tábua sintética assume que comportamento atual se manterá no futuro:
- Ignora mudanças culturais (casamentos tardios)
- Ignora choques (divórcio facilitado)

**Solução**: Usar múltiplas PNADs (2011, 2015, 2023) para detectar tendências.

### 2. Sem Distinção de Estado Civil Detalhado

Não distingue:
- Solteiro (nunca casou)
- Separado/divorciado
- Viúvo

**Impacto**: `q_casar` mistura primeiros casamentos com recasamentos.

**Justificativa**: Para pensão heritor, o que importa é "tem cônjuge?" (binário).

### 3. Ignorar Mortalidade

O modelo não considera mortes (só transições conjugais):
- `l_solteiro[x]` não é afetado por mortalidade
- Viuvez é tratada como separação (`q_separar`)

**Justificativa**: Mortalidade é modelada separadamente (tábua BR-EMS).

### 4. Homogeneidade Intra-Grupo

Assume que todos servidores têm mesma `q_casar`:
- Ignora educação, renda, região
- Ignora tipo de cargo (estatutário vs celetista)

**Mitigação**: Estratificar por características adicionais se amostra permitir.

## Comparação com Literatura

### Tábuas de Nupcialidade Clássicas

Métodos tradicionais (Nuptiality Tables):
- **Coale-McNeil (1972)**: Modelo paramétrico para idade ao casar
- **Hernes (1972)**: Modelo de pressão social
- **Bloom (1982)**: Incorpora recasamentos

**Nossa abordagem**:
- Não-paramétrica (usa dados diretamente)
- Focada em prevalência (não incidência)
- Adaptada para plano de previdência

### Estudos Brasileiros

- **IBGE (2010)**: Projeções de nupcialidade para população geral
- **Caetano & Alves (2002)**: Idade ao casar no Brasil 1940-2000
- **Cerqueira & Givisiez (2004)**: Tábuas de nupcialidade regionais

**Diferencial deste projeto**:
- Específico para servidores públicos (não existe na literatura)
- Integração com cálculo atuarial de pensão

## Referências Técnicas

### Metodologia de Tábuas de Vida

1. **Chiang, C. L. (1984)**: *The Life Table and Its Applications*. Malabar: Krieger.

2. **Preston, S. H., Heuveline, P., & Guillot, M. (2000)**: *Demography: Measuring and Modeling Population Processes*. Blackwell.

3. **Keyfitz, N., & Caswell, H. (2005)**: *Applied Mathematical Demography*. Springer.

### Nupcialidade e União Conjugal

4. **Coale, A. J., & McNeil, D. R. (1972)**: The distribution by age of the frequency of first marriage in a female cohort. *Journal of the American Statistical Association*.

5. **Schoen, R., & Urton, W. (1979)**: A two-state nuptiality model. *Population Studies*, 33(2), 223-235.

### Contexto Brasileiro

6. **IBGE (2023)**: *Estatísticas do Registro Civil*. Vol. 50.

7. **Caetano, A. J., & Alves, J. E. D. (2002)**: Casamento, separação e divórcio no Brasil. *Anais do XIII Encontro da ABEP*.

### Atuária

8. **Bowers, N. L., et al. (1997)**: *Actuarial Mathematics*. Society of Actuaries.

9. **Dickson, D. C., Hardy, M. R., & Waters, H. R. (2020)**: *Actuarial Mathematics for Life Contingent Risks*. Cambridge University Press.

## Código Completo

Os scripts implementam toda a metodologia:

- **`05_tabua_sintetica.jl`**: Estimação das probabilidades de transição
- **`06_graficos_tabua_sintetica.jl`**: Visualizações e validação
- **`02_tabua_conjugalidade.jl`**: Cálculo das prevalências (input)

## Próximos Passos

1. **Validação com Dados Reais**: Executar pipeline completo com PNADC 2023

2. **Análise de Sensibilidade**: Testar impacto de diferentes valores de `q_separar`

3. **Projeções Temporais**: Usar PNAD 2011-2023 para projetar 2024-2040

4. **Integração Completa**: Combinar com:
   - Tábua de mortalidade (BR-EMS)
   - Age gap (diferença de idade)
   - Cálculo de VPL da pensão heritor

5. **Estratificação**: Refinar por:
   - Região (UF)
   - Escolaridade
   - Tipo de cargo público

---

**Atualização**: 2025-10-17
**Autor**: Projeto pq_heritor - Análise Atuarial Previdência
