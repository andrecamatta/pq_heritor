#!/usr/bin/env julia
# Tábua de Coorte Sintética - Probabilidades de Transição
# Converte prevalências observadas em probabilidades de casar/separar

using CSV
using DataFrames
using Statistics
using PrettyTables
using Printf

println("=" ^ 70)
println("Tábua de Coorte Sintética - Probabilidades de Casamento")
println("=" ^ 70)

# Carregar prevalências observadas
RESULTADOS_DIR = "resultados"
arquivo_prevalencias = joinpath(RESULTADOS_DIR, "tabua_conjugalidade.csv")

if !isfile(arquivo_prevalencias)
    println("\nERRO: Arquivo não encontrado: $arquivo_prevalencias")
    println("Execute primeiro: julia 02_tabua_conjugalidade.jl")
    exit(1)
end

println("\nCarregando prevalências observadas...")
df_prev = CSV.read(arquivo_prevalencias, DataFrame)
println("Dados carregados: $(nrow(df_prev)) registros")

# === MÉTODO 1: PRIMEIRA DIFERENÇA (SIMPLIFICADO) ===

function estimar_q_casar_simples(prevalencias::Vector{Float64})
    """
    Estima probabilidade de casar usando método de primeira diferença

    Assume que separações são raras, então:
    P[x+1] ≈ P[x] + (1 - P[x]) * q_casar[x]

    Resolvendo: q_casar[x] = (P[x+1] - P[x]) / (1 - P[x])
    """
    n = length(prevalencias)
    q_casar = zeros(n-1)

    for x in 1:(n-1)
        dP = prevalencias[x+1] - prevalencias[x]
        denominador = 1.0 - prevalencias[x]

        if denominador > 0.01  # Evitar divisão por zero
            if dP > 0  # Crescimento = pessoas casando
                q_casar[x] = dP / denominador
            else  # Decrescimento = separação domina
                # Simplificação: não estimamos separação explicitamente
                q_casar[x] = 0.0
            end
        else
            q_casar[x] = 0.0
        end

        # Limitar a valores plausíveis [0, 0.5]
        q_casar[x] = clamp(q_casar[x], 0.0, 0.5)
    end

    return q_casar
end

function calcular_tabua_simples(prevalencias::Vector{Float64}, idades::Vector{Int})
    """
    Calcula tábua sintética usando método simplificado
    """
    n = length(prevalencias)

    # Estimar q_casar
    q_casar = estimar_q_casar_simples(prevalencias)

    # Calcular l_x (proporção solteira)
    l_solteiro = zeros(n)
    l_casado = zeros(n)

    # Condição inicial (idade mínima)
    l_solteiro[1] = 1.0 - prevalencias[1]
    l_casado[1] = prevalencias[1]

    # Recorrência forward
    for x in 1:(n-1)
        # Simplificação: assumir q_separar ≈ 0
        l_solteiro[x+1] = l_solteiro[x] * (1 - q_casar[x])
        l_casado[x+1] = 1.0 - l_solteiro[x+1]
    end

    # Reconstruir prevalência
    P_reconstruida = l_casado

    # Calcular erros
    erro_abs = prevalencias .- P_reconstruida

    return (
        l_solteiro = l_solteiro,
        l_casado = l_casado,
        q_casar = q_casar,
        P_reconstruida = P_reconstruida,
        erro_abs = erro_abs
    )
end

# === MÉTODO 2: DOIS ESTADOS COM OTIMIZAÇÃO ===

function estimar_taxas_dois_estados(prevalencias::Vector{Float64};
                                     max_iter::Int = 200,
                                     tol::Float64 = 1e-4)
    """
    Estima q_casar e q_separar usando otimização iterativa

    Minimiza: Σ(P_obs - P_modelo)²
    Sujeito a: equações de transição de estados
    """
    n = length(prevalencias)

    # Inicializar taxas com método simples
    q_casar = estimar_q_casar_simples(prevalencias)
    q_separar = zeros(n-1)  # Iniciar com zero

    # Taxa de aprendizado adaptativa
    lr = 0.05

    # Inicializar variáveis fora do loop
    l_solt = zeros(n)
    l_cas = zeros(n)

    for iter in 1:max_iter
        # === FORWARD PASS ===
        l_solt .= 0.0
        l_cas .= 0.0

        # Condição inicial
        l_solt[1] = 1.0 - prevalencias[1]
        l_cas[1] = prevalencias[1]

        # Recorrência
        for x in 1:(n-1)
            # Garantir que probabilidades somam <= 1
            q_c = clamp(q_casar[x], 0.0, 0.99)
            q_s = clamp(q_separar[x], 0.0, 0.99)

            # Transições
            l_solt[x+1] = l_solt[x] * (1 - q_c) + l_cas[x] * q_s
            l_cas[x+1] = l_solt[x] * q_c + l_cas[x] * (1 - q_s)

            # Normalizar (garantir soma = 1)
            total = l_solt[x+1] + l_cas[x+1]
            if total > 0
                l_solt[x+1] /= total
                l_cas[x+1] /= total
            end
        end

        # Calcular prevalência do modelo
        P_modelo = l_cas

        # Erro
        erro = prevalencias .- P_modelo
        mae = mean(abs.(erro))

        # Convergência
        if mae < tol
            println("  Convergiu em $iter iterações (MAE = $(round(mae*100, digits=4))%)")
            return (q_casar = q_casar, q_separar = q_separar,
                    l_solteiro = l_solt, l_casado = l_cas,
                    P_reconstruida = P_modelo, erro_abs = erro)
        end

        # === BACKWARD PASS (Gradiente) ===
        for x in 1:(n-1)
            if l_solt[x] + l_cas[x] > 0
                # Derivadas parciais aproximadas
                # ∂P/∂q_casar ≈ proporção solteira no período
                grad_casar = l_solt[x] / (l_solt[x] + l_cas[x])

                # ∂P/∂q_separar ≈ -proporção casada no período
                grad_separar = -l_cas[x] / (l_solt[x] + l_cas[x])

                # Atualizar taxas
                q_casar[x] += lr * erro[x+1] * grad_casar
                q_separar[x] += lr * erro[x+1] * grad_separar

                # Clamp
                q_casar[x] = clamp(q_casar[x], 0.0, 0.99)
                q_separar[x] = clamp(q_separar[x], 0.0, 0.5)  # Separação é menos comum
            end
        end

        # Reduzir learning rate gradualmente
        if iter % 50 == 0
            lr *= 0.9
        end
    end

    # Se não convergiu, calcular P_modelo final
    P_modelo_final = l_cas
    mae_final = mean(abs.(prevalencias .- P_modelo_final))
    println("  AVISO: Não convergiu em $max_iter iterações (MAE = $(round(mae_final*100, digits=4))%)")

    # Retornar melhor resultado
    return (q_casar = q_casar, q_separar = q_separar,
            l_solteiro = l_solt, l_casado = l_cas,
            P_reconstruida = P_modelo_final, erro_abs = prevalencias .- P_modelo_final)
end

# === PROCESSAR TODOS OS GRUPOS ===

println("\n" * "=" ^ 70)
println("CALCULANDO TÁBUAS SINTÉTICAS")
println("=" ^ 70)

resultados_simples = DataFrame()
resultados_completo = DataFrame()

for sexo in ["Masculino", "Feminino"]
    for grupo_tipo in ["Geral", "Servidores"]
        println("\n📊 Processando: $sexo - $grupo_tipo")

        # Filtrar dados
        dados = filter(row -> row.sexo == sexo, df_prev)

        idades = dados.idade
        prev = if grupo_tipo == "Geral"
            dados.prop_geral ./ 100  # Converter % para proporção
        else
            dados.prop_servidores ./ 100
        end

        # === MÉTODO SIMPLES ===
        println("  Método 1: Primeira diferença...")
        resultado_s = calcular_tabua_simples(prev, idades)

        # Montar DataFrame
        n = length(idades)
        df_simples = DataFrame(
            idade = idades,
            sexo = fill(sexo, n),
            grupo = fill(grupo_tipo, n),
            l_solteiro = resultado_s.l_solteiro,
            l_casado = resultado_s.l_casado,
            q_casar = [resultado_s.q_casar; missing],
            q_separar = fill(missing, n),  # Não estimado neste método
            P_observada = prev,
            P_reconstruida = resultado_s.P_reconstruida,
            erro_abs = resultado_s.erro_abs,
            metodo = fill("primeira_diferenca", n)
        )

        mae_s = mean(abs.(skipmissing(resultado_s.erro_abs)))
        println("    MAE = $(round(mae_s*100, digits=3))%")

        append!(resultados_simples, df_simples)

        # === MÉTODO COMPLETO ===
        println("  Método 2: Dois estados com otimização...")
        resultado_c = estimar_taxas_dois_estados(prev)

        df_completo = DataFrame(
            idade = idades,
            sexo = fill(sexo, n),
            grupo = fill(grupo_tipo, n),
            l_solteiro = resultado_c.l_solteiro,
            l_casado = resultado_c.l_casado,
            q_casar = [resultado_c.q_casar; missing],
            q_separar = [resultado_c.q_separar; missing],
            P_observada = prev,
            P_reconstruida = resultado_c.P_reconstruida,
            erro_abs = resultado_c.erro_abs,
            metodo = fill("dois_estados", n)
        )

        mae_c = mean(abs.(skipmissing(resultado_c.erro_abs)))
        println("    MAE = $(round(mae_c*100, digits=3))%")

        append!(resultados_completo, df_completo)
    end
end

# === SALVAR RESULTADOS ===

println("\n" * "=" ^ 70)
println("SALVANDO RESULTADOS")
println("=" ^ 70)

arquivo_simples = joinpath(RESULTADOS_DIR, "tabua_sintetica_simples.csv")
arquivo_completo = joinpath(RESULTADOS_DIR, "tabua_sintetica_completa.csv")

CSV.write(arquivo_simples, resultados_simples)
CSV.write(arquivo_completo, resultados_completo)

println("\n✓ Tábua sintética (método simples): $arquivo_simples")
println("✓ Tábua sintética (método completo): $arquivo_completo")

# === VALIDAÇÃO ===

println("\n" * "=" ^ 70)
println("VALIDAÇÃO DOS RESULTADOS")
println("=" ^ 70)

println("\nErro Médio Absoluto (MAE) por Método:")
println("")

# Tabela comparativa
validacao = DataFrame(
    Sexo = String[],
    Grupo = String[],
    MAE_Simples = Float64[],
    MAE_Completo = Float64[]
)

for sexo in ["Masculino", "Feminino"]
    for grupo in ["Geral", "Servidores"]
        # Método simples
        dados_s = filter(row -> row.sexo == sexo && row.grupo == grupo, resultados_simples)
        mae_s = mean(abs.(skipmissing(dados_s.erro_abs))) * 100

        # Método completo
        dados_c = filter(row -> row.sexo == sexo && row.grupo == grupo, resultados_completo)
        mae_c = mean(abs.(skipmissing(dados_c.erro_abs))) * 100

        push!(validacao, (sexo, grupo, mae_s, mae_c))
    end
end

# Formatar
validacao.MAE_Simples = round.(validacao.MAE_Simples, digits=3)
validacao.MAE_Completo = round.(validacao.MAE_Completo, digits=3)

pretty_table(validacao)

# === ESTATÍSTICAS RESUMIDAS ===

println("\n" * "=" ^ 70)
println("ESTATÍSTICAS DAS PROBABILIDADES (Método Completo)")
println("=" ^ 70)

for sexo in ["Masculino", "Feminino"]
    println("\n$sexo:")
    for grupo in ["Geral", "Servidores"]
        dados = filter(row -> row.sexo == sexo && row.grupo == grupo, resultados_completo)

        # Estatísticas de q_casar
        q_casar_vals = collect(skipmissing(dados.q_casar))
        q_separar_vals = collect(skipmissing(dados.q_separar))

        println("  $grupo:")
        println("    q_casar (probabilidade de casar):")
        println("      Média: $(round(mean(q_casar_vals)*100, digits=2))%")
        println("      Máximo: $(round(maximum(q_casar_vals)*100, digits=2))% (idade $(dados[argmax(skipmissing(dados.q_casar)), :idade]))")
        println("      Mínimo: $(round(minimum(q_casar_vals)*100, digits=2))%")

        println("    q_separar (probabilidade de separar):")
        println("      Média: $(round(mean(q_separar_vals)*100, digits=2))%")
        println("      Máximo: $(round(maximum(q_separar_vals)*100, digits=2))%")
    end
end

# === INTERPRETAÇÃO ===

println("\n" * "=" ^ 70)
println("INTERPRETAÇÃO DOS RESULTADOS")
println("=" ^ 70)

println("\n📌 Como usar a tábua sintética:")
println("")
println("1. l_solteiro[x]: Proporção que permanece solteira até idade x")
println("2. l_casado[x]: Proporção que está casada na idade x")
println("3. q_casar[x]: Prob. de casar entre x e x+1 (dado solteiro em x)")
println("4. q_separar[x]: Prob. de separar entre x e x+1 (dado casado em x)")
println("")
println("Exemplo: Probabilidade de solteiro de 25 anos estar casado aos 35:")
println("  P = 1 - l_solteiro[35] / l_solteiro[25]")

println("\n" * "=" ^ 70)
println("Próximos passos:")
println("  julia 06_graficos_tabua_sintetica.jl")
println("=" ^ 70)
