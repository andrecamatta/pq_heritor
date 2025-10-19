#!/usr/bin/env julia
# Script para processar microdados da PNADC 2023 Visita 5
# Baseado em .claude/skills/pnadc2023/02_parsing.md

using CSV
using DataFrames
using Statistics

println("=" ^ 70)
println("Processamento dos Microdados PNADC 2023 - Visita 5")
println("=" ^ 70)

# ============================================================================
# CONSTANTES DE POSIÇÕES FWF (baseadas no dicionário IBGE)
# ============================================================================

const POS_UPA = 12
const LEN_UPA = 9
const POS_V1008 = 28
const LEN_V1008 = 2
const POS_V1014 = 30
const LEN_V1014 = 2
const POS_V1032 = 58      # Peso amostral
const LEN_V1032 = 15
const POS_UF = 6
const LEN_UF = 2
const POS_V2003 = 90      # Número da pessoa
const LEN_V2003 = 2
const POS_V2005 = 92      # Condição no domicílio (02=Cônjuge)
const LEN_V2005 = 2
const POS_V2007 = 94      # Sexo (1=Homem, 2=Mulher)
const LEN_V2007 = 1
const POS_V2009 = 103     # Idade
const LEN_V2009 = 3
const POS_V4028 = 183     # Servidor público (1=Sim, 2=Não)
const LEN_V4028 = 1

# ============================================================================
# FUNÇÃO DE EXTRAÇÃO
# ============================================================================

function extrair_campo(linha::String, pos::Int, len::Int)
    """Extrai campo do FWF (posições 1-indexed)"""
    if length(linha) < pos + len - 1
        return ""
    end
    return strip(linha[pos:pos+len-1])
end

# ============================================================================
# PARSER PRINCIPAL
# ============================================================================

function ler_pnadc_visita5(arquivo::String)
    """
    Parser do PNADC 2023 Visita 5

    Retorna: DataFrame com dados processados
    """
    dados = []
    n_linhas = 0
    n_validos = 0

    println("\nLendo arquivo: $arquivo")
    println("(Isso pode demorar alguns minutos...)")

    open(arquivo, "r") do f
        for linha in eachline(f)
            n_linhas += 1

            # Progresso a cada 50k linhas
            if n_linhas % 50_000 == 0
                print("\r  Processadas: $(n_linhas ÷ 1000)k linhas...")
            end

            try
                # Extrair campos
                upa = extrair_campo(linha, POS_UPA, LEN_UPA)
                v1008 = extrair_campo(linha, POS_V1008, LEN_V1008)
                v1014 = extrair_campo(linha, POS_V1014, LEN_V1014)
                v2003 = extrair_campo(linha, POS_V2003, LEN_V2003)
                uf_str = extrair_campo(linha, POS_UF, LEN_UF)

                v2005_str = extrair_campo(linha, POS_V2005, LEN_V2005)
                v2007_str = extrair_campo(linha, POS_V2007, LEN_V2007)
                v2009_str = extrair_campo(linha, POS_V2009, LEN_V2009)
                v4028_str = extrair_campo(linha, POS_V4028, LEN_V4028)
                v1032_str = extrair_campo(linha, POS_V1032, LEN_V1032)

                # Validar campos essenciais
                if isempty(upa) || isempty(v2007_str) || isempty(v2009_str) || isempty(v1032_str)
                    continue
                end

                # Converter para tipos
                sexo = parse(Int, v2007_str)
                idade = parse(Int, v2009_str)
                peso = parse(Float64, v1032_str)

                # Condição no domicílio (pode estar vazio)
                condicao_dom = isempty(v2005_str) ? 0 : parse(Int, v2005_str)

                # Servidor público (1=Sim, 2 ou vazio=Não)
                servidor = v4028_str == "1"

                # UF
                uf = isempty(uf_str) ? 0 : parse(Int, uf_str)

                # Validar valores
                if sexo ∉ [1, 2] || idade < 0 || idade > 120 || peso <= 0
                    continue
                end

                # Filtrar idade (15-90 anos)
                if idade < 15 || idade > 90
                    continue
                end

                # IDs compostos
                domicilio_id = string(upa, v1008, v1014)
                pessoa_id = string(domicilio_id, v2003)

                # Armazenar
                push!(dados, (
                    domicilio_id = domicilio_id,
                    pessoa_id = pessoa_id,
                    uf = uf,
                    idade = idade,
                    sexo = sexo,
                    condicao_dom = condicao_dom,
                    servidor = servidor,
                    peso = peso
                ))

                n_validos += 1

            catch e
                # Silenciosamente descartar linhas com erro
                continue
            end
        end
    end

    println("\r  Processadas: $(n_linhas ÷ 1000)k linhas... ✓")

    # Converter para DataFrame
    df = DataFrame(dados)

    # Adicionar labels descritivos
    df.sexo_desc = map(s -> s == 1 ? "Masculino" : "Feminino", df.sexo)
    df.servidor_desc = map(s -> s ? "Servidor" : "Não servidor", df.servidor)

    # Casado = tem cônjuge no domicílio (identificado pelo V2005)
    # Precisamos encontrar se existe alguém com V2005 = 02 ou 03 no mesmo domicílio
    # Por ora, vamos marcar quem É cônjuge
    df.e_conjuge = df.condicao_dom .∈ Ref([2, 3])

    println("\nEstatísticas:")
    println("  Total de linhas no arquivo: $n_linhas")
    println("  Pessoas válidas (15-90 anos): $n_validos")

    return df
end

# ============================================================================
# IDENTIFICAR CASADOS
# ============================================================================

function identificar_casados!(df::DataFrame)
    """
    Identifica quem é casado verificando se há cônjuge no domicílio
    """
    println("\nIdentificando pessoas casadas...")

    # Inicializar coluna
    df.casado .= false

    # Identificar domicílios com cônjuge
    dom_com_conjuge = Set{String}()

    for row in eachrow(df)
        if row.condicao_dom in [2, 3]  # É cônjuge
            push!(dom_com_conjuge, row.domicilio_id)
        end
    end

    # Marcar como casados: responsáveis e cônjuges em domicílios com cônjuge
    for i in 1:nrow(df)
        if df[i, :domicilio_id] in dom_com_conjuge
            # Marcar responsável (1) ou cônjuge (2, 3)
            if df[i, :condicao_dom] in [1, 2, 3]
                df[i, :casado] = true
            end
        end
    end

    println("  Pessoas casadas/em união: $(count(df.casado))")

    return df
end

# ============================================================================
# MAIN
# ============================================================================

DADOS_DIR = "dados"
ARQUIVO_ENTRADA = joinpath(DADOS_DIR, "PNADC_2023_visita5.txt")
ARQUIVO_SAIDA = joinpath(DADOS_DIR, "pnadc_2023_processado.csv")

# Verificar se arquivo existe
if !isfile(ARQUIVO_ENTRADA)
    println("\nERRO: Arquivo não encontrado: $ARQUIVO_ENTRADA")
    println("\nExecute primeiro: ./00_download_pnadc2023.sh")
    exit(1)
end

# Processar
df = ler_pnadc_visita5(ARQUIVO_ENTRADA)

# Identificar casados
identificar_casados!(df)

# Estatísticas finais
println("\n" * "=" ^ 70)
println("ESTATÍSTICAS FINAIS")
println("=" ^ 70)

println("\nAmostra:")
println("  - Pessoas: $(nrow(df))")
println("  - Domicílios: $(length(unique(df.domicilio_id)))")
println("  - Homens: $(count(df.sexo .== 1))")
println("  - Mulheres: $(count(df.sexo .== 2))")
println("  - Servidores públicos: $(count(df.servidor))")
println("  - Casados/União: $(count(df.casado))")

println("\nPopulação Ponderada:")
pop_total = sum(df.peso) / 1_000_000
pop_homens = sum(df.peso[df.sexo .== 1]) / 1_000_000
pop_mulheres = sum(df.peso[df.sexo .== 2]) / 1_000_000
pop_servidores = sum(df.peso[df.servidor]) / 1_000_000
pop_casados = sum(df.peso[df.casado]) / 1_000_000

println("  - Total: $(round(pop_total, digits=1)) milhões")
println("  - Homens: $(round(pop_homens, digits=1)) milhões")
println("  - Mulheres: $(round(pop_mulheres, digits=1)) milhões")
println("  - Servidores públicos: $(round(pop_servidores, digits=2)) milhões")
println("  - Casados/União: $(round(pop_casados, digits=1)) milhões")

# Salvar
println("\nSalvando: $ARQUIVO_SAIDA")
CSV.write(ARQUIVO_SAIDA, df)

println("\n" * "=" ^ 70)
println("✓ Processamento concluído!")
println("=" ^ 70)
println("\nPróximos passos:")
println("  julia 02_tabua_conjugalidade.jl")
println("=" ^ 70)
