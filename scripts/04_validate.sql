-- 04_VALIDATE.SQL

-- 1. Resumo da Execução
SELECT * FROM dw.etl_logs ORDER BY log_id DESC LIMIT 1;

-- 2. Teste de Unicidade de Fato (Grain Check)
SELECT 
    'Fact Uniqueness' as check_name,
    CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END as status
FROM (
    SELECT order_id, order_item_id, COUNT(*) 
    FROM dw.fact_sales 
    GROUP BY 1, 2 
    HAVING COUNT(*) > 1
);

-- 3. Teste de Integridade Referencial (Orphans)
SELECT 
    'Orphan Customers' as check_name,
    COUNT(*) as fail_count
FROM dw.fact_sales f
LEFT JOIN dw.dim_customer d ON f.sk_customer = d.sk_customer
WHERE d.sk_customer IS NULL;

-- 4. Validação Lógica SCD2
-- Não deve haver dois registros is_current=true para o mesmo ID original
SELECT 
    'SCD2 Active Flags' as check_name,
    CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END as status
FROM (
    SELECT customer_unique_id, COUNT(*) 
    FROM dw.dim_customer 
    WHERE is_current = TRUE 
    GROUP BY 1 
    HAVING COUNT(*) > 1
);

-- 5. Validação Financeira
SELECT 
    'Total Sales Value' as metric,
    SUM(total_amount) as value
FROM dw.fact_sales;