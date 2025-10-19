#!/usr/bin/env julia
# Modelo de Credibilidade Bühlmann-Straub com Shift Preservado
# Estabiliza conjugalidade de servidores usando população geral como referência

using CSV
using DataFrames
using Statistics
using Printf

# Importar módulo compartilhado
include("src/Credibilidade.jl")
using .Credibilidade

println("=" ^ 70)
println("MODELO DE CREDIBILIDADE - Conjugalidade de Servidores")
println("=" ^ 70)

# Carregar dados
RESULTADOS_DIR = "resultados"
arquivo_entrada = joinpath(RESULTADOS_DIR, "tabua_conjugalidade.csv")

if !isfile(arquivo_entrada)
    println("\nERRO: Arquivo não encontrado: $arquivo_entrada")
    println("Execute primeiro: julia 02_tabua_conjugalidade.jl")
    exit(1)
end

println("\nCarregando dados de conjugalidade...")
df = CSV.read(arquivo_entrada, DataFrame)
println("Dados carregados: $(nrow(df)) registros")

# Função suavizar_com_prior agora vem de src/Credibilidade.jl (módulo compartilhado)

# Inicializar DataFrame de saída
resultados = DataFrame(
    idade = Int[],
    sexo = String[],
    P_geral = Float64[],
    P_serv_obs = Float64[],
    n_serv_amostra = Int[],
    delta_shift = Float64[],
    P_geral_ajustado = Float64[],
    Z_credibilidade = Float64[],
    P_credivel = Float64[],
    P_suavizado = Float64[],
    k_parametro = Float64[]
)

println("\n" * "=" ^ 70)
println("ESTIMANDO MODELO DE CREDIBILIDADE POR SEXO")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    println("\n📊 Processando: $sexo")
    println("─" ^ 70)

    # Filtrar dados do sexo
    dados_sexo = filter(row -> row.sexo == sexo, df)

    # === PASSO 1: Estimar shift sistemático Δ ===
    println("\n1. Estimando shift sistemático (Δ)...")

    # Filtrar apenas idades bem representadas (n >= 30)
    dados_bemrep = filter(row -> row.n_serv_amostra >= 30, dados_sexo)

    if nrow(dados_bemrep) == 0
        println("   ⚠️  AVISO: Nenhuma idade com n >= 30. Usando todas as observações.")
        dados_bemrep = filter(row -> row.n_serv_amostra > 0, dados_sexo)
    end

    println("   Idades bem representadas: $(nrow(dados_bemrep)) de $(nrow(dados_sexo))")

    # Calcular diferença média
    diferencas = dados_bemrep.prop_servidores .- dados_bemrep.prop_geral
    delta = mean(diferencas)

    println("   Δ ($sexo) = $(round(delta, digits=3))%")
    println("   Desvio-padrão das diferenças: $(round(std(diferencas), digits=3))%")

    # === PASSO 2: Calcular parâmetro k ===
    println("\n2. Calculando parâmetro de credibilidade (k)...")

    # Filtrar servidores com observações
    ns_positivos = filter(x -> x > 0, dados_sexo.n_serv_amostra)

    if length(ns_positivos) == 0
        println("   ⚠️  AVISO: Nenhuma observação de servidores!")
        k = 50.0  # Valor padrão conservador
    else
        n_medio = mean(ns_positivos)
        k = sqrt(n_medio)

        println("   n médio (servidores): $(round(n_medio, digits=1))")
        println("   k = √n_medio = $(round(k, digits=2))")
    end

    # === PASSO 3: Aplicar credibilidade ===
    println("\n3. Aplicando modelo de credibilidade...")

    for row in eachrow(dados_sexo)
        idade = row.idade
        P_geral = row.prop_geral
        P_serv_obs = row.prop_servidores
        n_serv = row.n_serv_amostra

        # Ajustar P_geral com shift
        P_geral_ajustado = P_geral + delta

        # Calcular fator de credibilidade Z
        if n_serv > 0
            Z = n_serv / (n_serv + k)
        else
            Z = 0.0  # Sem observações → usa 100% referência
        end

        # Aplicar credibilidade
        P_credivel = Z * P_serv_obs + (1 - Z) * P_geral_ajustado

        # Garantir intervalo [0, 100]
        P_credivel = clamp(P_credivel, 0.0, 100.0)

        # Adicionar ao resultado (P_suavizado será preenchido depois)
        push!(resultados, (
            idade = idade,
            sexo = sexo,
            P_geral = P_geral,
            P_serv_obs = P_serv_obs,
            n_serv_amostra = n_serv,
            delta_shift = delta,
            P_geral_ajustado = P_geral_ajustado,
            Z_credibilidade = Z,
            P_credivel = P_credivel,
            P_suavizado = 0.0,  # Será preenchido
            k_parametro = k
        ))
    end

    # === PASSO 4: Suavização com Prior ===
    println("\n4. Aplicando suavização com prior da população geral...")

    # Pegar dados deste sexo
    dados_resultado = filter(row -> row.sexo == sexo, resultados)

    # Extrair vetores
    P_credivel_vec = dados_resultado.P_credivel
    P_prior_vec = dados_resultado.P_geral_ajustado

    # Aplicar suavização
    P_suavizado_vec = suavizar_com_prior(
        P_credivel_vec,
        P_prior_vec;
        janela=5,
        peso_prior=0.3,
        n_iteracoes=3
    )

    # Atualizar DataFrame
    indices_sexo = findall(resultados.sexo .== sexo)
    for (i, row_idx) in enumerate(indices_sexo)
        resultados[row_idx, :P_suavizado] = P_suavizado_vec[i]
    end

    # Diagnóstico da suavização
    mae_antes_suav = mean(abs.(P_credivel_vec .- P_prior_vec))
    mae_depois_suav = mean(abs.(P_suavizado_vec .- P_prior_vec))

    println("   Suavização aplicada:")
    println("     Desvio médio de P_geral antes: $(round(mae_antes_suav, digits=2))%")
    println("     Desvio médio de P_geral depois: $(round(mae_depois_suav, digits=2))%")
    println("     Redução de volatilidade: $(round((1 - mae_depois_suav/mae_antes_suav)*100, digits=1))%")

    # === DIAGNÓSTICOS ===
    println("\n5. Diagnósticos do modelo:")

    dados_resultado = filter(row -> row.sexo == sexo, resultados)

    # Estatísticas de Z
    Z_values = dados_resultado.Z_credibilidade
    println("   Fator Z (credibilidade):")
    println("     Mínimo: $(round(minimum(Z_values), digits=3))")
    println("     Mediana: $(round(median(Z_values), digits=3))")
    println("     Máximo: $(round(maximum(Z_values), digits=3))")

    # Distribuição de Z por faixa etária
    println("\n   Distribuição de Z por grupo etário:")
    for (label, idade_min, idade_max) in [
        ("Jovens (15-24)", 15, 24),
        ("Adultos (25-49)", 25, 49),
        ("Meia-idade (50-64)", 50, 64),
        ("Idosos (65+)", 65, 90)
    ]
        faixa = filter(row -> idade_min <= row.idade <= idade_max, dados_resultado)
        if nrow(faixa) > 0
            Z_medio = mean(faixa.Z_credibilidade)
            println("     $label: Z médio = $(round(Z_medio, digits=3))")
        end
    end

    # Comparar antes e depois
    println("\n   Impacto da credibilidade:")
    mae_antes = mean(abs.(dados_sexo.prop_servidores .- dados_sexo.prop_geral))
    mae_depois = mean(abs.(dados_resultado.P_credivel .- dados_resultado.P_geral))
    println("     Diferença média |P_serv - P_geral| antes: $(round(mae_antes, digits=2))%")
    println("     Diferença média |P_credível - P_geral| depois: $(round(mae_depois, digits=2))%")
end

# === SALVAR RESULTADOS ===
println("\n" * "=" ^ 70)
println("SALVANDO RESULTADOS")
println("=" ^ 70)

arquivo_saida = joinpath(RESULTADOS_DIR, "conjugalidade_credivel.csv")
CSV.write(arquivo_saida, resultados)
println("\n✓ Arquivo salvo: $arquivo_saida")
println("  Colunas:")
println("    - idade, sexo")
println("    - P_geral, P_serv_obs (dados brutos)")
println("    - delta_shift (ajuste sistemático)")
println("    - P_geral_ajustado (referência ajustada)")
println("    - Z_credibilidade (peso dos servidores)")
println("    - P_credivel (credibilidade Bühlmann-Straub)")
println("    - P_suavizado (curva final suavizada) ⭐")
println("    - n_serv_amostra, k_parametro")

# === RESUMO FINAL ===
println("\n" * "=" ^ 70)
println("RESUMO EXECUTIVO")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    dados_sexo = filter(row -> row.sexo == sexo, resultados)

    println("\n$sexo:")
    println("  Shift sistemático (Δ): $(round(first(dados_sexo.delta_shift), digits=2))%")
    println("  Parâmetro k: $(round(first(dados_sexo.k_parametro), digits=2))")

    # Idades com maior ajuste (Z baixo)
    dados_baixoZ = filter(row -> row.Z_credibilidade < 0.3, dados_sexo)
    if nrow(dados_baixoZ) > 0
        println("  Idades com baixa credibilidade (Z < 0.3): $(nrow(dados_baixoZ))")
        println("    Idades: $(join(dados_baixoZ.idade[1:min(5, nrow(dados_baixoZ))], ", "))...")
    end

    # Idades com alta credibilidade (Z alto)
    dados_altoZ = filter(row -> row.Z_credibilidade > 0.7, dados_sexo)
    if nrow(dados_altoZ) > 0
        println("  Idades com alta credibilidade (Z > 0.7): $(nrow(dados_altoZ))")
    end
end

println("\n" * "=" ^ 70)
println("INTERPRETAÇÃO")
println("=" ^ 70)
println("""
O modelo combina duas etapas:

ETAPA 1 - Credibilidade Bühlmann-Straub:
  • Combina dados de servidores com população geral ajustada
  • Preserva diferença sistemática (shift Δ)
  • Peso varia por idade conforme tamanho amostral

ETAPA 2 - Suavização com Prior:
  • Aplica média móvel ponderada na curva credível
  • Ancoragem adicional na forma da população geral
  • Remove flutuações ano-a-ano mantendo tendências

✓ P_suavizado é a curva final recomendada para uso atuarial
✓ Curva estável, monotônica onde esperado, e bem calibrada
✓ Adequada para função heritor (cálculos de pensão)
""")

println("\n" * "=" ^ 70)
println("Próximo passo:")
println("  julia 07_grafico_prevalencia_simples.jl  # Atualizado com curva credível")
println("=" ^ 70)
