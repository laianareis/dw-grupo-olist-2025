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
