-- 06_PERFORMANCE.SQL
-- Objetivo: Demonstrar ganho de performance via Indexação e Pré-agregação (Gold Layer)

-- ====================================================================
-- 1. BASELINE: Query Lenta (Join em Star Schema Completo)
-- ====================================================================
-- Cenário: Relatório de vendas totais por Categoria e Estado (Granularidade Mensal)
-- Executa joins em 4 tabelas e agrega milhões de linhas da Fato.

SELECT '--- INICIO ANALISE QUERY LENTA ---' as log;

EXPLAIN ANALYZE -- O output mostrará o tempo de "Execution Time"
SELECT 
    d.year,
    d.month_name,
    dp.category_name,
    dc.state,
    COUNT(f.order_id) as total_orders,
    SUM(f.total_amount) as total_revenue,
    AVG(f.freight_value) as avg_freight
FROM dw.fact_sales f
JOIN dw.dim_date d ON f.date_key = d.date_key
JOIN dw.dim_product dp ON f.sk_product = dp.sk_product
JOIN dw.dim_customer dc ON f.sk_customer = dc.sk_customer
GROUP BY 1, 2, 3, 4
ORDER BY 1, 3;

-- ====================================================================
-- 2. TUNING: Implementação de Índices (B-Tree)
-- ====================================================================
-- DuckDB já otimiza scans, mas índices aceleram Joins e Filtros pontuais.

CREATE INDEX IF NOT EXISTS idx_fact_date ON dw.fact_sales(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_prod ON dw.fact_sales(sk_product);
CREATE INDEX IF NOT EXISTS idx_fact_cust ON dw.fact_sales(sk_customer);

-- ====================================================================
-- 3. MATERIALIZAÇÃO: Criação da Tabela Agregada (Data Mart)
-- ====================================================================
-- "Sobe" o grão do dado de "Item de Pedido" para "Mensal por Categoria/Estado"
-- Reduz drasticamente a cardinalidade (Número de linhas).

DROP TABLE IF EXISTS dw.agg_sales_monthly;

CREATE TABLE dw.agg_sales_monthly AS
SELECT 
    d.year,
    d.month, -- Usando numérico para ordenação correta
    d.month_name,
    dp.category_name,
    dc.state,
    COUNT(f.order_id) as total_orders,
    SUM(f.total_amount) as total_revenue,
    AVG(f.freight_value) as avg_freight,
    CURRENT_TIMESTAMP as refreshed_at
FROM dw.fact_sales f
JOIN dw.dim_date d ON f.date_key = d.date_key
JOIN dw.dim_product dp ON f.sk_product = dp.sk_product
JOIN dw.dim_customer dc ON f.sk_customer = dc.sk_customer
GROUP BY 1, 2, 3, 4, 5;

-- Checkpoint: Verificar redução de volume
SELECT 
    (SELECT COUNT(*) FROM dw.fact_sales) as linhas_fato,
    (SELECT COUNT(*) FROM dw.agg_sales_monthly) as linhas_agregada,
    ROUND((SELECT COUNT(*) FROM dw.agg_sales_monthly)::FLOAT / (SELECT COUNT(*) FROM dw.fact_sales)::FLOAT * 100, 2) || '%' as taxa_compressao;

-- ====================================================================
-- 4. VALIDAÇÃO: Query Otimizada (Leitura direta do Agregado)
-- ====================================================================
-- Cenário: O mesmo relatório, agora lendo da tabela otimizada.

SELECT '--- INICIO ANALISE QUERY OTIMIZADA ---' as log;

EXPLAIN ANALYZE
SELECT 
    year,
    month_name,
    category_name,
    state,
    total_orders,
    total_revenue,
    avg_freight
FROM dw.agg_sales_monthly
WHERE year = 2017 -- Exemplo de filtro comum
ORDER BY year, category_name;