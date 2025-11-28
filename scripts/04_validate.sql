-- 04_VALIDATE.SQL - Checagens finais
SELECT 'Validações DW Olist' as check;

-- Contagens
SELECT 'staging_orders', COUNT(*) FROM stg_orders
UNION ALL SELECT 'oltp_orders', COUNT(*) FROM oltp_orders
UNION ALL SELECT 'fact_sales', COUNT(*) FROM fact_sales;

-- Integridade FK
SELECT 'fact_sales sem customer?', COUNT(*) FROM fact_sales WHERE sk_customer IS NULL;
SELECT 'fact_sales sem product?', COUNT(*) FROM fact_sales WHERE sk_product IS NULL;

-- NULLs críticos
SELECT 'price NULL?', COUNT(*) FROM fact_sales WHERE price IS NULL;
SELECT 'date_key NULL?', COUNT(*) FROM fact_sales WHERE date_key IS NULL;

-- Teste analítico
SELECT 'Top categoria:', dp.product_category_name, COUNT(*) as vendas
FROM fact_sales f JOIN dim_product dp ON f.sk_product = dp.sk_product
GROUP BY 2 ORDER BY 3 DESC LIMIT 3;
