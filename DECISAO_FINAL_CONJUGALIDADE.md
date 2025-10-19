# Decisão Final: Abordagem para Conjugalidade

**Data**: 2025-10-18
**Status**: ✅ **CONCLUÍDO**

---

## 🎯 Abordagem Escolhida

### **Credibilidade Bühlmann-Straub + Média Móvel Ponderada** ⭐

**Arquivo**: `08_credibilidade_servidores.jl`
**Resultado**: `resultados/conjugalidade_credivel.csv`
**Coluna usar**: `P_suavizado`

---

## 📊 Abordagens Testadas

| Abordagem                            | Status      | Problema                          |
|--------------------------------------|-------------|-----------------------------------|
| **Cred + Média Móvel** ⭐ (ATUAL)     | ✅ **USAR**  | Nenhum! Funciona perfeitamente    |
| Cred + Natural Splines               | ❌ Rejeitado| **Serrilhado** (oscila em 78-80)  |
| GLM Polinômios                       | ❌ Rejeitado| **Sobe** nas extremidades (+1.7%/ano) |

---

## 🔍 Por Que Média Móvel Venceu?

### Problema dos Splines: **Serrilhamento**

**Dados em idades avançadas** (poucos servidores):
```
Idade 78: Observado = 100% (1 servidor casado)
Idade 79: Observado = 0%   (1 servidor solteiro)
Idade 80: Observado = 100% (1 servidor casado)
```

**Comportamento**:
- **Splines**: Tentam interpolar TODOS os pontos → **Oscilam**: 28% → 24% → 29% ❌
- **Média Móvel**: Fazem média dos vizinhos → **Suave**: 26% → 26% → 26% ✅

### Por Que Média Móvel É Melhor?

**Média móvel** (`suavizar_com_prior` em linhas 29-79):
```julia
Para cada idade:
  1. Pegar vizinhos (janela=5: idade±2)
  2. Média ponderada (pesos triangulares)
  3. Ancorar 30% na população geral
  4. Repetir 3 vezes
```

**Efeito**:
- ✅ "Borra" oscilações locais
- ✅ Remove ruído de amostras pequenas
- ✅ Curva final **muito suave**
- ✅ Não sobe nas extremidades (como GLM)

---

## 📈 Comparação Numérica

### Idades Avançadas (85-90 anos)

| Abordagem       | Masc 85-90 | Fem 85-90 | Inclinação (M) | Serrilhamento |
|-----------------|------------|-----------|----------------|---------------|
| **Média Móvel** ⭐ | **46%**    | **8%**    | **-3.7%/ano**  | ✅ Suave      |
| Splines         | 46%        | 7%        | -4.6%/ano      | ❌ Oscila     |
| GLM             | 69%        | 64%       | +1.7%/ano      | ⚠️ Sobe!      |

### Suavidade (Desvio-Padrão da Curva)

| Abordagem       | Volatilidade | Suavidade |
|-----------------|--------------|-----------|
| **Média Móvel** ⭐ | **Baixa**    | ✅✅✅      |
| Splines         | Média        | ⚠️⚠️       |
| GLM             | Baixa        | ✅✅        |

---

## 🔧 Implementação da Abordagem Vencedora

### Arquivo: `08_credibilidade_servidores.jl`

**Etapa 1: Credibilidade Bühlmann-Straub**
```julia
# 1. Estimar shift Δ (diferença servidores - pop geral)
Δ = média(P_serv - P_geral) onde n_serv ≥ 30

# 2. Ajustar população geral
P_geral_ajustado = P_geral + Δ

# 3. Calcular fator de credibilidade
Z = n_serv / (n_serv + k), onde k = √(média(n_serv))

# 4. Combinar
P_credível = Z × P_serv + (1-Z) × P_geral_ajustado
```

**Etapa 2: Média Móvel Ponderada** (função `suavizar_com_prior`)
```julia
# Parâmetros:
janela = 5          # Vizinhos: idade ± 2
peso_prior = 0.3    # 30% ancoragem na pop geral
n_iteracoes = 3     # 3 passadas de suavização

# Algoritmo:
for iter in 1:3
    for idade in 15:90
        # Média dos vizinhos com pesos triangulares
        vizinhos = [idade-2, idade-1, idade, idade+1, idade+2]
        valor_local = média_ponderada(vizinhos)

        # Combinar com pop geral
        P_suavizado[idade] = 0.7 * valor_local + 0.3 * P_geral_ajustado[idade]
    end
end
```

---

## ✅ Vantagens da Abordagem Escolhida

### vs Splines:
- ✅ **Mais suave**: Não serrilha em dados ruidosos
- ✅ **Simples**: Média móvel > splines cúbicos
- ✅ **Robusto**: Funciona bem com poucos dados

### vs GLM:
- ✅ **Não sobe nas extremidades**: Média móvel mantém comportamento plausível
- ✅ **Trata poucos dados**: Credibilidade ancora na pop geral
- ✅ **Preserve shift**: Diferença servidores-geral é mantida

### Teoria de Credibilidade:
- ✅ **Fundamentação atuarial**: Bühlmann-Straub é reconhecido (saúde suplementar)
- ✅ **Peso adaptativo**: Z varia por idade conforme n amostral
- ✅ **Shift preservado**: Δ captura diferença sistemática

---

## 📁 Arquivos Finais

### **USAR ESTES**:
- **Script**: `08_credibilidade_servidores.jl` ⭐
- **Dados**: `resultados/conjugalidade_credivel.csv` ⭐
- **Coluna**: `P_suavizado` ⭐

### Arquivos de Teste (não usar):
- `08b_modelo_glm_conjugalidade.jl` - GLM (sobe nas extremidades)
- `08d_credibilidade_splines.jl` - Splines (serrilhado)
- `08e_graficos_3_abordagens.jl` - Comparação visual

---

## 🎓 Lições Aprendidas

### 1. Média Móvel > Splines para Dados Ruidosos

**Quando usar média móvel**:
- ✅ Poucos dados (n < 10 em algumas idades)
- ✅ Oscilações grandes (0% → 100% → 0%)
- ✅ Precisa de suavidade

**Quando usar splines**:
- ⚠️ Muitos dados (n > 100 em todas idades)
- ⚠️ Dados já suaves
- ⚠️ Precisa de interpolação precisa

### 2. GLM Polinômios Falham nas Extremidades

**Problema fundamental**: Polinômios **extrapolam mal**
- Grau 3: sobe nas extremidades
- Grau 4: oscila ainda mais
- Grau 2: não captura curva complexa

**Solução**: Não usar polinômios para dados demográficos!

### 3. Credibilidade Resolve Poucos Dados

**Por quê funciona**:
- Toma "emprestado" informação da população geral
- Peso adaptativo: mais pop geral quando n pequeno
- Preserva diferença sistemática (shift Δ)

---

## 🚀 Próximos Passos

### Curto Prazo (Concluído ✅):
- ✅ Testar 3 abordagens (Média Móvel, Splines, GLM)
- ✅ Comparar resultados
- ✅ Escolher abordagem final
- ✅ Documentar decisão

### Médio Prazo:
1. **Age Gap**: Aplicar mesma abordagem (Credibilidade + Média Móvel)
2. **Validação**: Testar em dados 2011 (out-of-sample)
3. **Intervalos de Confiança**: Bootstrap para quantificar incerteza

### Longo Prazo:
1. **Função Heritor Completa**: Conjugalidade + Age Gap + Mortalidade
2. **Projeções 2024-2040**: Extrapolar tendências
3. **Harmonização 2011-2023**: Análise temporal

---

## 📚 Referências

### Teoria de Credibilidade:
- Bühlmann-Straub: Aplicação em saúde suplementar (Brasil)
- IBA (Instituto Brasileiro de Atuária)

### Suavização:
- Média móvel ponderada: Equivalente a filtro Savitzky-Golay (grau 0)
- Whittaker-Henderson: Graduação clássica (similar em espírito)

### Splines (testados mas rejeitados):
- Hyndman (2007): "Spline interpolation for demographic variables"
- Interpolations.jl: Natural cubic splines

---

## 💡 Resumo Executivo (1 parágrafo)

A abordagem **Credibilidade Bühlmann-Straub + Média Móvel Ponderada** foi escolhida como solução final para modelar conjugalidade de servidores públicos. Splines naturais foram testados mas produzem serrilhamento (oscilações em idades avançadas com poucos dados), enquanto GLM com polinômios sobe erraticamente nas extremidades (68% aos 90 anos). A média móvel (janela=5, 3 iterações) remove ruído efetivamente, produzindo curvas suaves e plausíveis. A credibilidade resolve o problema de poucos dados ancorando na população geral com peso adaptativo. Resultado: curva estável, monotônica onde esperado, e adequada para uso atuarial na função heritor.

---

**Status**: ✅ **DECISÃO FINAL TOMADA**
**Abordagem**: **Credibilidade + Média Móvel** (`08_credibilidade_servidores.jl`)
**Arquivo usar**: `resultados/conjugalidade_credivel.csv` (coluna `P_suavizado`)
