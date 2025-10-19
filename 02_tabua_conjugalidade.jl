#!/usr/bin/env julia
# Cálculo da Tábua de Conjugalidade
# Compara proporção de casados entre população geral e servidores públicos

using CSV
using DataFrames
using Statistics
using StatsBase
using PrettyTables
using Printf

println("=" ^ 70)
println("Tábua de Conjugalidade - População Geral vs. Servidores Públicos")
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
println("  Servidores: $(count(df.servidor))")
println("  População geral: $(nrow(df))")

# Definir idades individuais (ano a ano)
idades = collect(15:90)  # De 15 a 90 anos

# Função para calcular proporção de casados COM PESOS
function calcular_proporcao(df_filtrado)
    if nrow(df_filtrado) == 0
        return (0.0, 0.0, 0)
    end

    # Total ponderado
    total_ponderado = sum(df_filtrado.peso)

    # Casados ponderado
    casados_ponderado = sum(df_filtrado.peso[df_filtrado.casado .== 1])

    # Proporção
    prop = total_ponderado > 0 ? casados_ponderado / total_ponderado : 0.0

    # Tamanho amostral (para referência)
    n_amostra = nrow(df_filtrado)

    return (prop, total_ponderado, n_amostra)
end

# Criar dataframe de resultados
resultados = DataFrame(
    idade = Int[],
    sexo = String[],
    prop_geral = Float64[],
    n_geral_pond = Float64[],
    n_geral_amostra = Int[],
    prop_servidores = Float64[],
    n_serv_pond = Float64[],
    n_serv_amostra = Int[],
    diferenca = Float64[],
    diferenca_pp = Float64[]
)

println("\nCalculando proporções por idade e sexo...\n")

for idade_val in idades
    for sexo_val in [1, 2]
        sexo_label = sexo_val == 1 ? "Masculino" : "Feminino"

        # Filtrar população geral
        df_geral = filter(row ->
            row.idade == idade_val &&
            row.sexo == sexo_val,
            df)

        # Filtrar servidores
        df_serv = filter(row ->
            row.idade == idade_val &&
            row.sexo == sexo_val &&
            row.servidor,
            df)

        # Calcular proporções PONDERADAS
        (prop_geral, n_geral_pond, n_geral_amostra) = calcular_proporcao(df_geral)
        (prop_serv, n_serv_pond, n_serv_amostra) = calcular_proporcao(df_serv)

        # Diferença relativa e em pontos percentuais
        dif_relativa = prop_geral > 0 ? (prop_serv / prop_geral - 1) * 100 : 0.0
        dif_pp = (prop_serv - prop_geral) * 100

        push!(resultados, (
            idade_val,
            sexo_label,
            prop_geral * 100,
            n_geral_pond,
            n_geral_amostra,
            prop_serv * 100,
            n_serv_pond,
            n_serv_amostra,
            dif_relativa,
            dif_pp
        ))
    end
end

# Exibir resultados
println("Tábua de Conjugalidade - Proporção de Casados/União Estável (%)")
println("=" ^ 70)

# Tabela para Masculino (primeiras e últimas 10 idades)
println("\n📊 MASCULINO (amostra)\n")
tab_masc = filter(row -> row.sexo == "Masculino", resultados)
tab_masc_show = select(tab_masc, :idade, :prop_geral, :n_geral_amostra, :prop_servidores, :n_serv_amostra, :diferenca_pp)
# Arredondar valores
tab_masc_show.prop_geral = round.(tab_masc_show.prop_geral, digits=1)
tab_masc_show.prop_servidores = round.(tab_masc_show.prop_servidores, digits=1)
tab_masc_show.diferenca_pp = round.(tab_masc_show.diferenca_pp, digits=1)
rename!(tab_masc_show, :idade => "Idade", :prop_geral => "Geral(%)", :n_geral_amostra => "N_Geral",
        :prop_servidores => "Serv(%)", :n_serv_amostra => "N_Serv", :diferenca_pp => "Dif(pp)")
# Mostrar primeiras 10 e últimas 10
println("Primeiras 10 idades:")
pretty_table(first(tab_masc_show, 10))
println("\nÚltimas 10 idades:")
pretty_table(last(tab_masc_show, 10))

# Tabela para Feminino (primeiras e últimas 10 idades)
println("\n📊 FEMININO (amostra)\n")
tab_fem = filter(row -> row.sexo == "Feminino", resultados)
tab_fem_show = select(tab_fem, :idade, :prop_geral, :n_geral_amostra, :prop_servidores, :n_serv_amostra, :diferenca_pp)
# Arredondar valores
tab_fem_show.prop_geral = round.(tab_fem_show.prop_geral, digits=1)
tab_fem_show.prop_servidores = round.(tab_fem_show.prop_servidores, digits=1)
tab_fem_show.diferenca_pp = round.(tab_fem_show.diferenca_pp, digits=1)
rename!(tab_fem_show, :idade => "Idade", :prop_geral => "Geral(%)", :n_geral_amostra => "N_Geral",
        :prop_servidores => "Serv(%)", :n_serv_amostra => "N_Serv", :diferenca_pp => "Dif(pp)")
println("Primeiras 10 idades:")
pretty_table(first(tab_fem_show, 10))
println("\nÚltimas 10 idades:")
pretty_table(last(tab_fem_show, 10))

# Salvar resultados em CSV
arquivo_csv = joinpath(RESULTADOS_DIR, "tabua_conjugalidade.csv")
CSV.write(arquivo_csv, resultados)
println("\n✅ Resultados salvos em: $arquivo_csv")

# Estatísticas resumidas
println("\n" * "=" ^ 70)
println("RESUMO ESTATÍSTICO")
println("=" ^ 70)

for sexo_label in ["Masculino", "Feminino"]
    println("\n$sexo_label:")
    df_sexo = filter(row -> row.sexo == sexo_label, resultados)

    # Encontrar idade com maior proporção de casados
    idx_max_geral = argmax(df_sexo.prop_geral)
    idx_max_serv = argmax(df_sexo.prop_servidores)

    println("  Pico de conjugalidade (geral): $(df_sexo[idx_max_geral, :idade]) anos ($(round(df_sexo[idx_max_geral, :prop_geral], digits=1))%)")
    println("  Pico de conjugalidade (servidores): $(df_sexo[idx_max_serv, :idade]) anos ($(round(df_sexo[idx_max_serv, :prop_servidores], digits=1))%)")

    # Média geral (ponderada por idade ativa 25-60)
    df_ativa = filter(row -> 25 <= row.idade <= 60, df_sexo)
    println("  Média de conjugalidade 25-60 anos (geral): $(round(mean(df_ativa.prop_geral), digits=1))%")
    println("  Média de conjugalidade 25-60 anos (servidores): $(round(mean(df_ativa.prop_servidores), digits=1))%")
    println("  Diferença média: $(round(mean(df_ativa.diferenca_pp), digits=1)) pp")
end

println("\n" * "=" ^ 70)
println("Próximos passos:")
println("  julia 03_visualizacoes.jl")
println("=" ^ 70)
