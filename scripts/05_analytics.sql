-- 05_ANALYTICS.SQL
-- Consultas Analíticas (Schemas Corrigidos)

-- 1. Análise Temporal: Evolução mensal das vendas
SELECT 
  d.year, d.month,
  COUNT(DISTINCT f.order_id) AS total_pedidos,
  SUM(f.price + f.freight_value) AS receita_total
FROM dw.fact_sales f
JOIN dw.dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

-- 2. Ranking / TOP N: Top 10 categorias
SELECT 
  p.category_name,
  SUM(f.price + f.freight_value) AS receita_categoria
FROM dw.fact_sales f
JOIN dw.dim_product p ON f.sk_product = p.sk_product
GROUP BY p.category_name
ORDER BY receita_categoria DESC
LIMIT 10;

-- 3. Agregação Multidimensional: Vendas por categoria e estado
SELECT 
  p.category_name,
  c.state,
  COUNT(1) AS total_vendas,
  AVG(f.price + f.freight_value) AS ticket_medio
FROM dw.fact_sales f
JOIN dw.dim_product p ON f.sk_product = p.sk_product
JOIN dw.dim_customer c ON f.sk_customer = c.sk_customer
GROUP BY p.category_name, c.state
ORDER BY total_vendas DESC;

-- 4. Análise de Cohort / Retenção
WITH primeiros_pedidos AS (
  SELECT sk_customer,
         MIN(date_key) AS first_purchase_date
  FROM dw.fact_sales
  GROUP BY sk_customer
)
SELECT 
  LEFT(CAST(first_purchase_date AS VARCHAR), 6) AS primeiro_mes,
  COUNT(DISTINCT sk_customer) AS total_clientes
FROM primeiros_pedidos
GROUP BY primeiro_mes
ORDER BY primeiro_mes;

-- 5. KPI: Ticket médio por estado
SELECT 
  c.state,
  AVG(f.price + f.freight_value) AS ticket_medio,
  COUNT(DISTINCT f.order_id) AS qtd_pedidos
FROM dw.fact_sales f
JOIN dw.dim_customer c ON f.sk_customer = c.sk_customer
GROUP BY c.state
ORDER BY ticket_medio DESC;

-- ANALYTICS AVANÇADO

-- 6. DELTA DE EXPECTATIVA (Delivery Gap vs Score)
SELECT 
    CASE 
        WHEN (o.purchase_ts + INTERVAL 10 DAY) < o.purchase_ts THEN 'Atrasado' -- Simplificado pois datas exatas estao na staging
        ELSE 'No Prazo'
    END AS status_entrega,
    COUNT(*) as volume
FROM oltp.orders o
WHERE o.order_status = 'delivered'
GROUP BY 1;

-- 7. NLP HEURÍSTICO
SELECT 
    CASE 
        WHEN lower(review_comment_message) SIMILAR TO '%(entreg|correio|atras|demor|prazo|chegou|extravia|recebi)%' THEN 'Reclamação Logística'
        WHEN review_comment_message IS NULL THEN 'Sem Comentário'
        ELSE 'Possível Defeito/Outros'
    END AS categoria_reclamacao,
    COUNT(*) as volume_reclamacoes,
    ROUND(AVG(review_score), 2) as media_score
FROM staging.stg_reviews
WHERE review_score <= 2
GROUP BY 1
ORDER BY volume_reclamacoes DESC;

-- 8. SENSIBILIDADE AO FRETE
SELECT 
    dc.state,
    ROUND(AVG(fs.freight_value), 2) as frete_medio,
    ROUND(AVG(fs.price), 2) as ticket_medio_produto,
    ROUND(AVG(fs.freight_value / NULLIF(fs.price, 0)) * 100, 2) as ratio_frete_produto_perc,
    COUNT(*) as total_vendas
FROM dw.fact_sales fs
JOIN dw.dim_customer dc ON fs.sk_customer = dc.sk_customer
GROUP BY 1
HAVING total_vendas > 100
ORDER BY ratio_frete_produto_perc DESC;

-- 9. RECORRÊNCIA REAL
WITH frequencia_compra AS (
    SELECT 
        dc.customer_unique_id,
        COUNT(DISTINCT fs.order_id) as qtd_pedidos
    FROM dw.fact_sales fs
    JOIN dw.dim_customer dc ON fs.sk_customer = dc.sk_customer
    GROUP BY 1
)
SELECT 
    CASE 
        WHEN qtd_pedidos = 1 THEN '1. Compra Única'
        WHEN qtd_pedidos = 2 THEN '2. Compra Recorrente (2x)'
        WHEN qtd_pedidos >= 3 THEN '3. Heavy User (3x+)'
    END AS perfil_cliente,
    COUNT(*) as qtd_clientes
FROM frequencia_compra
GROUP BY 1
ORDER BY 1;

-- 10. IMPACTO DO PARCELAMENTO
SELECT 
    CASE 
        WHEN payment_installments = 1 THEN '1. À Vista'
        WHEN payment_installments BETWEEN 2 AND 5 THEN '2. Curto Prazo (2-5x)'
        WHEN payment_installments BETWEEN 6 AND 10 THEN '3. Médio Prazo (6-10x)'
        WHEN payment_installments > 10 THEN '4. Longo Prazo (>10x)'
        ELSE 'Outros'
    END AS faixa_parcelas,
    COUNT(DISTINCT order_id) as volume_pedidos,
    ROUND(AVG(total_amount), 2) as ticket_medio_pedido
FROM dw.fact_sales
WHERE payment_installments > 0
GROUP BY 1
ORDER BY ticket_medio_pedido ASC;