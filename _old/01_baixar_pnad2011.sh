#!/bin/bash
# Script para baixar microdados da PNAD 2011
# Fonte: FTP do IBGE

set -e  # Exit on error

echo "======================================================================"
echo "Download dos Microdados PNAD 2011"
echo "======================================================================"

# Criar diretório
DADOS_DIR="dados"
mkdir -p "$DADOS_DIR"

# URL base do FTP do IBGE
BASE_URL="ftp://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_anual/microdados/2011"

# Arquivos a baixar
ARQUIVO_DADOS="PNAD_2011.zip"
ARQUIVO_DOC="Documentacao_2011.zip"

echo ""
echo "Baixando microdados da PNAD 2011..."
echo "Origem: $BASE_URL"
echo ""

# Baixar arquivo de dados
echo "1. Baixando arquivo de dados: $ARQUIVO_DADOS"
if [ -f "$DADOS_DIR/$ARQUIVO_DADOS" ]; then
    echo "   ⚠️  Arquivo já existe. Pulando download."
else
    wget -P "$DADOS_DIR" "$BASE_URL/$ARQUIVO_DADOS" || {
        echo "❌ Erro ao baixar $ARQUIVO_DADOS"
        echo ""
        echo "URLs alternativas:"
        echo "  - https://www.ibge.gov.br/estatisticas/sociais/trabalho/9127-pesquisa-nacional-por-amostra-de-domicilios.html"
        echo "  - Baixar manualmente e colocar em: $DADOS_DIR/$ARQUIVO_DADOS"
        exit 1
    }
fi

# Baixar documentação
echo ""
echo "2. Baixando documentação: $ARQUIVO_DOC"
if [ -f "$DADOS_DIR/$ARQUIVO_DOC" ]; then
    echo "   ⚠️  Arquivo já existe. Pulando download."
else
    wget -P "$DADOS_DIR" "$BASE_URL/$ARQUIVO_DOC" || {
        echo "⚠️  Falha ao baixar documentação (não crítico)"
    }
fi

# Descompactar
echo ""
echo "3. Descompactando arquivos..."

cd "$DADOS_DIR"

if [ -f "$ARQUIVO_DADOS" ]; then
    echo "   Descompactando $ARQUIVO_DADOS..."
    unzip -o "$ARQUIVO_DADOS" || {
        echo "❌ Erro ao descompactar. Verifique o arquivo."
        exit 1
    }
    echo "   ✓ Dados descompactados"
fi

if [ -f "$ARQUIVO_DOC" ]; then
    echo "   Descompactando $ARQUIVO_DOC..."
    unzip -o "$ARQUIVO_DOC" 2>/dev/null || echo "   ⚠️  Documentação não descompactada (não crítico)"
fi

cd ..

# Verificar arquivos esperados
echo ""
echo "4. Verificando arquivos..."

# Listar arquivos .txt (dados)
TXT_FILES=$(find "$DADOS_DIR" -maxdepth 2 -name "*.txt" -o -name "*.TXT" 2>/dev/null)

if [ -z "$TXT_FILES" ]; then
    echo "   ⚠️  Nenhum arquivo .txt encontrado"
    echo "   Listando conteúdo de $DADOS_DIR:"
    ls -lh "$DADOS_DIR"
else
    echo "   ✓ Arquivos encontrados:"
    echo "$TXT_FILES" | while read -r file; do
        SIZE=$(du -h "$file" | cut -f1)
        echo "     - $(basename $file) ($SIZE)"
    done
fi

# Procurar arquivo PES (pessoas)
PES_FILE=$(find "$DADOS_DIR" -maxdepth 2 -iname "*PES*.txt" 2>/dev/null | head -1)

if [ -n "$PES_FILE" ]; then
    echo ""
    echo "   ✓ Arquivo de pessoas identificado: $(basename $PES_FILE)"
    echo "     Tamanho: $(du -h "$PES_FILE" | cut -f1)"
    echo "     Linhas: $(wc -l < "$PES_FILE")"
else
    echo ""
    echo "   ⚠️  Arquivo PES*.txt não encontrado"
    echo "   Procure manualmente em $DADOS_DIR/"
fi

# Procurar dicionário
DICT_FILE=$(find "$DADOS_DIR" -maxdepth 2 -iname "*dicionario*" -o -iname "*layout*" -o -iname "*input*" 2>/dev/null | head -1)

if [ -n "$DICT_FILE" ]; then
    echo ""
    echo "   ✓ Dicionário/layout encontrado: $(basename $DICT_FILE)"
else
    echo ""
    echo "   ⚠️  Dicionário de variáveis não encontrado"
    echo "   Procure arquivo de layout/input em $DADOS_DIR/"
fi

echo ""
echo "======================================================================"
echo "Download Concluído!"
echo "======================================================================"
echo ""
echo "Próximos passos:"
echo ""
echo "1. Verificar dicionário de variáveis (layout FWF)"
echo "   Procurar em: $DADOS_DIR/"
echo "   Arquivos possíveis: Input_PNAD2011.txt, Dicionario_*.pdf, Layout_*.xls"
echo ""
echo "2. Ajustar script de leitura:"
echo "   Editar: 01_processar_dados.jl"
echo "   Atualizar posições das variáveis no layout FWF"
echo ""
echo "3. Executar processamento:"
echo "   julia 01_processar_dados.jl"
echo ""
echo "======================================================================"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - Verificar o dicionário oficial para posições corretas das variáveis"
echo "   - Confirmar códigos de V0302 (sexo), V0401 (cônjuge), V4706 (servidor)"
echo "   - Atualizar skill files em .claude/skills/pnad2011/ se necessário"
echo ""
echo "======================================================================"
