# Data Warehouse Olist (DuckDB + Python)

Pipeline ELT (Extract, Load, Transform) para processamento de dados do E-commerce Olist. O projeto ingere dados crus (CSV), normaliza em camada OLTP e transforma em um modelo dimensional (Star Schema) utilizando DuckDB. Scripts Python geram visualizações analíticas (Dashboards e KPIs).

## Arquitetura

O fluxo de dados segue a arquitetura Medalhão simplificada:

1.  **Bronze (Staging):** Views sobre arquivos CSV (Lazy Loading).
2.  **Silver (OLTP):** Limpeza, tipagem e deduplicação (3FN).
3.  **Gold (DW):** Modelagem Dimensional (Star Schema) para OLAP.
4.  **Analytics:** Geração de gráficos estáticos e interativos.

## Estrutura de Diretórios

```text
.
├── data/
│   └── olist/                  # Arquivos CSV do dataset Olist (Obrigatório)
├── scripts/
│   ├── 00_staging.sql          # Criação das Views sobre CSVs
│   ├── 01_oltp.sql             # Limpeza e Normalização
│   ├── 02_dw_model.sql         # DDL do Data Warehouse (Fato/Dimensões)
│   ├── 03_etl_load.sql         # Carga de dados e lógica SCD
│   ├── 04_validate.sql         # Testes de qualidade de dados
│   ├── 05_analytics.sql        # Queries analíticas SQL
│   └── 06_performance.sql      # Otimização e índices
├── visualizacoes/              # Saída dos gráficos gerados
│   └── gerar_graficos.py       # Gerador de KPIs e Dashboards
├── olist_dw.duckdb             # Banco de dados (Gerado automaticamente)
├── run_all.ps1                 # Orchestrator via PowerShell

└── README.md
```
## Requisitos

- Python 3.10+
- PowerShell 5.1+ (Para execução via script .ps1)
- Dados: Dataset Olist (Kaggle) descompactado em ./data/olist/
- DuckDB CLI (arquivo duckdb.exe) disponível em https://duckdb.org/docs/installation/cli

## Dependências Python

Execute o comando abaixo para instalar as bibliotecas necessárias (ambiante venv recomendado):

```Bash
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install duckdb pandas matplotlib seaborn plotly
```

## Configuração dos Dados
Certifique-se de que os arquivos .csv estejam na pasta correta. A estrutura esperada é:

- `./data/olist/olist_orders_dataset.csv`

- `./data/olist/olist_customers_dataset.csv`

- `./data/olist/olist_order_items_dataset.csv`

- `./data/olist/olist_products_dataset.csv`

- `./data/olist/olist_sellers_dataset.csv`

- `./data/olist/olist_order_payments_dataset.csv`

- `./data/olist/olist_order_reviews_dataset.csv`

- `./data/olist/product_category_name_translation.csv`

## Execução

Para rodar os scripts SQL sequencialmente:

```PowerShell
./run_all.ps1
```

## Geração de Visualizações
Caso queira regenerar apenas os gráficos sem recarregar o banco de dados:

```Bash
.\.venv\Scripts\Activate.ps1
python visualizacoes\gerar_graficos.py
```

Os gráficos serão salvos na pasta visualizacoes/:

PNG: Gráficos estáticos (Boxplots, Barras).

HTML: Dashboards interativos (Plotly).

## Modelo de Dados (DW)
- Fato: dw.fact_sales (Granularidade: Item do Pedido).

- Dimensões:

  - dw.dim_customer (SCD Tipo 2 - Histórico de Endereço).

  - dw.dim_product (SCD Tipo 1).

  - dw.dim_seller (SCD Tipo 0).

  - dw.dim_date (Calendário canônico).

Feito por:

- Laiana Reis / https://github.com/laianareis

- Nicoli Mecati / https://github.com/mecati

- Riquelmy Silva / https://github.com/riquelmyhsilva
