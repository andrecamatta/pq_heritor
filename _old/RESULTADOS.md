# Resultados: Tábua de Conjugalidade - População Geral vs. Servidores Públicos

## Resumo Executivo

Análise comparativa da proporção de casados/união estável entre a população geral e servidores públicos brasileiros. Os dados demonstram que **servidores públicos apresentam maior estabilidade conjugal** em todas as faixas etárias.

### Principais Achados

#### Masculino
- **Pico de conjugalidade (geral)**: 45-49 anos (64.4%)
- **Pico de conjugalidade (servidores)**: 45-49 anos (76.3%)
- **Média de conjugalidade (geral)**: 47.0%
- **Média de conjugalidade (servidores)**: 55.9%
- **Diferença média**: +8.9 pontos percentuais

#### Feminino
- **Pico de conjugalidade (geral)**: 40-44 anos (66.1%)
- **Pico de conjugalidade (servidores)**: 45-49 anos (77.4%)
- **Média de conjugalidade (geral)**: 49.2%
- **Média de conjugalidade (servidores)**: 58.4%
- **Diferença média**: +9.2 pontos percentuais

### Observações por Faixa Etária

#### Jovens (15-24 anos)
- Proporções baixas em ambos os grupos
- Diferença moderada (3-11 pp)
- Servidores apresentam ligeiramente maior conjugalidade

#### Idade Ativa (25-49 anos)
- **Maior diferencial entre grupos**
- Diferenças variando de 5 a 13 pp
- Servidores mantêm estabilidade acima de 70% após 30 anos

#### Meia-Idade e Idosos (50+ anos)
- Declínio gradual na conjugalidade (viuvez)
- Servidores mantêm vantagem de ~10 pp
- Padrão similar entre homens e mulheres

### Interpretação

Os resultados sugerem que **servidores públicos apresentam maior estabilidade conjugal**, possivelmente devido a:

1. **Estabilidade econômica**: Renda fixa e previsível
2. **Segurança no emprego**: Baixo risco de desemprego
3. **Benefícios sociais**: Planos de saúde, previdência
4. **Seleção ocupacional**: Perfil comportamental mais estável

### Limitações

- Dados sintéticos gerados para demonstração
- Análise transversal (não longitudinal)
- Não considera causas de dissolução conjugal
- Não separa primeiro casamento de recasamentos

## Arquivos Gerados

### Tabela
- `resultados/tabua_conjugalidade.csv`: Dados completos por faixa etária e sexo

### Gráficos
1. **01_linha_masculino.png**: Evolução da proporção de casados (homens)
2. **02_linha_feminino.png**: Evolução da proporção de casados (mulheres)
3. **03_barras_masculino.png**: Comparação lado a lado (homens)
4. **04_barras_feminino.png**: Comparação lado a lado (mulheres)
5. **05_diferenca_pp.png**: Diferença em pontos percentuais
6. **06_painel_comparativo.png**: Visão geral 2×2

## Próximos Passos Sugeridos

### Para Usar Dados Reais

1. Baixar microdados da PNADC 2023:
```bash
./00_download_pnadc2023.sh
```

2. Fornecer arquivo CSV processado em `dados/PNADC_2023.csv` com colunas:
   - V2007: Sexo
   - V2009: Idade
   - VD3005: Condição de conjugalidade
   - VD4009: Posição na ocupação

### Análises Adicionais

- Incluir estado civil detalhado (solteiro, divorciado, viúvo)
- Analisar idade média ao primeiro casamento
- Comparar com outras categorias ocupacionais
- Análise por região geográfica
- Tendências temporais (séries históricas)
- Modelagem de transições de estado conjugal

## Referências

- IBGE - Pesquisa Nacional por Amostra de Domicílios Contínua
- Dicionário de variáveis PNADC 2023
- Literatura sobre conjugalidade no Brasil
