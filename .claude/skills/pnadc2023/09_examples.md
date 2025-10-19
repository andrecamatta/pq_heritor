# Exemplos Práticos - PNADC 2023

## Visão Geral

Este skill apresenta exemplos completos e funcionais de análise com PNADC 2023, desde o download até a geração de relatórios.

## Exemplo 1: Pipeline Completo de Análise

### Objetivo
Analisar conjugalidade, fertilidade e composição familiar da população brasileira em 2023.

### Código Completo

```julia
#!/usr/bin/env julia
#
# example_01_full_pipeline.jl
# Pipeline completo de análise PNADC 2023
#

using DataFrames
using CSV
using Statistics
using Printf

# ============================================================================
# PASSO 1: PARSER
# ============================================================================

println("="^70)
println("PIPELINE COMPLETO - PNADC 2023")
println("="^70)
println()

# Constantes FWF
const POS_UPA = 12
const LEN_UPA = 9
const POS_V1008 = 28
const LEN_V1008 = 2
const POS_V1014 = 30
const LEN_V1014 = 2
const POS_V1032 = 58
const LEN_V1032 = 15
const POS_V2003 = 90
const LEN_V2003 = 2
const POS_V2005 = 92
const LEN_V2005 = 2
const POS_V2007 = 94
const LEN_V2007 = 1
const POS_V2009 = 103
const LEN_V2009 = 3

struct Pessoa
    domicilio_id::String
    pessoa_id::String
    idade::Int
    sexo::Int
    condicao_dom::Int
    peso::Float64
end

function extrair_campo(linha::String, pos::Int, len::Int)
    if length(linha) < pos + len - 1
        return ""
    end
    return strip(linha[pos:pos+len-1])
end

function ler_pnadc(arquivo::String)
    pessoas_local = Pessoa[]
    n_linhas = 0

    open(arquivo, "r") do f
        for linha in eachline(f)
            n_linhas += 1

            if n_linhas % 100_000 == 0
                print("\rLinhas processadas: $(n_linhas ÷ 1000)k")
            end

            try
                upa = extrair_campo(linha, POS_UPA, LEN_UPA)
                v1008 = extrair_campo(linha, POS_V1008, LEN_V1008)
                v1014 = extrair_campo(linha, POS_V1014, LEN_V1014)
                v2003 = extrair_campo(linha, POS_V2003, LEN_V2003)
                v2005_str = extrair_campo(linha, POS_V2005, LEN_V2005)
                v2007_str = extrair_campo(linha, POS_V2007, LEN_V2007)
                v2009_str = extrair_campo(linha, POS_V2009, LEN_V2009)
                v1032_str = extrair_campo(linha, POS_V1032, LEN_V1032)

                if isempty(upa) || isempty(v2007_str) || isempty(v2009_str)
                    continue
                end

                idade = parse(Int, v2009_str)
                sexo = parse(Int, v2007_str)
                condicao = parse(Int, v2005_str)
                peso = parse(Float64, v1032_str)

                if sexo ∉ [1, 2] || idade < 0 || idade > 120 || peso <= 0
                    continue
                end

                domicilio_id = string(upa, v1008, v1014)
                pessoa_id = string(domicilio_id, v2003)

                push!(pessoas_local, Pessoa(domicilio_id, pessoa_id, idade, sexo, condicao, peso))
            catch e
                continue
            end
        end
    end

    println()
    return pessoas_local
end

# ============================================================================
# PASSO 2: CARREGAR DADOS
# ============================================================================

println("[1/5] Carregando dados PNADC 2023...")
data_file = "../data_pnadc2023/PNADC_2023_visita5.txt"
pessoas = ler_pnadc(data_file)

println("Total de pessoas: $(length(pessoas))")
println("População ponderada: $(round(Int, sum(p.peso for p in pessoas)))")
println()

# ============================================================================
# PASSO 3: ANÁLISE DE CONJUGALIDADE
# ============================================================================

println("[2/5] Analisando conjugalidade...")

# Filtrar domicílios com único responsável
resp_por_dom = Dict{String, Int}()
for p in pessoas
    if p.condicao_dom == 1
        resp_por_dom[p.domicilio_id] = get(resp_por_dom, p.domicilio_id, 0) + 1
    end
end

dominios_validos = Set(k for (k, v) in resp_por_dom if v == 1)
pessoas_filtradas = filter(p -> p.domicilio_id ∈ dominios_validos, pessoas)

println("Domicílios válidos: $(length(dominios_validos))")
println("Pessoas em domicílios válidos: $(length(pessoas_filtradas))")

# Calcular conjugalidade
contadores_conj = Dict{Tuple{Int, Int}, Tuple{Float64, Float64}}()

for p in pessoas_filtradas
    key = (p.idade, p.sexo)
    em_uniao = (p.condicao_dom in [2, 3])

    if haskey(contadores_conj, key)
        n_conj, n_tot = contadores_conj[key]
        contadores_conj[key] = (
            n_conj + (em_uniao ? p.peso : 0.0),
            n_tot + p.peso
        )
    else
        contadores_conj[key] = (
            em_uniao ? p.peso : 0.0,
            p.peso
        )
    end
end

# Criar DataFrame
idades = sort(unique([k[1] for k in keys(contadores_conj)]))

df_conj = DataFrame(
    idade = Int[],
    mulher = Union{Float64, Missing}[],
    homem = Union{Float64, Missing}[]
)

for idade in idades
    prob_f = haskey(contadores_conj, (idade, 2)) ?
             contadores_conj[(idade, 2)][1] / contadores_conj[(idade, 2)][2] :
             missing

    prob_m = haskey(contadores_conj, (idade, 1)) ?
             contadores_conj[(idade, 1)][1] / contadores_conj[(idade, 1)][2] :
             missing

    push!(df_conj, (idade, prob_f, prob_m))
end

CSV.write("conjugalidade_2023.csv", df_conj)
println("✓ Tabela de conjugalidade salva")
println()

# ============================================================================
# PASSO 4: ANÁLISE DE FERTILIDADE
# ============================================================================

println("[3/5] Analisando fertilidade...")

# Identificar filhos por domicílio
filhos_por_dom = Dict{String, Vector{Pessoa}}()
for p in pessoas
    if p.condicao_dom in [4, 5, 6]
        if !haskey(filhos_por_dom, p.domicilio_id)
            filhos_por_dom[p.domicilio_id] = Pessoa[]
        end
        push!(filhos_por_dom[p.domicilio_id], p)
    end
end

println("Domicílios com filhos: $(length(filhos_por_dom))")

# Calcular probabilidade de ter filho
contadores_fert = Dict{Tuple{Int, Int}, Tuple{Float64, Float64}}()

for p in pessoas
    if p.condicao_dom in [1, 2, 3]  # Responsável ou cônjuge
        key = (p.idade, p.sexo)
        tem_filho = haskey(filhos_por_dom, p.domicilio_id) &&
                   !isempty(filhos_por_dom[p.domicilio_id])

        if haskey(contadores_fert, key)
            n_com, n_tot = contadores_fert[key]
            contadores_fert[key] = (
                n_com + (tem_filho ? p.peso : 0.0),
                n_tot + p.peso
            )
        else
            contadores_fert[key] = (
                tem_filho ? p.peso : 0.0,
                p.peso
            )
        end
    end
end

# Criar DataFrame
idades_fert = sort(unique([k[1] for k in keys(contadores_fert)]))

df_fert = DataFrame(
    idade = Int[],
    mulher = Union{Float64, Missing}[],
    homem = Union{Float64, Missing}[]
)

for idade in idades_fert
    prob_f = haskey(contadores_fert, (idade, 2)) ?
             contadores_fert[(idade, 2)][1] / contadores_fert[(idade, 2)][2] :
             missing

    prob_m = haskey(contadores_fert, (idade, 1)) ?
             contadores_fert[(idade, 1)][1] / contadores_fert[(idade, 1)][2] :
             missing

    push!(df_fert, (idade, prob_f, prob_m))
end

CSV.write("fertilidade_2023.csv", df_fert)
println("✓ Tabela de fertilidade salva")
println()

# ============================================================================
# PASSO 5: RELATÓRIO RESUMO
# ============================================================================

println("[4/5] Gerando estatísticas resumo...")

# População
peso_f = sum(p.peso for p in filter(p -> p.sexo == 2, pessoas))
peso_m = sum(p.peso for p in filter(p -> p.sexo == 1, pessoas))
pct_f = peso_f / (peso_f + peso_m) * 100

println("POPULAÇÃO:")
println("  Total: $(round(Int, peso_f + peso_m)) pessoas")
println("  Mulheres: $(round(Int, peso_f)) ($(round(pct_f, digits=1))%)")
println("  Homens: $(round(Int, peso_m)) ($(round(100-pct_f, digits=1))%)")
println()

# Conjugalidade - pico
max_conj_f = maximum(skipmissing(df_conj.mulher))
idade_max_f = df_conj[findfirst(==(max_conj_f), df_conj.mulher), :idade]

max_conj_m = maximum(skipmissing(df_conj.homem))
idade_max_m = df_conj[findfirst(==(max_conj_m), df_conj.homem), :idade]

println("CONJUGALIDADE:")
println("  Pico mulheres: $(round(max_conj_f*100, digits=1))% aos $idade_max_f anos")
println("  Pico homens: $(round(max_conj_m*100, digits=1))% aos $idade_max_m anos")
println()

# Fertilidade - pico
max_fert_f = maximum(skipmissing(df_fert.mulher))
idade_fert_f = df_fert[findfirst(==(max_fert_f), df_fert.mulher), :idade]

max_fert_m = maximum(skipmissing(df_fert.homem))
idade_fert_m = df_fert[findfirst(==(max_fert_m), df_fert.homem), :idade]

println("FERTILIDADE:")
println("  Pico mulheres: $(round(max_fert_f*100, digits=1))% aos $idade_fert_f anos")
println("  Pico homens: $(round(max_fert_m*100, digits=1))% aos $idade_fert_m anos")
println()

println("[5/5] ✓ Análise concluída!")
println()
println("="^70)
println("ARQUIVOS GERADOS:")
println("  - conjugalidade_2023.csv")
println("  - fertilidade_2023.csv")
println("="^70)
```

### Como Executar

```bash
cd /path/to/project
julia example_01_full_pipeline.jl
```

## Exemplo 2: Análise Específica de Servidores

### Objetivo
Comparar perfil demográfico de servidores públicos vs população geral.

### Código

```julia
#!/usr/bin/env julia
#
# example_02_servants_analysis.jl
#

using DataFrames, CSV, Statistics

# [Incluir parser do Exemplo 1]
# ...

println("[1/3] Carregando dados...")
pessoas = ler_pnadc("../data_pnadc2023/PNADC_2023_visita5.txt")

println("[2/3] Identificando servidores...")
# Nota: precisaríamos adicionar V4028 ao parser

servidores = filter(p -> !ismissing(p.servidor) && p.servidor == 1, pessoas)
println("Servidores identificados: $(length(servidores))")

println("[3/3] Comparando perfis...")

# População geral
idade_media_geral = mean(p.idade for p in pessoas)
pct_mulher_geral = sum(p.peso for p in filter(p -> p.sexo == 2, pessoas)) /
                   sum(p.peso for p in pessoas) * 100

# Servidores
idade_media_serv = mean(p.idade for p in servidores)
pct_mulher_serv = sum(p.peso for p in filter(p -> p.sexo == 2, servidores)) /
                  sum(p.peso for p in servidores) * 100

println("\nCOMPARAÇÃO:")
println("  Idade média:")
println("    População geral: $(round(idade_media_geral, digits=1)) anos")
println("    Servidores: $(round(idade_media_serv, digits=1)) anos")
println()
println("  % Mulheres:")
println("    População geral: $(round(pct_mulher_geral, digits=1))%")
println("    Servidores: $(round(pct_mulher_serv, digits=1))%")
```

## Exemplo 3: Age Gap Analysis

### Objetivo
Analisar diferença de idade entre cônjuges.

**Arquivo de referência**: `conjugality/03_age_gap_pnadc2023.jl`

### Uso

```bash
cd conjugality
julia 03_age_gap_pnadc2023.jl
```

### Outputs
- `age_gaps_2023.csv` - Todos os casais com age gap
- `age_gaps_2023_summary.csv` - Estatísticas por tipo de casal

## Exemplo 4: Comparação com Modelos 2011

### Objetivo
Comparar dados empíricos 2023 com predições de modelos ajustados em 2011.

### Código

```julia
#!/usr/bin/env julia
#
# example_04_compare_with_models.jl
#

using DataFrames, CSV, Statistics, Plots

# Carregar modelo de fertilidade
include("at_least_one_child/at_least_one_child_model.jl")
data = load_at_least_one_child_data()
fit_models!(data)

# Carregar dados 2023
# [Parser...]
df_fert_2023 = prob_ter_filho_por_idade_sexo(pessoas)

# Comparar
idades = 20:60

# Predições do modelo (2011)
pred_f = [prob_at_least_one_child(a, sex=:F) for a in idades]

# Observado 2023
obs_f = filter(r -> r.sexo == 2 && !ismissing(r.prob_filho), df_fert_2023)

# Calcular diferença
rmse = sqrt(mean((pred_f .- obs_f.prob_filho).^2))
mae = mean(abs.(pred_f .- obs_f.prob_filho))

println("RMSE: $(round(rmse, digits=4))")
println("MAE: $(round(mae, digits=4))")

# Plot
plot(idades, pred_f,
     label="Modelo 2011",
     linewidth=2,
     linestyle=:dash,
     color=:red)

scatter!(obs_f.idade, obs_f.prob_filho,
         label="Observado 2023",
         color=:red,
         markersize=4,
         xlabel="Idade",
         ylabel="P(tem filho)",
         title="Fertilidade: Modelo 2011 vs Observado 2023")

savefig("comparacao_fertilidade_2011_2023.png")
```

## Exemplo 5: Teste Rápido com Subset

### Objetivo
Testar código rapidamente com apenas primeiras 50k linhas.

### Código

```julia
function ler_pnadc_subset(arquivo::String, max_linhas::Int=50_000)
    """Ler apenas primeiras N linhas para teste"""
    pessoas_local = Pessoa[]
    n_linhas = 0

    open(arquivo, "r") do f
        for linha in eachline(f)
            n_linhas += 1

            if n_linhas > max_linhas
                break
            end

            # [Mesmo parsing do exemplo 1]
            # ...
        end
    end

    return pessoas_local
end

# Uso
println("Teste rápido com subset...")
pessoas_teste = ler_pnadc_subset("../data_pnadc2023/PNADC_2023_visita5.txt", 50_000)
println("Pessoas carregadas: $(length(pessoas_teste))")

# Análises rápidas...
```

## Exemplo 6: Export para Outros Formatos

### Para Python

```julia
using Arrow

# Converter para Arrow (compatível com Pandas/Polars)
df = DataFrame(pessoas)
Arrow.write("pnadc2023.arrow", df)
```

**Uso em Python:**
```python
import pyarrow.feather as feather
import pandas as pd

df = feather.read_feather("pnadc2023.arrow")
```

### Para R

```julia
using RData

# Salvar em formato RData
df = DataFrame(pessoas)
save("pnadc2023.RData", Dict("pessoas" => df))
```

## Troubleshooting Comum

### Problema: Arquivo muito grande, memória insuficiente

**Solução**: Processar em chunks

```julia
function processar_em_chunks(arquivo::String, chunk_size::Int=100_000)
    contadores = Dict()

    open(arquivo, "r") do f
        chunk = []
        for (i, linha) in enumerate(eachline(f))
            push!(chunk, linha)

            if length(chunk) >= chunk_size
                # Processar chunk
                processar_chunk(chunk, contadores)
                empty!(chunk)
            end
        end

        # Processar último chunk
        if !isempty(chunk)
            processar_chunk(chunk, contadores)
        end
    end

    return contadores
end
```

### Problema: Performance lenta

**Soluções**:
1. Usar `@inbounds` em loops críticos
2. Pre-alocar vetores
3. Evitar closures desnecessárias
4. Compilar com `--optimize=3`

### Problema: Encoding de caracteres

**Solução**: Especificar encoding

```julia
using StringEncodings

open(arquivo, enc"ISO-8859-1") do f
    # Processar...
end
```

## Scripts Prontos no Projeto

### Conjugalidade
- `conjugality/01_pnadc2023_empirical_conjugality.jl` - Análise completa
- `conjugality/02_compare_2011_vs_2023.jl` - Comparação temporal
- `conjugality/03_age_gap_pnadc2023.jl` - Age gap

### Download
- `conjugality/00_download_pnadc2023.sh` - Download automatizado

### Documentação
- `conjugality/RELATORIO_PNADC2023.md` - Relatório de evolução 2011→2023
- `README_metodologia.md` - Metodologia do projeto completo

## Checklist de Análise

Antes de publicar resultados:

- [ ] Verificar peso total (~203 milhões)
- [ ] Verificar distribuição por sexo (~51-52% mulheres)
- [ ] Validar idades plausíveis (0-120 anos)
- [ ] Verificar missing values
- [ ] Documentar filtros aplicados
- [ ] Comparar com fontes externas (Censo, IBGE)
- [ ] Gerar visualizações
- [ ] Salvar outputs em CSV
- [ ] Documentar limitações

## Recursos Adicionais

### Pacotes Julia Úteis
- `DataFrames.jl` - Manipulação de dados
- `CSV.jl` - Leitura/escrita CSV
- `Statistics.jl` - Estatísticas básicas
- `Plots.jl` - Visualizações
- `GLM.jl` - Modelos lineares
- `Distributions.jl` - Distribuições de probabilidade
- `LsqFit.jl` - Ajuste de curvas

### Documentação IBGE
- FTP: https://ftp.ibge.gov.br/
- Site oficial: https://www.ibge.gov.br/
- Dicionários de variáveis no FTP

### Contato
Para questões específicas do projeto, consulte:
- `README_metodologia.md`
- Scripts em `conjugality/`
- Skills em `.claude/skills/pnadc2023/`
