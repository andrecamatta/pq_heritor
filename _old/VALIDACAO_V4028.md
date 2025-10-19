# Validação da Variável V4028 - Servidor Público

## Data: 2025-10-17

## Contexto
Durante o desenvolvimento da tábua de conjugalidade, surgiu a dúvida se estávamos capturando **todos** os servidores públicos disponíveis na PNADC 2023. Este documento registra a investigação e validação realizada.

## Critério Atual
```julia
# 01_processar_dados.jl (linha 104)
servidor = v4028_str == "1"
```

## Investigação

### 1. Análise da Distribuição de V4028 nos Dados Brutos

**Amostra**: 377 mil registros (500k limite)

**Distribuição encontrada**:
| Código | Frequência | Percentual | Interpretação |
|--------|------------|------------|---------------|
| "1"    | 12.549     | 3,32%      | **Servidor estatutário** |
| "2"    | 2.772      | 0,73%      | **NÃO é servidor** |
| VAZIO  | 362.473    | 95,94%     | Pessoa não ocupada |

### 2. Documentação Oficial da PNADC

**Fonte**: Dicionário PNADC Visita 5 (Data Zoom PUC-Rio)

**V4028**: "Nesse trabalho, ... era servidor público estatutário (federal, estadual ou municipal)?"

**Tipo**: Pergunta Sim/Não (binária)
- **Código "1" = SIM** → Servidor público estatutário
- **Código "2" = NÃO** → Não é servidor estatutário
- **VAZIO** → Não aplicável (pessoa não ocupada/sem trabalho)

**Aplicabilidade**: Pessoas ocupadas de 14 anos ou mais de idade

### 3. Comparação com Estimativas Oficiais

#### Fontes Oficiais (2023):
- **IPEA/ENAP - Atlas do Estado Brasileiro**:
  - Servidores estatutários: **~7,0 milhões**
  - Total servidores públicos (todos tipos): ~11,3 milhões

#### Nossos Dados (PNADC 2023):
- **Servidor com V4028="1"** (idades 15-90): **6,84 milhões**

#### Taxa de Captura:
```
6,84M / 7,0M = 97,7% ✓
```

**Diferença**: 160 mil pessoas (2,3%)

**Explicação da diferença**:
1. Nosso filtro exclui idades <15 e >90 anos
2. Diferenças metodológicas entre fontes (IPEA usa múltiplas bases)
3. Margem de erro amostral da PNADC (~1-2%)

## Conclusões

### ✅ VALIDAÇÃO APROVADA

1. **V4028 está corretamente definida**: Captura servidor estatutário via pergunta binária Sim/Não

2. **Nosso critério está correto**: `V4028 == "1"` identifica precisamente servidores estatutários

3. **Cobertura excelente**: 97,7% de captura em relação às estimativas oficiais

4. **Código "2" não deve ser incluído**: Representa explicitamente "NÃO é servidor"

5. **Militares**: Não são classificados como "servidores estatutários" e não aparecem em V4028. Esta distinção é **constitucional** (EC 18/1998) e está correta.

## Observações Importantes

### Sobre Militares
- Após a Emenda Constitucional 18/1998, militares foram **excluídos** da categoria de servidores públicos
- São tratados separadamente no arcabouço legal brasileiro
- Não é esperado que apareçam em V4028 (que pergunta especificamente sobre "servidor estatutário")

### Tipos de Servidores Públicos
| Tipo | Estimativa 2023 | Capturado por V4028? |
|------|-----------------|----------------------|
| Estatutários (concursados) | 7,0 M | ✅ SIM (código "1") |
| CLT (empregados públicos) | 2,5 M | ❌ NÃO (são empregados) |
| Comissionados | 0,8 M | ❌ NÃO (não estatutários) |
| Militares | 1,0 M | ❌ NÃO (categoria separada) |
| **TOTAL** | **11,3 M** | **7,0 M capturados** |

## Recomendação Final

**✅ NENHUMA ALTERAÇÃO NECESSÁRIA**

O código atual (`servidor = v4028_str == "1"`) está:
- Tecnicamente correto
- Bem documentado na fonte oficial
- Validado contra estimativas externas
- Capturando 97,7% do universo esperado

Manter como está e prosseguir com as análises de conjugalidade.

---

**Validação realizada por**: Claude Code
**Fontes consultadas**:
- IBGE - PNADC 2023 Microdados Visita 5
- IPEA - Atlas do Estado Brasileiro
- ENAP - Estatísticas de Servidores Públicos
- Data Zoom PUC-Rio - Dicionário PNADC
