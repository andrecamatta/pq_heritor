# Integração com Modelos Demográficos Existentes

## Visão Geral

O projeto possui três modelos demográficos implementados baseados em dados de 2011. Esta skill ensina como:
1. Usar os modelos existentes
2. Comparar predições dos modelos com dados empíricos 2023
3. Decidir quando re-ajustar os modelos

## Modelos Disponíveis

### 1. Age Gap Model
**Localização**: `age_gap/age_gap_model.jl`
**Apêndice**: 6 (IBGE 2011)
**Função**: Distribuição de idade do cônjuge dado idade e sexo do indivíduo

### 2. At Least One Child Model
**Localização**: `at_least_one_child/at_least_one_child_model.jl`
**Apêndice**: 7 (IBGE 2011)
**Função**: Probabilidade de ter pelo menos um filho por idade e sexo

### 3. Youngest Child Age Model
**Localização**: `youngest_child/youngest_child_age_model.jl`
**Apêndice**: 8 (IBGE 2011)
**Função**: Distribuição da idade do filho mais novo por idade e sexo do responsável

## Uso dos Modelos

### Age Gap Model

```julia
# Carregar modelo
include("age_gap/age_gap_model.jl")

# Carregar dados de 2011 e ajustar splines
df_2011 = load_age_gap_data()
fit_gap_splines!(df_2011)

# Predizer gap médio para indivíduo
gap_homem_40 = mu_gap(40, sex=:M)  # ~3.6 anos
gap_mulher_35 = mu_gap(35, sex=:F)  # ~-2.0 anos

# Obter distribuição completa
dist = gapdist(40, sex=:M)
mean(dist)    # Média
std(dist)     # Desvio padrão
quantile(dist, 0.5)  # Mediana

# Amostrar idade de cônjuge
spouse_ages = sample_spouse_age(40, sex=:M, N=10000)
```

**Parâmetros do Modelo:**
- Spline cúbico suavizado (s=10.0)
- Distribuição: t-Student truncada
- σ_M = 3.2, σ_F = 2.8
- ν = 6.0 (graus de liberdade)

### At Least One Child Model

```julia
# Carregar modelo
include("at_least_one_child/at_least_one_child_model.jl")

# Carregar dados e ajustar modelo bi-logístico
data = load_at_least_one_child_data()
fit_models!(data)

# Avaliar probabilidade
prob_mulher_30 = prob_at_least_one_child(30, sex=:F)  # ~0.60
prob_homem_40 = prob_at_least_one_child(40, sex=:M)  # ~0.68

# Avaliar para vetor de idades
idades = 20:60
probs_f = [prob_at_least_one_child(a, sex=:F) for a in idades]
probs_m = [prob_at_least_one_child(a, sex=:M) for a in idades]
```

**Parâmetros do Modelo (2011):**
- Mulheres: θ = [0.754, 0.297, 25.1, 0.300, 51.4]
- Homens: θ = [0.710, 0.243, 27.0, 0.245, 56.8]
- RMSE: F=0.006, M=0.007

### Youngest Child Age Model

```julia
# Carregar modelo
include("youngest_child/youngest_child_age_model.jl")

# Carregar dados e ajustar
df = load_youngest_child_data()
fit_models!(df)

# Predizer idade média do filho mais novo
idade_filho_mulher_40 = mean_youngest_child(40, sex=:F)  # ~10.5 anos
idade_filho_homem_45 = mean_youngest_child(45, sex=:M)  # ~10.5 anos

# Obter parâmetros da distribuição Beta escalada
params = youngest_child_dist(40, sex=:F)
# params.α, params.β, params.U

# Amostrar idades
idades_filhos = sample_youngest_child_age(40, sex=:F, N=10000)
```

**Parâmetros do Modelo (2011):**
- Mulheres: μ_F(a) = -7.532 + 0.4425 * a (R²=0.99999)
- Homens: μ_M(a) = -9.030 + 0.4377 * a (R²=0.99928)
- Precisão φ = 16.0
- Suporte: [0, 30 anos]

## Comparação: Modelo vs Dados 2023

### Metodologia Geral

```julia
# 1. Calcular predições do modelo (ajustado em 2011)
idades = 20:80
pred_modelo = [funcao_modelo(a, params_2011) for a in idades]

# 2. Calcular valores empíricos de 2023
empirico_2023 = calcular_empirico_2023(dados_2023)

# 3. Comparar
rmse = sqrt(mean((pred_modelo .- empirico_2023).^2))
mae = mean(abs.(pred_modelo .- empirico_2023))

# 4. Visualizar
plot(idades, pred_modelo, label="Modelo 2011")
scatter!(idades, empirico_2023, label="Empírico 2023")
```

### Comparação: Age Gap

```julia
using DataFrames, CSV, Statistics, Plots

# Modelo (2011)
include("age_gap/age_gap_model.jl")
df_2011 = load_age_gap_data()
fit_gap_splines!(df_2011)

# Dados empíricos 2023
pessoas_2023 = ler_pnadc("../data_pnadc2023/PNADC_2023_visita5.txt")
casais_2023 = identificar_casais(pessoas_2023)
df_gap_2023 = age_gap_ponderado_por_idade_sexo(casais_2023)

# Comparar
idades = 25:65

# Homens
gap_modelo_m = [mu_gap(a, sex=:M) for a in idades]
df_obs_m = filter(r -> r.sexo == 1, df_gap_2023)

plot(idades, gap_modelo_m,
     label="Modelo 2011 (Homens)",
     color=:blue,
     linestyle=:dash,
     linewidth=2,
     xlabel="Idade",
     ylabel="Age gap médio (anos)",
     title="Comparação: Modelo 2011 vs Empírico 2023")

scatter!(df_obs_m.idade, df_obs_m.age_gap_medio,
         label="Observado 2023 (Homens)",
         color=:blue,
         markersize=4)

# Mulheres
gap_modelo_f = [mu_gap(a, sex=:F) for a in idades]
df_obs_f = filter(r -> r.sexo == 2, df_gap_2023)

plot!(idades, gap_modelo_f,
      label="Modelo 2011 (Mulheres)",
      color=:red,
      linestyle=:dash,
      linewidth=2)

scatter!(df_obs_f.idade, df_obs_f.age_gap_medio,
         label="Observado 2023 (Mulheres)",
         color=:red,
         markersize=4)

savefig("comparacao_age_gap_2011_vs_2023.png")
```

### Comparação: Fertilidade

```julia
# Modelo (2011)
include("at_least_one_child/at_least_one_child_model.jl")
data = load_at_least_one_child_data()
fit_models!(data)

# Dados empíricos 2023
df_fert_2023 = prob_ter_filho_por_idade_sexo(pessoas_2023)

# Comparar
idades = 18:65

# Predições do modelo
prob_modelo_f = [prob_at_least_one_child(a, sex=:F) for a in idades]
prob_modelo_m = [prob_at_least_one_child(a, sex=:M) for a in idades]

# Empírico 2023
df_obs_f = filter(r -> r.sexo == 2 && !ismissing(r.prob_filho), df_fert_2023)
df_obs_m = filter(r -> r.sexo == 1 && !ismissing(r.prob_filho), df_fert_2023)

# Plot
plot(idades, prob_modelo_f,
     label="Modelo 2011 (Mulheres)",
     color=:red,
     linestyle=:dash,
     linewidth=2,
     xlabel="Idade",
     ylabel="P(tem filho)",
     title="Comparação: Fertilidade 2011 vs 2023")

scatter!(df_obs_f.idade, df_obs_f.prob_filho,
         label="Observado 2023 (Mulheres)",
         color=:red,
         markersize=4)

# Similar para homens...
```

### Comparação: Idade do Filho Mais Novo

```julia
# Modelo (2011)
include("youngest_child/youngest_child_age_model.jl")
df = load_youngest_child_data()
fit_models!(df)

# Dados empíricos 2023
df_filho_2023 = idade_filho_mais_novo_por_responsavel(pessoas_2023)

# Agregar por idade e sexo
df_agg_2023 = combine(
    groupby(df_filho_2023, [:idade_resp, :sexo_resp]),
    [:idade_filho_mais_novo, :peso] => ((idades, pesos) ->
        sum(idades .* pesos) / sum(pesos)) => :media_ponderada
)

# Comparar
idades = 20:60

# Predições do modelo
pred_f = [mean_youngest_child(a, sex=:F) for a in idades]
pred_m = [mean_youngest_child(a, sex=:M) for a in idades]

# Empírico 2023
df_obs_f = filter(r -> r.sexo_resp == 2, df_agg_2023)
df_obs_m = filter(r -> r.sexo_resp == 1, df_agg_2023)

# Plot
plot(idades, pred_f,
     label="Modelo 2011 (Mulheres)",
     color=:red,
     linestyle=:dash,
     linewidth=2)

scatter!(df_obs_f.idade_resp, df_obs_f.media_ponderada,
         label="Observado 2023 (Mulheres)",
         color=:red,
         markersize=4)

# Similar para homens...
```

## Métricas de Comparação

### RMSE e MAE

```julia
function calcular_metricas(pred, obs)
    """
    Calcula RMSE e MAE entre predições e observações.
    """
    # Alinhar por idade
    idades_comuns = intersect(pred.idade, obs.idade)

    pred_aligned = [pred[pred.idade .== a, :valor][1] for a in idades_comuns]
    obs_aligned = [obs[obs.idade .== a, :valor][1] for a in idades_comuns]

    rmse = sqrt(mean((pred_aligned .- obs_aligned).^2))
    mae = mean(abs.(pred_aligned .- obs_aligned))
    max_diff = maximum(abs.(pred_aligned .- obs_aligned))

    return (rmse=rmse, mae=mae, max_diff=max_diff)
end
```

### R² de Correlação

```julia
function calcular_r2(pred, obs)
    """
    Calcula R² entre predições e observações.
    """
    idades_comuns = intersect(pred.idade, obs.idade)

    pred_aligned = [pred[pred.idade .== a, :valor][1] for a in idades_comuns]
    obs_aligned = [obs[obs.idade .== a, :valor][1] for a in idades_comuns]

    # R² = 1 - SS_res / SS_tot
    ss_res = sum((obs_aligned .- pred_aligned).^2)
    ss_tot = sum((obs_aligned .- mean(obs_aligned)).^2)

    r2 = 1 - ss_res / ss_tot
    return r2
end
```

## Quando Re-ajustar os Modelos?

### Critérios de Decisão

**✓ Re-ajustar se:**
1. **RMSE > 0.05** (para probabilidades) ou **MAE > 3 anos** (para idades)
2. **Mudança estrutural visível** nos dados (ex: curva mudou de forma)
3. **R² < 0.90** entre modelo e dados 2023
4. **Viés sistemático** (modelo sempre superestima ou subestima)

**✗ Manter modelo se:**
1. **Diferenças pequenas** (RMSE < 0.02, MAE < 1 ano)
2. **Variação dentro do esperado** estatisticamente
3. **Tendência geral preservada**

### Exemplo: Decisão para Conjugalidade

Do relatório `conjugality/RELATORIO_PNADC2023.md`:

> **Principais Descobertas**
> 1. **Queda massiva na conjugalidade** em todas as faixas etárias
> 2. **Mulheres**: redução média de **-22.5 pontos percentuais**
> 3. **Homens**: redução média de **-45.2 pontos percentuais**

**Conclusão**: ✓ **RE-AJUSTAR NECESSÁRIO** - Mudança estrutural dramática.

## Re-ajuste de Modelos

### Age Gap Model

```julia
# 1. Preparar dados 2023 no formato esperado
df_gap_2023 = age_gap_ponderado_por_idade_sexo(casais_2023)

# Converter para formato do modelo
df_input = DataFrame(
    idade = vcat(df_gap_2023[df_gap_2023.sexo .== 1, :idade],
                 df_gap_2023[df_gap_2023.sexo .== 2, :idade]),
    gap_medio_homem = vcat(df_gap_2023[df_gap_2023.sexo .== 1, :age_gap_medio],
                           fill(missing, sum(df_gap_2023.sexo .== 2))),
    gap_medio_mulher = vcat(fill(missing, sum(df_gap_2023.sexo .== 1)),
                            df_gap_2023[df_gap_2023.sexo .== 2, :age_gap_medio])
)

# 2. Re-ajustar splines
fit_gap_splines!(df_input)

# 3. Salvar novo modelo
# (Ajustar código do modelo para exportar parâmetros)
```

### At Least One Child Model

```julia
# 1. Preparar dados 2023
df_fert_2023 = tabela_fertilidade(pessoas_2023)

# 2. Re-ajustar modelo bi-logístico
# (Ver código em at_least_one_child_model.jl)
θ0_f = [0.75, 0.30, 25.0, 0.30, 51.0]
θ0_m = [0.71, 0.24, 27.0, 0.25, 57.0]

result_f = fit_bilogistic(
    df_fert_2023[!ismissing.(df_fert_2023.mulher), :idade],
    df_fert_2023[!ismissing.(df_fert_2023.mulher), :mulher],
    θ0=θ0_f,
    lower=[0.1, 0.001, 10.0, 0.001, 20.0],
    upper=[0.999, 2.0, 40.0, 1.0, 80.0]
)

# Parâmetros atualizados
θ_new_f = result_f.param
println("Novos parâmetros (Mulheres): $θ_new_f")
println("RMSE: $(result_f.rmse)")
```

### Youngest Child Age Model

```julia
# 1. Preparar dados 2023
df_filho_2023 = idade_filho_mais_novo_por_responsavel(pessoas_2023)

# Agregar por idade e sexo
df_agg = combine(
    groupby(df_filho_2023, [:idade_resp, :sexo_resp]),
    [:idade_filho_mais_novo, :peso] => ((idades, pesos) ->
        sum(idades .* pesos) / sum(pesos)) => :media_ponderada
)

# 2. Re-ajustar regressão linear
using GLM

df_f = filter(r -> r.sexo_resp == 2, df_agg)
lm_F_new = lm(@formula(media_ponderada ~ idade_resp), df_f)

df_m = filter(r -> r.sexo_resp == 1, df_agg)
lm_M_new = lm(@formula(media_ponderada ~ idade_resp), df_m)

# Novos parâmetros
coef_f = coef(lm_F_new)
coef_m = coef(lm_M_new)

println("Novos parâmetros (Mulheres): μ_F(a) = $(coef_f[1]) + $(coef_f[2]) * a")
println("Novos parâmetros (Homens): μ_M(a) = $(coef_m[1]) + $(coef_m[2]) * a")
```

## Aplicação dos Modelos em Simulações

### Exemplo: Gerar População Sintética

```julia
# Carregar modelos
include("age_gap/age_gap_model.jl")
include("at_least_one_child/at_least_one_child_model.jl")
include("youngest_child/youngest_child_age_model.jl")

# Ajustar com dados 2011 (ou 2023 se re-ajustados)
# ...

# Gerar indivíduo sintético
idade = 40
sexo = :F

# 1. Tem cônjuge?
prob_conj = 0.45  # Da tabela de conjugalidade
tem_conjuge = rand() < prob_conj

# 2. Se tem, qual a idade do cônjuge?
if tem_conjuge
    idade_conjuge = idade + sample_spouse_age(idade, sex=sexo, N=1)[1]
end

# 3. Tem filho?
prob_filho = prob_at_least_one_child(idade, sex=sexo)
tem_filho = rand() < prob_filho

# 4. Se tem, idade do filho mais novo?
if tem_filho
    idade_filho = sample_youngest_child_age(idade, sex=sexo, N=1)[1]
end

println("Indivíduo sintético:")
println("  Idade: $idade, Sexo: $sexo")
println("  Tem cônjuge: $tem_conjuge")
if tem_conjuge
    println("  Idade cônjuge: $idade_conjuge")
end
println("  Tem filho: $tem_filho")
if tem_filho
    println("  Idade filho mais novo: $idade_filho")
end
```

## Próximos Passos

Com os modelos integrados:
1. **Ver exemplos completos**: [09_examples.md](09_examples.md)
2. **Comparar modelos**: Documentado em `conjugality/RELATORIO_PNADC2023.md`
3. **Aplicar em simulações**: Usar modelos para gerar populações sintéticas
