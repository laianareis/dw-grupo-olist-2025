-- 1. Análise Temporal: Evolução mensal das vendas (quantidade e receita)
SELECT 
  d.year, d.month,
  COUNT(DISTINCT f.order_id) AS total_pedidos,
  SUM(f.price + f.freight_value) AS receita_total
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;
-- Mostra como as vendas e receita variam ao longo do tempo (ano mês)

-- 2. Ranking / TOP N: Top 10 categorias mais vendidas por receita
SELECT 
  p.product_category_name,
  SUM(f.price + f.freight_value) AS receita_categoria
FROM fact_sales f
JOIN dim_product p ON f.sk_product = p.sk_product
GROUP BY p.product_category_name
ORDER BY receita_categoria DESC
LIMIT 10;
-- Identifica as categorias campeãs de venda em valor monetário

-- 3. Agregação Multidimensional: Vendas e ticket médio por categoria e estado do cliente
SELECT 
  p.product_category_name,
  c.customer_state,
  COUNT(1) AS total_vendas,
  AVG(f.price + f.freight_value) AS ticket_medio
FROM fact_sales f
JOIN dim_product p ON f.sk_product = p.sk_product
JOIN dim_customer c ON f.sk_customer = c.sk_customer
GROUP BY p.product_category_name, c.customer_state
ORDER BY total_vendas DESC;
-- Cruzamento: qual categoria tem maior venda em quais estados e média gasta

-- 4. Análise de Cohort / Retenção: Quantidade de clientes pelo mês do primeiro pedido
WITH primeiros_pedidos AS (
  SELECT sk_customer,
         MIN(date_key) AS first_purchase_date
  FROM fact_sales
  GROUP BY sk_customer
)
SELECT 
  DATE_TRUNC('month', first_purchase_date) AS primeiro_mes,
  COUNT(DISTINCT sk_customer) AS total_clientes
FROM primeiros_pedidos
GROUP BY primeiro_mes
ORDER BY primeiro_mes;
-- Mede aquisição e fidelização ao longo do tempo pelo mês ingressado

-- 5. KPI: Ticket médio e número de pedidos por estado do cliente
SELECT 
  c.customer_state,
  AVG(f.price + f.freight_value) AS ticket_medio,
  COUNT(DISTINCT f.order_id) AS qtd_pedidos
FROM fact_sales f
JOIN dim_customer c ON f.sk_customer = c.sk_customer
GROUP BY c.customer_state
ORDER BY ticket_medio DESC;
-- Avalia o valor médio gasto e volume de pedidos por estado para foco comercial

-- ANALYTICS.SQL

-- 1. DELTA DE EXPECTATIVA (Delivery Gap vs Score)
-- Hipótese: Atraso pune severamente, antecipação tem retornos marginais.
SELECT 
    CASE 
        WHEN (o.order_delivered_customer_date::DATE - o.order_estimated_delivery_date::DATE) > 0 THEN 'Atrasado'
        WHEN (o.order_delivered_customer_date::DATE - o.order_estimated_delivery_date::DATE) < -2 THEN 'Antecipado (>2 dias)'
        ELSE 'No Prazo'
    END AS status_entrega,
    COUNT(*) as volume,
    ROUND(AVG(r.review_score), 2) as media_nota_review,
    ROUND(AVG(date_diff('day', o.order_purchase_timestamp::TIMESTAMP, o.order_delivered_customer_date::TIMESTAMP)), 1) as tempo_medio_entrega_dias
FROM oltp_orders o
JOIN stg_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered' 
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1
ORDER BY media_nota_review DESC;

-- 2. NLP HEURÍSTICO (Logística vs Produto em Notas Baixas)
-- Hipótese: Notas baixas (1-2) contendo termos logísticos indicam falha da operação, não do vendedor.
SELECT 
    CASE 
        WHEN lower(review_comment_message) SIMILAR TO '%(entreg|correio|atras|demor|prazo|chegou|extravia|recebi)%' THEN 'Reclamação Logística'
        WHEN review_comment_message IS NULL THEN 'Sem Comentário'
        ELSE 'Possível Defeito/Outros'
    END AS categoria_reclamacao,
    COUNT(*) as volume_reclamacoes,
    ROUND(AVG(review_score), 2) as media_score -- Deve ser baixo
FROM stg_reviews
WHERE review_score <= 2 -- Focando em detratores
GROUP BY 1
ORDER BY volume_reclamacoes DESC;

-- 3. SENSIBILIDADE AO FRETE (Freight Ratio)
-- Hipótese: Frete > 20% do produto mata a conversão ou a satisfação (aqui analisamos vendas concretizadas).
SELECT 
    dc.customer_state,
    ROUND(AVG(fs.freight_value), 2) as frete_medio,
    ROUND(AVG(fs.price), 2) as ticket_medio_produto,
    ROUND(AVG(fs.freight_value / NULLIF(fs.price, 0)) * 100, 2) as ratio_frete_produto_perc,
    COUNT(*) as total_vendas
FROM fact_sales fs
JOIN dim_customer dc ON fs.sk_customer = dc.sk_customer
GROUP BY 1
HAVING total_vendas > 100 -- Filtrar estados com pouco volume para significância
ORDER BY ratio_frete_produto_perc DESC;

-- 4. RECORRÊNCIA REAL (Customer Unique ID)
-- Hipótese: Olist é "One-Off" (baixa fidelidade).
WITH frequencia_compra AS (
    SELECT 
        dc.customer_unique_id,
        COUNT(DISTINCT fs.order_id) as qtd_pedidos
    FROM fact_sales fs
    JOIN dim_customer dc ON fs.sk_customer = dc.sk_customer
    GROUP BY 1
)
SELECT 
    CASE 
        WHEN qtd_pedidos = 1 THEN '1. Compra Única'
        WHEN qtd_pedidos = 2 THEN '2. Compra Recorrente (2x)'
        WHEN qtd_pedidos >= 3 THEN '3. Heavy User (3x+)'
    END AS perfil_cliente,
    COUNT(*) as qtd_clientes,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM frequencia_compra), 2) as perc_base
FROM frequencia_compra
GROUP BY 1
ORDER BY 1;

-- 5. IMPACTO DO PARCELAMENTO (Ticket vs Installments)
-- Hipótese: Parcelamento longo alavanca ticket alto.
SELECT 
    CASE 
        WHEN payment_installments = 1 THEN '1. À Vista'
        WHEN payment_installments BETWEEN 2 AND 5 THEN '2. Curto Prazo (2-5x)'
        WHEN payment_installments BETWEEN 6 AND 10 THEN '3. Médio Prazo (6-10x)'
        WHEN payment_installments > 10 THEN '4. Longo Prazo (>10x)'
        ELSE 'Outros'
    END AS faixa_parcelas,
    COUNT(DISTINCT order_id) as volume_pedidos,
    ROUND(AVG(payment_value), 2) as ticket_medio_pedido
FROM fact_sales
WHERE payment_installments > 0
GROUP BY 1
ORDER BY ticket_medio_pedido ASC;