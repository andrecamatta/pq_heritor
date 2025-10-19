# Download e Fonte de Dados - PNADC 2023

## Fonte Oficial

**PNAD Contínua 2023 Anual - Visita 5**
- **Instituição**: IBGE (Instituto Brasileiro de Geografia e Estatística)
- **URL FTP**: https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_continua/Anual/Microdados/Visita/Visita_5/Dados/
- **Arquivo**: `PNADC_2023_visita5_20250822.zip`
- **Tamanho**: ~167 MB (compactado), ~1.4 GB (descompactado)
- **Atualização**: 22 de agosto de 2025
- **Ponderação**: Calibrada com Censo 2022

## O que é a Visita 5?

A PNAD Contínua acompanha os mesmos domicílios por 5 trimestres consecutivos (5 visitas). A **Visita 5** corresponde ao trimestre final de cada domicílio na amostra, e os dados anuais são baseados nesta última visita.

**Por que usar Visita 5?**
- Dados anuais (12 meses de referência)
- Informações mais completas sobre trabalho e rendimento
- Comparável com PNAD Anual (2011 e anteriores)
- Maior estabilidade nas estimativas

## Script de Download Automatizado

### Localização
`conjugality/00_download_pnadc2023.sh`

### Código Completo

```bash
#!/bin/bash
#
# 00_download_pnadc2023.sh
# Download dos microdados da PNAD Contínua 2023 Anual (5ª visita)
#

set -e  # Exit on error

echo "=================================="
echo "Download PNAD Contínua 2023 Anual"
echo "=================================="

# Diretório de destino
DATA_DIR="../data_pnadc2023"
mkdir -p "$DATA_DIR"

# URL IBGE PNADC 2023 Visita 5
BASE_URL="https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_continua/Anual/Microdados/Visita/Visita_5/Dados"
FILE_NAME="PNADC_2023_visita5_20250822.zip"

echo ""
echo "[1/3] Baixando PNADC 2023 Anual (5ª visita)..."
echo "URL: $BASE_URL/$FILE_NAME"
echo "Destino: $DATA_DIR/"
echo ""
echo "Nota: Arquivo com ponderação atualizada (2025-08-22)"
echo ""

wget -c -O "$DATA_DIR/$FILE_NAME" "$BASE_URL/$FILE_NAME" 2>&1 | tail -20

echo ""
echo "[2/3] Verificando download..."
if [ -f "$DATA_DIR/$FILE_NAME" ]; then
    echo "✓ Arquivo baixado: $FILE_NAME"
    ls -lh "$DATA_DIR/$FILE_NAME"
else
    echo "✗ Erro: Arquivo não encontrado"
    exit 1
fi

echo ""
echo "[3/3] Extraindo arquivos..."
cd "$DATA_DIR"
unzip -o "$FILE_NAME"
echo "✓ Extração concluída"

echo ""
echo "=================================="
echo "✓ Download completo!"
echo "=================================="
echo ""
echo "Arquivos extraídos em: $DATA_DIR/"
echo ""
echo "Próximo passo:"
echo "  julia conjugality/01_pnadc2023_empirical_conjugality.jl"
echo ""
```

### Como Usar

```bash
# Navegue até o diretório conjugality
cd conjugality

# Torne o script executável (primeira vez)
chmod +x 00_download_pnadc2023.sh

# Execute o download
./00_download_pnadc2023.sh
```

### Output Esperado

```
==================================
Download PNAD Contínua 2023 Anual
==================================

[1/3] Baixando PNADC 2023 Anual (5ª visita)...
[... progresso do download ...]

[2/3] Verificando download...
✓ Arquivo baixado: PNADC_2023_visita5_20250822.zip
-rw-rw-r-- 1 user user 167M ago 21 15:37 PNADC_2023_visita5_20250822.zip

[3/3] Extraindo arquivos...
Archive:  PNADC_2023_visita5_20250822.zip
  inflating: PNADC_2023_visita5.txt
✓ Extração concluída

==================================
✓ Download completo!
==================================

Arquivos extraídos em: ../data_pnadc2023/
```

## Estrutura de Diretórios

Após o download, a estrutura será:

```
pq_heritor/
├── data_pnadc2023/
│   ├── PNADC_2023_visita5_20250822.zip  (arquivo original)
│   ├── PNADC_2023_visita5.txt           (microdados - 1.4 GB)
│   └── input_PNADC_2023_visita5.txt     (dicionário SAS)
└── conjugality/
    └── 00_download_pnadc2023.sh
```

## Arquivos Importantes

### 1. PNADC_2023_visita5.txt
- **Tamanho**: ~1.4 GB
- **Formato**: Fixed-Width Format (FWF)
- **Linhas**: ~560 mil registros (pessoas)
- **Largura**: 4000 caracteres por linha
- **Encoding**: Latin-1 (ISO-8859-1)

### 2. input_PNADC_2023_visita5.txt
- **Tipo**: Dicionário de posições (formato SAS)
- **Conteúdo**: Posições FWF e nomes de variáveis
- **Uso**: Referência para parsing

## Download Manual (Alternativa)

Se o script automático falhar:

1. Acesse o FTP do IBGE:
   ```
   https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_continua/Anual/Microdados/Visita/Visita_5/Dados/
   ```

2. Baixe o arquivo:
   ```
   PNADC_2023_visita5_20250822.zip
   ```

3. Extraia para `data_pnadc2023/`:
   ```bash
   mkdir -p data_pnadc2023
   cd data_pnadc2023
   unzip PNADC_2023_visita5_20250822.zip
   ```

## Verificação de Integridade

### Tamanhos Esperados
```bash
# Arquivo compactado
ls -lh data_pnadc2023/PNADC_2023_visita5_20250822.zip
# ~167 MB

# Arquivo descompactado
ls -lh data_pnadc2023/PNADC_2023_visita5.txt
# ~1.4 GB

# Contar linhas
wc -l data_pnadc2023/PNADC_2023_visita5.txt
# Deve retornar algo próximo de 560.000 linhas
```

### Validação Rápida
```bash
# Ver primeiras linhas (observe se tem estrutura)
head -5 data_pnadc2023/PNADC_2023_visita5.txt

# Ver dicionário
head -100 data_pnadc2023/input_PNADC_2023_visita5.txt
```

## Atualizações e Versões

### Histórico de Versões
- **20250822** (atual): Ponderação calibrada com Censo 2022
- **20240621**: Versão anterior (ponderação com Censo 2010)

### Como Verificar a Versão
O nome do arquivo contém a data de atualização:
```
PNADC_2023_visita5_YYYYMMDD.zip
                   ^^^^^^^^
                   20250822 = 22 de agosto de 2025
```

### Quando Atualizar
O IBGE periodicamente atualiza os pesos amostrais. Verifique:
- Página oficial PNADC: https://www.ibge.gov.br/estatisticas/sociais/trabalho/17270-pnad-continua.html
- Notas técnicas e comunicados do IBGE
- Última atualização no FTP

## Documentação Adicional

### No FTP IBGE
- **Documentação**: `.../Documentacao/`
- **Dicionários**: Planilhas Excel com códigos de variáveis
- **Notas metodológicas**: PDFs com detalhes da pesquisa

### Links Úteis
- PNADC Principal: https://www.ibge.gov.br/estatisticas/sociais/trabalho/17270-pnad-continua.html
- FTP Geral PNADC: https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_continua/
- Notas técnicas: Disponíveis no site do IBGE

## Troubleshooting

### Erro: wget não instalado
```bash
# Ubuntu/Debian
sudo apt-get install wget

# macOS
brew install wget
```

### Erro: unzip não instalado
```bash
# Ubuntu/Debian
sudo apt-get install unzip

# macOS
brew install unzip
```

### Erro: Espaço em disco insuficiente
- Arquivo compactado: 167 MB
- Arquivo descompactado: 1.4 GB
- **Total necessário**: ~1.6 GB

### Download interrompido
O script usa `wget -c` que permite continuar downloads interrompidos:
```bash
# Basta executar novamente
./00_download_pnadc2023.sh
```

## Próximos Passos

Após o download bem-sucedido:
1. **Parser**: Veja [02_parsing.md](02_parsing.md) para parsear o arquivo FWF
2. **Variáveis**: Consulte [03_variables_dictionary.md](03_variables_dictionary.md) para entender as variáveis
3. **Análise**: Use [09_examples.md](09_examples.md) para exemplos completos
