#!/bin/bash
# Script para download dos microdados da PNAD Contínua 2023 Anual (Visita 5)
# URL base: ftp.ibge.gov.br
# Referência: .claude/skills/pnadc2023/01_data_source.md

set -e

DADOS_DIR="dados"
mkdir -p $DADOS_DIR

echo "==================================="
echo "Download PNAD Contínua 2023 Anual"
echo "==================================="

# PNADC 2023 - Anual (Visita 5) - Ponderação calibrada com Censo 2022
URL_BASE="https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_continua/Anual/Microdados/Visita/Visita_5/Dados"
ARQUIVO="PNADC_2023_visita5_20250822.zip"

cd $DADOS_DIR

if [ -f "$ARQUIVO" ]; then
    echo "Arquivo $ARQUIVO já existe. Pulando download..."
else
    echo "Baixando $ARQUIVO..."
    wget -c "$URL_BASE/$ARQUIVO" || curl -O "$URL_BASE/$ARQUIVO"
fi

if [ -f "$ARQUIVO" ]; then
    echo "Descompactando $ARQUIVO..."
    unzip -o "$ARQUIVO"
    echo "Download e extração concluídos!"
else
    echo "ERRO: Não foi possível baixar o arquivo."
    exit 1
fi

cd ..

echo ""
echo "Arquivos disponíveis em: $DADOS_DIR/"
ls -lh $DADOS_DIR/*.txt 2>/dev/null | head -5 || echo "Nenhum arquivo .txt encontrado ainda"
