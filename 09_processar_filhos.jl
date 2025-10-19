#!/usr/bin/env julia
# Script para processar informações de filhos da PNADC 2023
# Identifica filhos dependentes (≤ 24 anos) por responsável/cônjuge

using CSV
using DataFrames
using Statistics

println("=" ^ 70)
println("Processamento de Dados de Filhos - PNADC 2023")
println("=" ^ 70)

# ============================================================================
# CARREGAR DADOS
# ============================================================================

DADOS_DIR = "dados"
ARQUIVO_ENTRADA = joinpath(DADOS_DIR, "pnadc_2023_processado.csv")
ARQUIVO_SAIDA = joinpath(DADOS_DIR, "pnadc_2023_filhos.csv")

if !isfile(ARQUIVO_ENTRADA)
    println("\nERRO: Arquivo não encontrado: $ARQUIVO_ENTRADA")
    println("Execute primeiro: julia --project=. 01_processar_dados.jl")
    exit(1)
end

println("\nCarregando dados processados...")
df = CSV.read(ARQUIVO_ENTRADA, DataFrame, types=Dict(:domicilio_id => String, :pessoa_id => String))
println("✓ Dados carregados: $(nrow(df)) pessoas")

# ============================================================================
# IDENTIFICAR FILHOS POR DOMICÍLIO
# ============================================================================

println("\n" * "=" ^ 70)
println("IDENTIFICANDO FILHOS DEPENDENTES")
println("=" ^ 70)

println("\nCritérios:")
println("  - Filho: V2005 ∈ {4, 5, 6} (filho, filho só do resp., enteado)")
println("  - Dependente: idade ≤ 24 anos")
println("  - Plausibilidade biológica: (idade_responsável - idade_filho) ≥ 15 anos")

# Identificar filhos dependentes por domicílio
function identificar_filhos_por_domicilio(df::DataFrame)
    """
    Retorna Dict: domicilio_id => [filhos dependentes...]
    """
    filhos_por_dom = Dict{String, Vector{NamedTuple}}()

    for row in eachrow(df)
        # Verificar se é filho (V2005 = 04, 05 ou 06)
        if row.condicao_dom in [4, 5, 6]
            # Verificar se é dependente (≤ 24 anos)
            if row.idade <= 24
                if !haskey(filhos_por_dom, row.domicilio_id)
                    filhos_por_dom[row.domicilio_id] = []
                end

                push!(filhos_por_dom[row.domicilio_id], (
                    idade = row.idade,
                    sexo = row.sexo,
                    peso = row.peso
                ))
            end
        end
    end

    return filhos_por_dom
end

filhos_por_dom = identificar_filhos_por_domicilio(df)

println("\nEstatísticas de domicílios:")
println("  - Total de domicílios: $(length(unique(df.domicilio_id)))")
println("  - Domicílios com filhos ≤ 24: $(length(filhos_por_dom))")

# Estatísticas de filhos
n_filhos_total = sum(length(v) for v in values(filhos_por_dom))
println("  - Total de filhos ≤ 24 anos: $n_filhos_total")

if n_filhos_total > 0
    todas_idades = vcat([f.idade for filhos in values(filhos_por_dom) for f in filhos]...)
    println("  - Idade média dos filhos: $(round(mean(todas_idades), digits=1)) anos")
    println("  - Idade mínima: $(minimum(todas_idades)) anos")
    println("  - Idade máxima: $(maximum(todas_idades)) anos")
end

# ============================================================================
# PROCESSAR RESPONSÁVEIS E CÔNJUGES
# ============================================================================

println("\n" * "=" ^ 70)
println("PROCESSANDO RESPONSÁVEIS E CÔNJUGES")
println("=" ^ 70)

# Filtrar apenas responsáveis (V2005 = 01)
# Inclui monoparentais (responsáveis sem cônjuge)
# Evita duplicação: 1 observação por domicílio
df_pais = filter(row -> row.condicao_dom == 1, df)

println("\nPessoas analisadas:")
println("  - Responsáveis (V2005=1): $(nrow(df_pais))")
println("  - Idade mínima: $(minimum(df_pais.idade)) anos")
println("  - Idade máxima: $(maximum(df_pais.idade)) anos")

# Adicionar informações de filhos para cada responsável/cônjuge
resultado = DataFrame()

for row in eachrow(df_pais)
    # Buscar filhos do domicílio
    filhos = get(filhos_por_dom, row.domicilio_id, [])

    # Calcular métricas com validação biológica
    if length(filhos) > 0
        idade_min = minimum(f.idade for f in filhos)
        diff_idade = row.idade - idade_min

        # VALIDAÇÃO: Diferença mínima de 15 anos (plausibilidade biológica)
        if diff_idade >= 15
            tem_filho_dep = true
            n_filhos_dep = length(filhos)
            idade_filho_mais_novo = idade_min
        else
            # Caso biologicamente implausível: ignorar
            tem_filho_dep = false
            n_filhos_dep = 0
            idade_filho_mais_novo = missing
        end
    else
        tem_filho_dep = false
        n_filhos_dep = 0
        idade_filho_mais_novo = missing
    end

    # Adicionar ao resultado
    push!(resultado, (
        pessoa_id = row.pessoa_id,
        domicilio_id = row.domicilio_id,
        idade = row.idade,
        sexo = row.sexo,
        sexo_desc = row.sexo_desc,
        servidor = row.servidor,
        servidor_desc = row.servidor_desc,
        peso = row.peso,
        tem_filho_dep = tem_filho_dep,
        n_filhos_dep = n_filhos_dep,
        idade_filho_mais_novo = idade_filho_mais_novo
    ), cols=:union)
end

# ============================================================================
# ESTATÍSTICAS FINAIS
# ============================================================================

println("\n" * "=" ^ 70)
println("ESTATÍSTICAS FINAIS")
println("=" ^ 70)

# Estatísticas amostrais
n_com_filho = count(resultado.tem_filho_dep)
println("\nAmostra:")
println("  - Total de responsáveis/cônjuges: $(nrow(resultado))")
println("  - Com filhos ≤ 24: $n_com_filho ($(round(100*n_com_filho/nrow(resultado), digits=1))%)")
println("  - Sem filhos ≤ 24: $(nrow(resultado) - n_com_filho)")

# Estatísticas ponderadas
pop_total = sum(resultado.peso) / 1_000_000
pop_com_filho = sum(resultado.peso[resultado.tem_filho_dep]) / 1_000_000

println("\nPopulação ponderada (milhões):")
println("  - Total: $(round(pop_total, digits=2))M")
println("  - Com filhos ≤ 24: $(round(pop_com_filho, digits=2))M ($(round(100*pop_com_filho/pop_total, digits=1))%)")

# Estatísticas por sexo
println("\nPor sexo:")
for sexo in ["Masculino", "Feminino"]
    dados_sexo = filter(row -> row.sexo_desc == sexo, resultado)
    n_total = nrow(dados_sexo)
    n_com = count(dados_sexo.tem_filho_dep)

    pop_total_sexo = sum(dados_sexo.peso) / 1_000_000
    pop_com_sexo = sum(dados_sexo.peso[dados_sexo.tem_filho_dep]) / 1_000_000

    println("\n  $sexo:")
    println("    - Amostra: $n_com/$n_total ($(round(100*n_com/n_total, digits=1))%)")
    println("    - Ponderado: $(round(pop_com_sexo, digits=2))M/$(round(pop_total_sexo, digits=2))M ($(round(100*pop_com_sexo/pop_total_sexo, digits=1))%)")
end

# Estatísticas por grupo (servidor vs não-servidor)
println("\nPor grupo:")
for (grupo, eh_servidor) in [("População geral", false), ("Servidores", true)]
    dados_grupo = filter(row -> row.servidor == eh_servidor, resultado)

    if nrow(dados_grupo) > 0
        n_total = nrow(dados_grupo)
        n_com = count(dados_grupo.tem_filho_dep)

        pop_total_grupo = sum(dados_grupo.peso) / 1_000_000
        pop_com_grupo = sum(dados_grupo.peso[dados_grupo.tem_filho_dep]) / 1_000_000

        println("\n  $grupo:")
        println("    - Amostra: $n_com/$n_total ($(round(100*n_com/n_total, digits=1))%)")
        println("    - Ponderado: $(round(pop_com_grupo, digits=2))M/$(round(pop_total_grupo, digits=2))M ($(round(100*pop_com_grupo/pop_total_grupo, digits=1))%)")
    end
end

# Número de filhos (apenas quem tem)
dados_com_filho = filter(row -> row.tem_filho_dep, resultado)
if nrow(dados_com_filho) > 0
    println("\nNúmero de filhos (apenas quem tem):")
    println("  - Média: $(round(mean(dados_com_filho.n_filhos_dep), digits=2))")
    println("  - Mediana: $(median(dados_com_filho.n_filhos_dep))")
    println("  - Máximo: $(maximum(dados_com_filho.n_filhos_dep))")

    # Distribuição
    for n in 1:min(5, maximum(dados_com_filho.n_filhos_dep))
        count_n = count(==(n), dados_com_filho.n_filhos_dep)
        pct = 100 * count_n / nrow(dados_com_filho)
        println("    - $n filho(s): $count_n ($(round(pct, digits=1))%)")
    end
    if maximum(dados_com_filho.n_filhos_dep) > 5
        count_6plus = count(>=(6), dados_com_filho.n_filhos_dep)
        pct = 100 * count_6plus / nrow(dados_com_filho)
        println("    - 6+ filhos: $count_6plus ($(round(pct, digits=1))%)")
    end
end

# Idade do filho mais novo
dados_idade_filho = dropmissing(resultado, :idade_filho_mais_novo)
if nrow(dados_idade_filho) > 0
    println("\nIdade do filho mais novo:")
    println("  - Média: $(round(mean(dados_idade_filho.idade_filho_mais_novo), digits=1)) anos")
    println("  - Mediana: $(median(dados_idade_filho.idade_filho_mais_novo)) anos")
    println("  - Desvio-padrão: $(round(std(dados_idade_filho.idade_filho_mais_novo), digits=1)) anos")
end

# ============================================================================
# SALVAR RESULTADO
# ============================================================================

println("\n" * "=" ^ 70)
println("Salvando resultado: $ARQUIVO_SAIDA")

# Converter IDs para String antes de salvar (evitar conversão para Int64)
resultado.pessoa_id = string.(resultado.pessoa_id)
resultado.domicilio_id = string.(resultado.domicilio_id)

CSV.write(ARQUIVO_SAIDA, resultado)

println("\n" * "=" ^ 70)
println("✓ Processamento concluído!")
println("=" ^ 70)
println("\nPróximos passos:")
println("  julia --project=. 12_tabua_filhos.jl")
println("=" ^ 70)
