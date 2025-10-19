#!/usr/bin/env julia
# ⚠️  ARQUIVO OBSOLETO - Substituído por 09_age_gap_servidores.jl
# ⚠️  Mantido apenas para referência histórica. NÃO USE EM PRODUÇÃO!
#
# Análise de Age Gap (Diferença de Idade entre Cônjuges)
# Essencial para cálculo da função heritor (idade esperada do beneficiário)

using CSV
using DataFrames
using Statistics
using StatsBase
using PrettyTables
using Printf
using Plots
using Random

println("=" ^ 70)
println("Análise de Age Gap - Diferença de Idade entre Cônjuges")
println("=" ^ 70)

# Carregar dados processados
DADOS_DIR = "dados"
RESULTADOS_DIR = "resultados"
mkpath(RESULTADOS_DIR)

arquivo_dados = joinpath(DADOS_DIR, "pnadc_2023_processado.csv")

if !isfile(arquivo_dados)
    println("\nERRO: Arquivo não encontrado: $arquivo_dados")
    println("Execute primeiro: julia 01_processar_dados.jl")
    exit(1)
end

println("\nCarregando dados...")
df = CSV.read(arquivo_dados, DataFrame)

println("Total de registros: $(nrow(df))")

# === IDENTIFICAR PARES DE CÔNJUGES ===

println("\nIdentificando pares de cônjuges no domicílio...")

# Verificar se os dados têm as variáveis necessárias
if !(:V2005 in names(df)) && !(:condicao_dom in names(df))
    println("\nERRO: Variável de condição no domicílio não encontrada!")
    println("Os dados precisam ter V2005 (PNADC 2023) ou condicao_dom processada.")
    println("Execute primeiro: julia 01_processar_dados.jl com dados reais")
    exit(1)
end

# Usar V2005 se disponível, senão usar condicao_dom
if :V2005 in names(df)
    df.condicao_dom = df.V2005
end

# Verificar se há variáveis de identificação do domicílio
# Para PNADC 2023: UF, UPA, V1008, V1014
# Criar ID único do domicílio
if :UF in names(df) && :V1008 in names(df)
    df.domicilio_id = string.(df.UF) .* "_" .* string.(df.V1008)
else
    println("\nAVISO: Variáveis de identificação do domicílio não encontradas")
    println("Não será possível parear cônjuges corretamente.")
    println("Usando identificação sequencial (apenas para teste)")
    df.domicilio_id = string.(1:nrow(df))
end

# Extrair pares
function extrair_pares_conjuges(df::DataFrame)
    """
    Extrai pares de cônjuges (chefe + cônjuge) com diferenças de idade

    Usa estrutura domiciliar real da PNADC (V2005):
    - Código 01: Pessoa de referência (chefe)
    - Código 02: Cônjuge de sexo diferente
    - Código 03: Cônjuge de mesmo sexo
    """

    pares = DataFrame(
        domicilio_id = String[],
        idade_ref = Int[],
        sexo_ref = Int[],
        idade_conj = Int[],
        sexo_conj = Int[],
        age_gap = Int[],
        servidor_ref = Bool[],
        servidor_conj = Bool[],
        peso = Float64[]
    )

    # Agrupar por domicílio
    for dom_id in unique(df.domicilio_id)
        pessoas = filter(row -> row.domicilio_id == dom_id, df)

        # Identificar pessoa de referência (condicao_dom = 01 ou 1)
        ref = filter(row -> row.condicao_dom == 1 || row.condicao_dom == 01, pessoas)
        if nrow(ref) == 0
            continue  # Sem pessoa de referência
        end
        ref = ref[1, :]  # Pegar primeira se houver múltiplas

        # Identificar cônjuge (condicao_dom = 02, 03 ou 2, 3)
        conj = filter(row -> row.condicao_dom in [2, 3, 02, 03], pessoas)
        if nrow(conj) == 0
            continue  # Sem cônjuge
        end
        conj = conj[1, :]  # Pegar primeiro se houver múltiplos

        # Adicionar par
        push!(pares, (
            dom_id,
            ref.idade,
            ref.sexo,
            conj.idade,
            conj.sexo,
            ref.idade - conj.idade,  # Age gap (positivo = ref mais velho)
            ref.servidor,
            conj.servidor,
            ref.peso
        ))
    end

    return pares
end

println("\nExtraindo pares...")
pares = extrair_pares_conjuges(df)

println("Total de pares identificados: $(nrow(pares))")
println("  Com peso ponderado: $(round(sum(pares.peso) / 1_000_000, digits=2)) milhões de casais")

# === ESTATÍSTICAS DESCRITIVAS ===

println("\n" * "=" ^ 70)
println("ESTATÍSTICAS DE AGE GAP")
println("=" ^ 70)

# Média e desvio-padrão (ponderado)
age_gap_medio_pond = sum(pares.age_gap .* pares.peso) / sum(pares.peso)
age_gap_var_pond = sum((pares.age_gap .- age_gap_medio_pond).^2 .* pares.peso) / sum(pares.peso)
age_gap_sd_pond = sqrt(age_gap_var_pond)

println("\nGeral (ponderado):")
println("  Média: $(round(age_gap_medio_pond, digits=2)) anos")
println("  Desvio-padrão: $(round(age_gap_sd_pond, digits=2)) anos")
println("  Mediana (não-ponderada): $(median(pares.age_gap)) anos")
println("  Mínimo: $(minimum(pares.age_gap)) anos")
println("  Máximo: $(maximum(pares.age_gap)) anos")

# Percentis
println("\nPercentis:")
for p in [10, 25, 50, 75, 90]
    val = quantile(pares.age_gap, p/100)
    println("  P$p: $(round(val, digits=1)) anos")
end

# Por sexo da referência
println("\n" * "=" ^ 70)
println("AGE GAP POR SEXO DA REFERÊNCIA")
println("=" ^ 70)

for sexo_val in [1, 2]
    sexo_label = sexo_val == 1 ? "Masculino (referência)" : "Feminino (referência)"
    println("\n$sexo_label:")

    pares_sexo = filter(row -> row.sexo_ref == sexo_val, pares)

    if nrow(pares_sexo) == 0
        println("  Sem dados")
        continue
    end

    media = sum(pares_sexo.age_gap .* pares_sexo.peso) / sum(pares_sexo.peso)
    sd = sqrt(sum((pares_sexo.age_gap .- media).^2 .* pares_sexo.peso) / sum(pares_sexo.peso))

    println("  N (pares): $(nrow(pares_sexo))")
    println("  Média: $(round(media, digits=2)) anos")
    println("  Desvio-padrão: $(round(sd, digits=2)) anos")
    println("  Mediana: $(median(pares_sexo.age_gap)) anos")
end

# === AGE GAP POR IDADE DA REFERÊNCIA ===

println("\n" * "=" ^ 70)
println("AGE GAP POR IDADE E SEXO DA REFERÊNCIA")
println("=" ^ 70)

# Agrupar por idade da referência (a cada 5 anos)
faixas_etarias = [
    (20, 24), (25, 29), (30, 34), (35, 39), (40, 44),
    (45, 49), (50, 54), (55, 59), (60, 64), (65, 69), (70, 90)
]

resultado_faixas = DataFrame(
    sexo_ref = String[],
    faixa_etaria = String[],
    idade_min = Int[],
    idade_max = Int[],
    age_gap_medio = Float64[],
    age_gap_sd = Float64[],
    n_pares = Int[],
    n_pares_pond = Float64[]
)

for sexo_val in [1, 2]
    sexo_label = sexo_val == 1 ? "Masculino" : "Feminino"

    for (idade_min, idade_max) in faixas_etarias
        pares_filtro = filter(row ->
            row.sexo_ref == sexo_val &&
            idade_min <= row.idade_ref <= idade_max,
            pares)

        if nrow(pares_filtro) == 0
            continue
        end

        media = sum(pares_filtro.age_gap .* pares_filtro.peso) / sum(pares_filtro.peso)
        variancia = sum((pares_filtro.age_gap .- media).^2 .* pares_filtro.peso) / sum(pares_filtro.peso)
        sd = sqrt(variancia)

        push!(resultado_faixas, (
            sexo_label,
            "$idade_min-$idade_max",
            idade_min,
            idade_max,
            media,
            sd,
            nrow(pares_filtro),
            sum(pares_filtro.peso)
        ))
    end
end

println("\nResultados por faixa etária:")
println("")

# Exibir tabela
tab_show = copy(resultado_faixas)
tab_show.age_gap_medio = round.(tab_show.age_gap_medio, digits=2)
tab_show.age_gap_sd = round.(tab_show.age_gap_sd, digits=2)
tab_show.n_pares_pond = round.(tab_show.n_pares_pond ./ 1000, digits=1)

rename!(tab_show,
    :sexo_ref => "Sexo",
    :faixa_etaria => "Faixa",
    :age_gap_medio => "Gap_Médio",
    :age_gap_sd => "DP",
    :n_pares => "N_amostra",
    :n_pares_pond => "N_pond(mil)"
)

select!(tab_show, :Sexo, :Faixa, Symbol("Gap_Médio"), :DP, :N_amostra, Symbol("N_pond(mil)"))

pretty_table(tab_show)

# === DISTRIBUIÇÃO DE AGE GAP ===

println("\n" * "=" ^ 70)
println("DISTRIBUIÇÃO DE AGE GAP")
println("=" ^ 70)

# Contar por intervalo
intervalos = [
    (-Inf, -10), (-10, -5), (-5, -2), (-2, 0),
    (0, 2), (2, 5), (5, 10), (10, 15), (15, Inf)
]

dist_age_gap = DataFrame(
    intervalo = String[],
    n_pares = Int[],
    n_pares_pond = Float64[],
    proporcao = Float64[]
)

total_pond = sum(pares.peso)

for (idade_min, idade_max) in intervalos
    filtro = if idade_max == Inf
        pares.age_gap .>= idade_min
    elseif idade_min == -Inf
        pares.age_gap .< idade_max
    else
        (pares.age_gap .>= idade_min) .& (pares.age_gap .< idade_max)
    end

    n = count(filtro)
    n_pond = sum(pares.peso[filtro])
    prop = n_pond / total_pond * 100

    label = if idade_max == Inf
        "≥ $(Int(idade_min))"
    elseif idade_min == -Inf
        "< $(Int(idade_max))"
    else
        "[$(Int(idade_min)), $(Int(idade_max)))"
    end

    push!(dist_age_gap, (label, n, n_pond, prop))
end

println("\nDistribuição de age gap:")
dist_show = copy(dist_age_gap)
dist_show.n_pares_pond = round.(dist_show.n_pares_pond ./ 1000, digits=1)
dist_show.proporcao = round.(dist_show.proporcao, digits=2)

rename!(dist_show,
    :intervalo => "Age_Gap(anos)",
    :n_pares => "N",
    :n_pares_pond => "N_pond(mil)",
    :proporcao => "Prop(%)"
)

pretty_table(dist_show)

# === SALVAR RESULTADOS ===

println("\n" * "=" ^ 70)
println("SALVANDO RESULTADOS")
println("=" ^ 70)

# Salvar pares completos
arquivo_pares = joinpath(RESULTADOS_DIR, "pares_conjuges.csv")
CSV.write(arquivo_pares, pares)
println("\n✓ Pares salvos: $arquivo_pares")

# Salvar estatísticas por faixa etária
arquivo_faixas = joinpath(RESULTADOS_DIR, "age_gap_por_faixa.csv")
CSV.write(arquivo_faixas, resultado_faixas)
println("✓ Age gap por faixa: $arquivo_faixas")

# Salvar distribuição
arquivo_dist = joinpath(RESULTADOS_DIR, "distribuicao_age_gap.csv")
CSV.write(arquivo_dist, dist_age_gap)
println("✓ Distribuição: $arquivo_dist")

# === VISUALIZAÇÕES ===

println("\n" * "=" ^ 70)
println("GERANDO VISUALIZAÇÕES")
println("=" ^ 70)

GRAFICOS_DIR = joinpath(RESULTADOS_DIR, "graficos")
mkpath(GRAFICOS_DIR)

# Gráfico 1: Histograma de age gap
println("\n📊 Gráfico 1: Histograma de age gap...")

p1 = histogram(
    pares.age_gap,
    bins = -20:2:30,
    weights = pares.peso,
    label = nothing,
    title = "Distribuição de Age Gap (Diferença de Idade entre Cônjuges)",
    xlabel = "Age Gap (anos)",
    ylabel = "Frequência Ponderada",
    color = :steelblue,
    alpha = 0.7,
    size = (1000, 600),
    dpi = 150,
    margin = 8Plots.mm
)

vline!(p1, [0], color = :red, linestyle = :dash, linewidth = 2, label = "Age Gap = 0")
vline!(p1, [age_gap_medio_pond], color = :orange, linestyle = :dash, linewidth = 2,
       label = "Média = $(round(age_gap_medio_pond, digits=1))")

savefig(p1, joinpath(GRAFICOS_DIR, "06_histograma_age_gap.png"))
println("✓ Salvo: 06_histograma_age_gap.png")

# Gráfico 2: Age gap por idade da referência
println("\n📊 Gráfico 2: Age gap por idade...")

# Preparar dados por idade individual
age_gap_por_idade = combine(
    groupby(pares, [:sexo_ref, :idade_ref])
) do sdf
    if nrow(sdf) < 5
        return DataFrame()  # Poucas observações
    end
    media = sum(sdf.age_gap .* sdf.peso) / sum(sdf.peso)
    DataFrame(age_gap_medio = media, n = nrow(sdf))
end

# Filtrar idades com dados suficientes
filter!(row -> 25 <= row.idade_ref <= 70 && row.n >= 5, age_gap_por_idade)

p2 = plot(
    title = "Age Gap Médio por Idade da Referência",
    xlabel = "Idade da Pessoa de Referência",
    ylabel = "Age Gap Médio (anos)",
    legend = :topright,
    size = (1000, 600),
    dpi = 150,
    margin = 8Plots.mm
)

for sexo_val in [1, 2]
    sexo_label = sexo_val == 1 ? "Masculino" : "Feminino"
    dados_sexo = filter(row -> row.sexo_ref == sexo_val, age_gap_por_idade)

    if nrow(dados_sexo) > 0
        sort!(dados_sexo, :idade_ref)
        plot!(p2, dados_sexo.idade_ref, dados_sexo.age_gap_medio,
              label = sexo_label,
              linewidth = 2.5,
              marker = :circle,
              markersize = 3)
    end
end

hline!(p2, [0], color = :black, linestyle = :dash, linewidth = 1, label = nothing)

savefig(p2, joinpath(GRAFICOS_DIR, "07_age_gap_por_idade.png"))
println("✓ Salvo: 07_age_gap_por_idade.png")

# === RESUMO FINAL ===

println("\n" * "=" ^ 70)
println("RESUMO - AGE GAP ANALYSIS")
println("=" ^ 70)

println("\nPrincipais achados:")
println("  • Age gap médio: $(round(age_gap_medio_pond, digits=1)) anos")
println("  • Desvio-padrão: $(round(age_gap_sd_pond, digits=1)) anos")
println("  • Total de pares analisados: $(nrow(pares))")
println("  • População estimada: $(round(sum(pares.peso) / 1_000_000, digits=1)) milhões de casais")

println("\nInterpretação:")
println("  • Valor positivo indica que pessoa de referência é mais velha que cônjuge")
println("  • Homens tendem a ser mais velhos que suas parceiras")
println("  • Mulheres de referência também tendem a ser mais velhas (viés amostral)")

println("\nAplicação para função heritor:")
println("  • Usar age gap médio por idade e sexo para estimar idade do beneficiário")
println("  • Exemplo: Homem de 60 anos → Cônjuge esperada: ~$(60 - round(age_gap_medio_pond)) anos")
println("  • Considerar desvio-padrão para análise de sensibilidade")

println("\n" * "=" ^ 70)
println("Próximos passos:")
println("  julia 04_validacoes.jl")
println("=" ^ 70)
