# Dicionário de Variáveis - PNADC 2023

## Variáveis Essenciais para Análise Demográfica

### Identificação e Estrutura

| Variável | Posição | Tam | Tipo | Descrição | Valores |
|----------|---------|-----|------|-----------|---------|
| **Ano** | 1 | 4 | String | Ano de referência | 2023 |
| **UF** | 6 | 2 | String | Unidade da Federação | 11-53 (códigos IBGE) |
| **UPA** | 12 | 9 | String | Unidade Primária de Amostragem | Único por domicílio |
| **V1008** | 28 | 2 | String | Número do domicílio | 01-99 |
| **V1014** | 30 | 2 | String | Painel | 01-99 |
| **V2003** | 90 | 2 | String | Número de ordem da pessoa | 01-99 |

**ID Composto do Domicílio**: `UPA + V1008 + V1014`
**ID Composto da Pessoa**: `UPA + V1008 + V1014 + V2003`

### Demografia

| Variável | Posição | Tam | Tipo | Descrição | Valores |
|----------|---------|-----|------|-----------|---------|
| **V2007** | 94 | 1 | Int | Sexo | 1=Homem, 2=Mulher |
| **V2009** | 103 | 3 | Int | Idade em anos completos | 0-120 |
| **V2010** | 106 | 1 | Int | Cor ou raça | 1=Branca, 2=Preta, 3=Amarela, 4=Parda, 5=Indígena |
| **V2008** | 95 | 2 | String | Dia de nascimento | 01-31 |
| **V20081** | 97 | 2 | String | Mês de nascimento | 01-12 |
| **V20082** | 99 | 4 | String | Ano de nascimento | YYYY |

### Domicílio e Relações Familiares

| Variável | Posição | Tam | Tipo | Descrição | Valores |
|----------|---------|-----|------|-----------|---------|
| **V2001** | 88 | 2 | Int | Número de pessoas no domicílio | 01-99 |
| **V2005** | 92 | 2 | String | **Condição no domicílio** | Ver tabela abaixo |

#### Códigos de V2005 (Condição no Domicílio)

| Código | Significado |
|--------|-------------|
| **01** | Pessoa responsável pelo domicílio |
| **02** | Cônjuge ou companheiro(a) de sexo diferente |
| **03** | Cônjuge ou companheiro(a) do mesmo sexo |
| **04** | Filho(a) do responsável e do cônjuge |
| **05** | Filho(a) somente do responsável |
| **06** | Enteado(a) |
| **07** | Genro ou nora |
| **08** | Pai, mãe, padrasto ou madrasta |
| **09** | Sogro(a) |
| **10** | Neto(a) ou bisneto(a) |
| **11** | Irmão ou irmã |
| **12** | Avô ou avó |
| **13** | Outro parente |
| **14** | Agregado(a) - Não parente que não compartilha despesas |
| **15** | Convivente - Não parente que compartilha despesas |
| **16** | Pensionista |
| **17** | Empregado(a) doméstico(a) |
| **18** | Parente do(a) empregado(a) doméstico(a) |

**Importante para Análise Familiar:**
- **Cônjuge**: V2005 = 02 ou 03
- **Filho**: V2005 = 04, 05 ou 06
- **Responsável**: V2005 = 01

### Trabalho e Ocupação

| Variável | Posição | Tam | Tipo | Descrição | Valores |
|----------|---------|-----|------|-----------|---------|
| **V4010** | 142 | 4 | String | Código da ocupação (CBO-Domiciliar) | 0000-9999 |
| **V4012** | 146 | 1 | String | Posição na ocupação | Ver tabela abaixo |
| **V4013** | 148 | 5 | String | Código da atividade (CNAE-Domiciliar) | 00000-99999 |
| **V4014** | 154 | 1 | String | **Área do trabalho** | Ver tabela abaixo |
| **V4028** | 183 | 1 | String | **Servidor público estatutário** | 1=Sim, 2=Não |
| **V4029** | 184 | 1 | String | Carteira de trabalho assinada | 1=Sim, 2=Não |
| **V4032** | 185 | 1 | String | Contribui para previdência | 1=Sim, 2=Não |

#### Códigos de V4012 (Posição na Ocupação)

| Código | Significado |
|--------|-------------|
| 01 | Empregado no setor privado com carteira |
| 02 | Empregado no setor privado sem carteira |
| 03 | Trabalhador doméstico com carteira |
| 04 | Trabalhador doméstico sem carteira |
| 05 | Empregado no setor público com carteira |
| 06 | Empregado no setor público sem carteira |
| 07 | Militar e funcionário público estatutário |
| 08 | Empregador |
| 09 | Conta própria (autônomo) |
| 10 | Trabalhador familiar auxiliar |

#### Códigos de V4014 (Área do Trabalho)

| Código | Significado |
|--------|-------------|
| **1** | **Municipal** |
| **2** | **Estadual** |
| **3** | **Federal** |

**⚠️ IMPORTANTE**: V4014 pode ter muitos valores missing. Ver discussão em [04_identify_servants.md](04_identify_servants.md).

### Rendimento

| Variável | Posição | Tam | Tipo | Descrição | Valores |
|----------|---------|-----|------|-----------|---------|
| **V403312** | 189 | 8 | Float | Rendimento habitual - trabalho principal | Em reais |
| **V403412** | 212 | 8 | Float | Rendimento efetivo - trabalho principal | Em reais |
| **V405012** | 262 | 8 | Float | Rendimento habitual - trabalho secundário | Em reais |
| **V405112** | 285 | 8 | Float | Rendimento efetivo - trabalho secundário | Em reais |

### Pesos Amostrais

| Variável | Posição | Tam | Tipo | Descrição | Uso |
|----------|---------|-----|------|-----------|-----|
| **V1031** | 43 | 15 | Float | Peso SEM calibração | Não usar |
| **V1032** | 58 | 15 | Float | **Peso COM calibração (Censo 2022)** | **Usar sempre** |

**IMPORTANTE**: Sempre usar **V1032** (peso com calibração) para análises estatísticas.

### Educação

| Variável | Posição | Tam | Tipo | Descrição | Valores |
|----------|---------|-----|------|-----------|---------|
| **V3001** | 107 | 1 | String | Sabe ler e escrever | 1=Sim, 2=Não |
| **V3009A** | 118 | 2 | String | Curso mais elevado que frequentou | Ver códigos IBGE |

## Variáveis Derivadas Úteis

### IDs Compostos

```julia
# ID do domicílio
domicilio_id = string(UPA, V1008, V1014)

# ID da pessoa
pessoa_id = string(UPA, V1008, V1014, V2003)
```

### Identificação de Populações

```julia
# Servidor estatutário
is_servidor = (V4028 == "1")

# Servidor por nível
is_municipal = (V4028 == "1" && V4014 == "1")
is_estadual = (V4028 == "1" && V4014 == "2")
is_federal = (V4028 == "1" && V4014 == "3")

# Tem cônjuge
tem_conjuge = (V2005 in ["02", "03"])

# É filho
eh_filho = (V2005 in ["04", "05", "06"])
```

### Grupos Etários

```julia
# Faixas etárias
faixa_etaria = if V2009 < 18
    "0-17"
elseif V2009 < 25
    "18-24"
elseif V2009 < 40
    "25-39"
elseif V2009 < 60
    "40-59"
else
    "60+"
end
```

## Códigos de Unidade da Federação (UF)

| Código | UF | Região |
|--------|-------|--------|
| 11 | Rondônia | Norte |
| 12 | Acre | Norte |
| 13 | Amazonas | Norte |
| 14 | Roraima | Norte |
| 15 | Pará | Norte |
| 16 | Amapá | Norte |
| 17 | Tocantins | Norte |
| 21 | Maranhão | Nordeste |
| 22 | Piauí | Nordeste |
| 23 | Ceará | Nordeste |
| 24 | Rio Grande do Norte | Nordeste |
| 25 | Paraíba | Nordeste |
| 26 | Pernambuco | Nordeste |
| 27 | Alagoas | Nordeste |
| 28 | Sergipe | Nordeste |
| 29 | Bahia | Nordeste |
| 31 | Minas Gerais | Sudeste |
| 32 | Espírito Santo | Sudeste |
| 33 | Rio de Janeiro | Sudeste |
| 35 | São Paulo | Sudeste |
| 41 | Paraná | Sul |
| 42 | Santa Catarina | Sul |
| 43 | Rio Grande do Sul | Sul |
| 50 | Mato Grosso do Sul | Centro-Oeste |
| 51 | Mato Grosso | Centro-Oeste |
| 52 | Goiás | Centro-Oeste |
| 53 | Distrito Federal | Centro-Oeste |

## Filtros Comuns

### Domicílios com único responsável
```julia
# Contar responsáveis por domicílio
resp_por_dom = Dict{String, Int}()
for p in pessoas
    if p.condicao_dom == 1  # 01 = Responsável
        resp_por_dom[p.domicilio_id] = get(resp_por_dom, p.domicilio_id, 0) + 1
    end
end

# Filtrar domicílios válidos (único responsável)
dominios_validos = Set(k for (k, v) in resp_por_dom if v == 1)
pessoas_filtradas = filter(p -> p.domicilio_id ∈ dominios_validos, pessoas)
```

**Por que filtrar domicílios com único responsável?**
- Evita ambiguidade no pareamento cônjuge-responsável
- Usado na análise de conjugalidade do projeto
- Ver: `conjugality/01_pnadc2023_empirical_conjugality.jl`

### Idade reprodutiva
```julia
# Mulheres em idade reprodutiva (15-49 anos)
mulheres_reprodutiva = filter(p -> p.sexo == 2 && 15 <= p.idade <= 49, pessoas)
```

### Força de trabalho
```julia
# População em idade ativa (15+ anos)
pia = filter(p -> p.idade >= 15, pessoas)
```

## Documentação Oficial

### Onde Encontrar Dicionários Completos

1. **FTP IBGE - Documentação**:
   ```
   https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_continua/Anual/Microdados/Visita/Visita_5/Documentacao/
   ```

2. **Arquivos Úteis**:
   - `dicionario_PNADC_microdados_2023_visita5.xls` - Dicionário Excel completo
   - `input_PNADC_2023_visita5.txt` - Layout SAS (incluído no zip dos dados)

3. **Notas técnicas**: Disponíveis no site do IBGE

## Observações Importantes

### Valores Missing
- Em FWF, campos vazios geralmente aparecem como espaços
- Algumas variáveis têm código específico para missing (ex: 9=Ignorado)
- Sempre validar se campo não está vazio antes de converter

### Conversão de Tipos
```julia
# String → Int
idade = parse(Int, v2009_str)

# String → Float
peso = parse(Float64, v1032_str)

# Validar antes de converter
if !isempty(v2009_str)
    idade = parse(Int, v2009_str)
end
```

### Encoding
- Arquivo usa Latin-1 (ISO-8859-1)
- Caracteres acentuados podem aparecer incorretos se usar UTF-8
- Julia lida bem com isso por padrão

## Próximos Passos

Com o dicionário em mãos:
1. **Identificar servidores**: [04_identify_servants.md](04_identify_servants.md)
2. **Análise familiar**: [05_family_composition.md](05_family_composition.md)
3. **Exemplos práticos**: [09_examples.md](09_examples.md)
