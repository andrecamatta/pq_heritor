# PNAD 2011 - Dicionário de Variáveis

⚠️ **ATENÇÃO**: Este dicionário contém valores **APROXIMADOS** baseados em documentação geral da PNAD.
**É ESSENCIAL verificar o dicionário oficial da PNAD 2011** após download dos microdados.

## Variáveis de Identificação

| Variável | Tipo | Tamanho | Descrição |
|----------|------|---------|-----------|
| **UF** | N | 2 | Unidade da Federação |
| **V0102** | N | 5 | Número de controle |
| **V0103** | N | 3 | Número de série |
| **V0300** | N | 2 | Número de ordem da pessoa |
| **V0301** | N | 2 | Número de pessoas no domicílio |

### Códigos de UF

```
11 = Rondônia          21 = Maranhão         31 = Minas Gerais     41 = Paraná
12 = Acre              22 = Piauí            32 = Espírito Santo   42 = Santa Catarina
13 = Amazonas          23 = Ceará            33 = Rio de Janeiro   43 = Rio Grande do Sul
14 = Roraima           24 = Rio Grande Norte 35 = São Paulo        50 = Mato Grosso do Sul
15 = Pará              25 = Paraíba          41 = Paraná           51 = Mato Grosso
16 = Amapá             26 = Pernambuco       42 = Santa Catarina   52 = Goiás
17 = Tocantins         27 = Alagoas          43 = Rio Grande Sul   53 = Distrito Federal
21 = Maranhão          28 = Sergipe
                       29 = Bahia
```

## Variáveis Demográficas

### V0302 - Sexo

| Código | Descrição |
|--------|-----------|
| **2** | Masculino |
| **4** | Feminino |

⚠️ **Diferente de PNADC 2023** (que usa 1=Homem, 2=Mulher)

### V8005 - Idade em Anos Completos

- **Tipo**: Numérico (3 dígitos)
- **Valores**: 000 a 999
- **Missing**: 999
- **Faixa útil para conjugalidade**: 15 a 90 anos

### V0303 - Raça/Cor

| Código | Descrição |
|--------|-----------|
| 2 | Branca |
| 4 | Preta |
| 6 | Amarela |
| 8 | Parda |
| 0 | Indígena |
| 9 | Sem declaração |

## Variáveis de Domicílio e Família

### V0401 - Condição no Domicílio

⚠️ **CRÍTICA PARA CONJUGALIDADE**

| Código | Descrição | Uso |
|--------|-----------|-----|
| **01** | Pessoa de referência (chefe) | Identificar referência familiar |
| **02** | Cônjuge ou companheiro(a) | **IDENTIFICAR CÔNJUGE** |
| **03** | Filho(a) ou enteado(a) | - |
| **04** | Outro parente | - |
| **05** | Agregado | - |
| **06** | Pensionista | - |
| **07** | Empregado(a) doméstico(a) | - |
| **08** | Parente do empregado(a) doméstico(a) | - |

**Para conjugalidade**: Uma pessoa tem cônjuge se existe outra pessoa no mesmo domicílio com **V0401 = 02**.

### V0402 - Condição de Casado (se disponível)

⚠️ **Verificar se existe na PNAD 2011**

Algumas versões da PNAD têm variável específica de estado civil. Se disponível:
- 1 = Casado
- 2 = Desquitado/separado judicialmente
- 3 = Divorciado
- 4 = Viúvo
- 5 = Solteiro

**Nota**: Para conjugalidade atual, usar V0401 é mais preciso (inclui união estável).

## Variáveis de Trabalho e Ocupação

### V4706 - Posição na Ocupação no Trabalho Principal

⚠️ **CRÍTICA PARA IDENTIFICAR SERVIDORES PÚBLICOS**

| Código | Descrição |
|--------|-----------|
| 01 | Empregado com carteira de trabalho assinada |
| 02 | Militar do Exército, Marinha, Aeronáutica, Polícia Militar ou Corpo de Bombeiros |
| 03 | Empregado sem carteira de trabalho assinada |
| 04 | Conta própria |
| **05** | **Empregador** |
| 06 | Trabalhador na construção para o próprio uso |
| 07 | Trabalhador na produção para o próprio consumo |
| 08 | Não remunerado em ajuda a membro do domicílio |
| 09 | Não aplicável (desocupado ou fora da força de trabalho) |

⚠️ **VERIFICAR CÓDIGO DE SERVIDOR PÚBLICO ESTATUTÁRIO**

Na PNAD 2011, pode haver variável adicional ou cruzamento necessário. Possibilidades:
- **Código 05** pode ser servidor público
- Pode ser necessário cruzar com **V4805** (setor de atividade)
- Ou usar outra variável específica

**AÇÃO NECESSÁRIA**: Verificar no dicionário oficial como identificar servidores públicos estatutários.

### V4805 - Código da Ocupação (CBO-Domiciliar)

Código de 4 dígitos da ocupação segundo CBO-Domiciliar.

### V9001 - Grupamento de Atividade

Setor econômico do trabalho principal (agricultura, indústria, serviços, etc.).

## Variáveis de Rendimento

### V4706 a V4720 (aproximadamente)

Diversas variáveis de rendimento (trabalho principal, outros trabalhos, outras fontes).

Para análise de conjugalidade, geralmente não são usadas.

## Pesos Amostrais

### V4729 - Peso da Pessoa

⚠️ **ESSENCIAL PARA ESTIMATIVAS REPRESENTATIVAS**

- **Tipo**: Numérico (14 dígitos, geralmente com 2 casas decimais)
- **Formato**: XXXXXXXXXXXX.XX ou XXXXXXXXXXXXXX (sem ponto decimal)
- **Uso**: Multiplicar cada pessoa por este peso para obter estimativas populacionais

**Exemplo**:
```julia
# Se formato é 12345678901234 (sem ponto decimal)
peso = parse(Float64, "12345678901234") / 100  # = 123456789012.34

# Se formato é 123456789012.34 (com ponto decimal)
peso = parse(Float64, "123456789012.34")  # = 123456789012.34
```

**Validação**: A soma dos pesos deve ser próxima da população brasileira em 2011 (~195 milhões).

### V4619 - Peso do Domicílio (se disponível)

Peso para análises em nível de domicílio.

## Variáveis Adicionais Úteis

### V0501 - Alfabetização

| Código | Descrição |
|--------|-----------|
| 1 | Sim |
| 2 | Não |

### V4803 - Anos de Estudo

Número de anos completos de estudo.

## Resumo: Variáveis Essenciais para Conjugalidade

| Variável | Descrição | Uso |
|----------|-----------|-----|
| **V0302** | Sexo | Segmentação por sexo |
| **V8005** | Idade | Eixo X das tábuas |
| **V0401** | Condição no domicílio | Identificar cônjuge (código 02) |
| **V4706** | Posição na ocupação | Identificar servidor público |
| **V4729** | Peso da pessoa | Ponderação das estimativas |

## Comparação com PNADC 2023

| Conceito | PNAD 2011 | PNADC 2023 |
|----------|-----------|------------|
| Sexo | V0302 (2/4) | V2007 (1/2) |
| Idade | V8005 | V2009 |
| Condição domicílio | V0401 | V2005 |
| Peso | V4729 | V1032 |
| Servidor público | V4706 (?) | V4028=5 |

## Exemplo de Uso

```julia
# Carregar dados
df = CSV.read("dados/pnad2011_processado.csv", DataFrame)

# Calcular proporção de casados (homens, 30 anos)
df_filtro = filter(row ->
    row.V0302 == 2 &&        # Masculino
    row.V8005 == 30 &&       # 30 anos
    row.V4729 > 0,           # Peso válido
    df)

# Com pesos
casados_ponderado = sum(df_filtro.V4729[df_filtro.V0401 .== 02])
total_ponderado = sum(df_filtro.V4729)
prop_casados = casados_ponderado / total_ponderado * 100

println("Homens de 30 anos casados: $(round(prop_casados, digits=1))%")
```

## Checklist de Verificação

Após download dos microdados:

- [ ] Confirmar posições das variáveis no layout FWF
- [ ] Verificar códigos de V0302 (sexo)
- [ ] Verificar códigos de V0401 (condição no domicílio)
- [ ] Identificar corretamente servidores públicos (V4706 ou outra variável)
- [ ] Confirmar formato do peso (V4729) - com ou sem ponto decimal
- [ ] Validar soma dos pesos ≈ 195 milhões
- [ ] Verificar se há variáveis adicionais úteis

## Referências

- IBGE (2012). *Dicionário de Variáveis PNAD 2011*.
- IBGE (2012). *Notas Técnicas - Microdados PNAD 2011*.

---

**Última atualização**: 2025-10-17
**Status**: ⚠️ **PLACEHOLDER** - Códigos aproximados, VERIFICAR DICIONÁRIO OFICIAL
