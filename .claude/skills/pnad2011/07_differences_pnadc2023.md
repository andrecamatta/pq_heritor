# PNAD 2011 vs PNADC 2023 - Diferenças Principais

## Resumo Executivo

Este documento lista **todas as diferenças importantes** entre PNAD 2011 e PNADC 2023 que afetam análises de conjugalidade.

## Diferenças de Nomenclatura de Variáveis

### Tabela de Equivalências

| Conceito | PNAD 2011 | PNADC 2023 | Observações |
|----------|-----------|------------|-------------|
| **Sexo** | V0302 | V2007 | Códigos diferentes! |
| **Idade** | V8005 | V2009 | - |
| **Condição no domicílio** | V0401 | V2005 | Códigos equivalentes |
| **Peso amostral** | V4729 | V1032 | Metodologias diferentes |
| **Posição na ocupação** | V4706 | V4028 (agrupada)<br>V4009 (detalhada) | Códigos diferentes |
| **UF** | UF | UF | Mesma |
| **Número de ordem** | V0300 | V2003 | - |

### Códigos de Sexo (IMPORTANTE!)

⚠️ **ATENÇÃO**: Os códigos de sexo são **DIFERENTES**!

| Descrição | PNAD 2011 | PNADC 2023 |
|-----------|-----------|------------|
| Masculino | **2** | **1** |
| Feminino | **4** | **2** |

**Implicação**: Ao harmonizar dados, é necessário **recodificar**:

```julia
# Harmonizar sexo de PNAD 2011 para padrão PNADC 2023
df_2011.sexo_harmonizado = ifelse.(df_2011.V0302 .== 2, 1, 2)
```

### Códigos de Condição no Domicílio

| Descrição | PNAD 2011 (V0401) | PNADC 2023 (V2005) |
|-----------|-------------------|---------------------|
| Pessoa de referência | 01 | 01 |
| Cônjuge/companheiro | 02 | 02 (sexo diferente)<br>03 (mesmo sexo) |
| Filho(a) | 03 | 04 |
| Outros | 04-08 | 05-14 |

⚠️ **PNADC 2023 distingue cônjuge por orientação sexual** (códigos 02 e 03), PNAD 2011 não.

**Para harmonização**: Tratar V2005 ∈ {02, 03} como equivalente a V0401 = 02.

## Diferenças Metodológicas

### 1. Periodicidade

| Aspecto | PNAD 2011 | PNADC 2023 |
|---------|-----------|------------|
| **Frequência** | Anual (última semana de setembro) | Trimestral (contínua) |
| **Visitas** | 1 visita | 5 visitas (usar visita 1 ou 5) |
| **Período de referência** | Semana de referência em setembro | Trimestre de referência |

**Implicação**: Para comparar 2011 vs 2023:
- PNAD 2011: Dados de **setembro/2011**
- PNADC 2023: Usar **3º trimestre/2023** (jul-set) para maior comparabilidade

### 2. Abrangência Geográfica

| Região | PNAD 2011 | PNADC 2023 |
|--------|-----------|------------|
| **Zona rural da Região Norte** | ❌ **NÃO incluída** | ✅ **Incluída** |
| Demais regiões | Incluídas | Incluídas |

**Implicação**: PNADC 2023 tem maior cobertura. Para comparação rigorosa, pode ser necessário **excluir zona rural do Norte** na PNADC 2023.

### 3. Desenho Amostral

| Aspecto | PNAD 2011 | PNADC 2023 |
|---------|-----------|------------|
| **Tipo** | Amostra complexa (estratificada) | Amostra complexa (painel rotativo) |
| **Tamanho** | ~150k domicílios | ~211k domicílios (anual) |
| **Pessoas** | ~350k | ~700k (anual consolidado) |

### 4. Pesos Amostrais

| Aspecto | PNAD 2011 (V4729) | PNADC 2023 (V1032) |
|---------|-------------------|--------------------|
| **Calibração** | Projeções populacionais 2011 | Projeções populacionais 2023 |
| **Pós-estratificação** | Sim | Sim (mais refinada) |
| **Formato** | 14 dígitos | 14 dígitos |

**Implicação**: Pesos não são diretamente comparáveis (diferentes bases populacionais).

## Diferenças de Conteúdo

### 1. Variáveis Disponíveis

#### Em PNAD 2011 mas NÃO em PNADC 2023

Geralmente, a PNADC é mais completa. Variáveis específicas da PNAD tradicional que podem não estar na PNADC:
- Algumas perguntas suplementares específicas de 2011

#### Em PNADC 2023 mas NÃO em PNAD 2011

- **V2005 = 03**: Cônjuge do mesmo sexo (categoria separada)
- Variáveis longitudinais (painel)
- Maior detalhamento de ocupação

### 2. Identificação de Servidor Público

⚠️ **Códigos provavelmente diferentes**

| Aspecto | PNAD 2011 | PNADC 2023 |
|---------|-----------|------------|
| **Variável** | V4706 | V4028 (agrupada) |
| **Código servidor** | ? (verificar dicionário) | 5 |
| **Militares** | Código separado (02?) | Categoria separada |

**AÇÃO NECESSÁRIA**: Verificar no dicionário PNAD 2011 qual código corresponde a servidor público estatutário.

## Comparação de Tamanhos de Arquivo

| Aspecto | PNAD 2011 | PNADC 2023 |
|---------|-----------|------------|
| **Arquivo .txt (FWF)** | ~100-150 MB | ~200-300 MB (visita 1) |
| **Arquivo .zip** | ~30-50 MB | ~80-120 MB |
| **Tempo de leitura** | 1-2 min | 2-4 min |

## Impacto nas Análises de Conjugalidade

### Comparabilidade

✅ **Altamente comparável**:
- Conceito de cônjuge (condição no domicílio)
- Estrutura domiciliar
- Idade e sexo

⚠️ **Requer ajustes**:
- Recodificar sexo (2/4 → 1/2)
- Considerar V2005 ∈ {02, 03} como cônjuge
- Verificar equivalência de servidor público
- Decidir sobre zona rural do Norte

❌ **Não comparável**:
- Valores absolutos dos pesos (bases populacionais diferentes)
- Meses de referência (setembro vs trimestre)

### Harmonização Recomendada

```julia
function harmonizar_pnad2011_pnadc2023(df_2011::DataFrame, df_2023::DataFrame)
    """
    Harmoniza variáveis entre PNAD 2011 e PNADC 2023
    """

    # === PNAD 2011 ===

    # Sexo: 2/4 → 1/2
    df_2011.sexo = ifelse.(df_2011.V0302 .== 2, 1, 2)

    # Idade
    df_2011.idade = df_2011.V8005

    # Cônjuge: V0401 = 02
    df_2011.condicao_dom = df_2011.V0401
    df_2011.eh_conjuge = df_2011.V0401 .== 02

    # Peso
    df_2011.peso = df_2011.V4729

    # Servidor (verificar código!)
    df_2011.servidor = df_2011.V4706 .== 05  # Placeholder!

    # Ano
    df_2011.ano = 2011

    # === PNADC 2023 ===

    # Sexo: já é 1/2
    df_2023.sexo = df_2023.V2007

    # Idade
    df_2023.idade = df_2023.V2009

    # Cônjuge: V2005 ∈ {02, 03}
    df_2023.condicao_dom = df_2023.V2005
    df_2023.eh_conjuge = df_2023.V2005 .∈ Ref([02, 03])

    # Peso
    df_2023.peso = df_2023.V1032

    # Servidor
    df_2023.servidor = df_2023.V4028 .== 5

    # Ano
    df_2023.ano = 2023

    # === FILTROS COMUNS ===

    # Excluir zona rural do Norte se comparabilidade estrita
    # df_2023 = filter(row -> !(row.UF <= 17 && row.V1022 == 2), df_2023)

    # Idade 15-90
    filter!(row -> 15 <= row.idade <= 90, df_2011)
    filter!(row -> 15 <= row.idade <= 90, df_2023)

    # Pesos válidos
    filter!(row -> row.peso > 0, df_2011)
    filter!(row -> row.peso > 0, df_2023)

    # === EMPILHAR ===

    # Selecionar colunas comuns
    colunas_comuns = [:ano, :UF, :sexo, :idade, :condicao_dom, :eh_conjuge, :servidor, :peso]

    df_2011_sel = select(df_2011, colunas_comuns)
    df_2023_sel = select(df_2023, colunas_comuns)

    # Combinar
    df_combinado = vcat(df_2011_sel, df_2023_sel)

    return df_combinado
end
```

## Checklist de Comparação

Antes de comparar PNAD 2011 vs PNADC 2023:

- [ ] Recodificar sexo (PNAD 2011: 2/4 → 1/2)
- [ ] Tratar V2005 ∈ {02, 03} como cônjuge (PNADC 2023)
- [ ] Verificar equivalência de servidor público
- [ ] Decidir sobre zona rural do Norte (incluir/excluir)
- [ ] Usar trimestre comparável (3º tri PNADC 2023)
- [ ] Documentar diferenças metodológicas
- [ ] Validar tendências (esperar mudanças graduais, não abruptas)

## Validação de Tendências Esperadas (2011 → 2023)

### Tendências Plausíveis

Entre 2011 e 2023, espera-se:

✅ **Diminuição da conjugalidade jovem** (20-30 anos):
- Adiamento de casamentos
- Maior coabitação sem formalização

✅ **Aumento da conjugalidade em idades mais altas** (60+):
- Aumento da expectativa de vida
- Recasamentos

✅ **Redução do diferencial por escolaridade/ocupação**:
- Convergência de padrões sociais

⚠️ **Se observar**:
- Mudanças abruptas (>10 pp em qualquer idade): Verificar harmonização
- Inversão completa de padrões: Provável erro metodológico

## Referências

- IBGE (2012). *Notas Metodológicas PNAD 2011*.
- IBGE (2024). *Notas Metodológicas PNAD Contínua*.
- IBGE (2016). *Transição da PNAD para PNAD Contínua - Notas Técnicas*.

---

**Última atualização**: 2025-10-17
**Status**: ✅ Diferenças documentadas - Códigos PNAD 2011 a serem confirmados
