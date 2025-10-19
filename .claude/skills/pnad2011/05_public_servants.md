# PNAD 2011 - Identificação de Servidores Públicos

## Como Identificar Servidores Públicos na PNAD 2011

⚠️ **ATENÇÃO**: A identificação de servidores públicos **estatutários** na PNAD 2011 pode requerer cruzamento de variáveis. Os códigos exatos devem ser verificados no dicionário oficial.

## Variáveis Relevantes

### V4706 - Posição na Ocupação no Trabalho Principal

Esta é provavelmente a variável principal para identificar servidores públicos.

**Códigos prováveis** (verificar dicionário oficial):

| Código | Descrição | Servidor? |
|--------|-----------|-----------|
| 01 | Empregado com carteira de trabalho assinada | ❌ |
| 02 | Militar | ✅ (mas categoria especial) |
| 03 | Empregado sem carteira de trabalho assinada | ❌ |
| 04 | Conta própria | ❌ |
| 05 | Empregador | ❌ |
| 06 | Trabalhador na construção para o próprio uso | ❌ |
| 07 | Trabalhador na produção para o próprio consumo | ❌ |
| 08 | Não remunerado | ❌ |
| 09 | Não aplicável (desocupado/inativo) | ❌ |

⚠️ **Problema**: O código específico para **servidor público estatutário** pode:
- Estar em V4706 (código a ser verificado)
- Estar em outra variável (V4805, V9001, etc.)
- Requerer cruzamento de variáveis

### Possíveis Abordagens

#### Abordagem 1: Usar V4706 Diretamente (se houver código específico)

```julia
# Verificar se código 05 ou outro indica servidor público
df.servidor_publico = df.V4706 .== 05  # Código hipotético!
```

#### Abordagem 2: Cruzar com Setor de Atividade (V9001)

Se V4706 não distingue servidor público, pode ser necessário cruzar com setor:

```julia
# Exemplo: empregado (com carteira) no setor público
df.servidor_publico = (df.V4706 .== 01) .&& (df.setor .== "Público")
```

⚠️ **Verificar** se existe variável de setor público/privado.

#### Abordagem 3: Usar Código de Ocupação (V4805)

Algumas ocupações são exclusivamente de servidores públicos (professores de escola pública, policiais civis, etc.).

Limitação: Trabalhoso e não captura todos os servidores.

## Implementação Recomendada

### Passo 1: Verificar Dicionário Oficial

Após download dos microdados:

```julia
# Analisar distribuição de V4706
println("Distribuição de V4706 (Posição na ocupação):")
println(combine(groupby(df, :V4706), nrow => :n))

# Ver se há padrão claro
```

### Passo 2: Implementar Marcação

```julia
function identificar_servidores_pnad2011!(df::DataFrame)
    """
    Identifica servidores públicos estatutários

    ⚠️ PLACEHOLDER - Ajustar após verificar dicionário oficial
    """

    # OPÇÃO 1: Código direto em V4706
    # df.servidor_publico = df.V4706 .== 05  # Código a ser verificado!

    # OPÇÃO 2: Cruzamento (exemplo)
    # df.servidor_publico = (df.V4706 .== 01) .&& (df.setor_publico .== true)

    # OPÇÃO 3: Incluir militares
    # df.servidor_publico = (df.V4706 .== 05) .|| (df.V4706 .== 02)

    # PLACEHOLDER: Marcar todos como não-servidor até verificação
    df.servidor_publico = fill(false, nrow(df))

    @warn "ATENÇÃO: Identificação de servidores públicos usando PLACEHOLDER. Verificar dicionário PNAD 2011!"

    return df
end
```

### Passo 3: Validação

```julia
function validar_servidores_pnad2011(df::DataFrame)
    """
    Valida identificação de servidores públicos
    """

    println("=== Validação: Servidores Públicos ===\n")

    # Total identificado
    n_servidores = count(df.servidor_publico)
    n_total = nrow(df)
    prop_servidores = n_servidores / n_total * 100

    println("Total de servidores: $n_servidores ($(round(prop_servidores, digits=1))%)")

    # População estimada
    pop_total = sum(df.V4729[df.servidor_publico]) / 1_000_000
    println("População de servidores: $(round(pop_total, digits=1)) milhões")

    # Por sexo
    println("\nDistribuição por sexo:")
    for sexo in [2, 4]
        sexo_label = sexo == 2 ? "Masculino" : "Feminino"
        n = count(df.servidor_publico .&& (df.V0302 .== sexo))
        prop = n / count(df.V0302 .== sexo) * 100
        println("  $sexo_label: $n ($(round(prop, digits=1))%)")
    end

    # Verificação de plausibilidade
    println("\n=== Plausibilidade ===")
    if prop_servidores < 5.0
        @warn "Proporção muito baixa de servidores (< 5%). Verificar identificação!"
    elseif prop_servidores > 15.0
        @warn "Proporção muito alta de servidores (> 15%). Verificar identificação!"
    else
        println("✓ Proporção dentro do esperado (5-15%)")
    end

    # Referência: Segundo IBGE, há ~11 milhões de servidores públicos no Brasil
    # Em uma amostra de ~195 milhões, esperamos ~5.6%
    if pop_total < 8.0 || pop_total > 14.0
        @warn "População estimada fora do intervalo esperado (8-14 milhões)"
    else
        println("✓ População estimada plausível")
    end
end
```

## Comparação com PNADC 2023

### Diferenças Conhecidas

| Aspecto | PNAD 2011 | PNADC 2023 |
|---------|-----------|------------|
| **Variável principal** | V4706 | V4028 |
| **Código servidor** | **?** (verificar) | 5 |
| **Detalhamento** | Menos categorias | V4009 (detalhado) |
| **Militares** | Código separado (02) | Incluídos ou código separado |

### Harmonização

Para comparar 2011 vs 2023, é essencial usar **critérios equivalentes**:

```julia
function harmonizar_servidor_publico(df_2011::DataFrame, df_2023::DataFrame)
    """
    Garante que a definição de servidor público seja equivalente
    """

    # PNAD 2011
    # df_2011.servidor = df_2011.V4706 .== 05  # Código a verificar

    # PNADC 2023
    df_2023.servidor = df_2023.V4028 .== 5

    # Decisão sobre militares:
    # OPÇÃO 1: Incluir militares
    # df_2011.servidor .|= (df_2011.V4706 .== 02)
    # df_2023.servidor .|= (df_2023.V4028 .== X)  # Se houver código separado

    # OPÇÃO 2: Excluir militares (manter apenas estatutários civis)
    # (padrão acima)

    return (df_2011, df_2023)
end
```

## Casos Especiais

### 1. Militares

**Decisão necessária**: Incluir ou não militares na categoria "servidor público"?

- **Incluir**: Mais representativo do setor público
- **Excluir**: Análise focada em civis (regime diferente)

### 2. Empregados Públicos (CLT)

Servidores públicos contratados por CLT (não estatutários):

- **PNAD 2011**: Podem estar misturados com setor privado
- **PNADC 2023**: Mesma limitação

**Recomendação**: Documentar claramente se análise inclui apenas estatutários ou todos os trabalhadores do setor público.

### 3. Autarquias e Fundações

Podem ter regime jurídico diferente. Verificar se estão incluídos na identificação.

## Estatísticas de Referência (2011)

Para validar a identificação:

- **Servidores públicos no Brasil (2011)**: ~11 milhões (IPEA/IBGE)
  - Federal: ~1 milhão
  - Estadual: ~3-4 milhões
  - Municipal: ~6-7 milhões

- **Proporção da PEA**: ~11-12%

- **Proporção da população ocupada**: ~12-13%

## Exemplo de Análise: Conjugalidade de Servidores

```julia
# Após identificação correta de servidores
function analisar_conjugalidade_servidores_pnad2011(df::DataFrame)
    """
    Compara conjugalidade entre servidores e não-servidores
    """

    # Identificar cônjuges e servidores
    identificar_conjuges_pnad2011!(df)
    identificar_servidores_pnad2011!(df)

    # Calcular proporções
    resultado = combine(groupby(df, [:V0302, :V8005, :servidor_publico])) do sdf
        total_pond = sum(sdf.V4729)
        com_conjuge_pond = sum(sdf.V4729[sdf.tem_conjuge])
        prop = total_pond > 0 ? com_conjuge_pond / total_pond * 100 : 0.0

        DataFrame(prop_com_conjuge = prop, n_pond = total_pond)
    end

    return resultado
end
```

## Checklist de Implementação

Antes de usar a identificação de servidores:

- [ ] Baixar e ler dicionário oficial da PNAD 2011
- [ ] Verificar códigos de V4706 (Posição na ocupação)
- [ ] Verificar se há variável adicional de setor (público/privado)
- [ ] Testar identificação e calcular proporção total
- [ ] Validar com estatísticas de referência (~11 milhões)
- [ ] Documentar critérios usados (incluir/excluir militares, etc.)
- [ ] Garantir harmonização com PNADC 2023

## Referências

- IBGE (2012). *Dicionário de Variáveis PNAD 2011*.
- IPEA. *Atlas do Estado Brasileiro* (estatísticas de servidores públicos).
- `.claude/skills/pnadc2023/05_public_servants.md` (para comparação)

---

**Última atualização**: 2025-10-17
**Status**: ⚠️ **PLACEHOLDER** - Códigos exatos devem ser verificados no dicionário oficial PNAD 2011
