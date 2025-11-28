-- 01_OLTP.SQL
-- Camada Intermediária: Limpeza e Normalização (Silver Layer)

CREATE SCHEMA IF NOT EXISTS oltp;

-- Clientes: Deduplicação na fonte
CREATE OR REPLACE TABLE oltp.customers AS
SELECT DISTINCT 
    customer_unique_id, 
    first(customer_id) as customer_id, -- Arbitragem de ID
    first(customer_zip_code_prefix) as zip_code,
    first(customer_city) as city,
    first(customer_state) as state
FROM staging.stg_customers 
WHERE customer_unique_id IS NOT NULL
GROUP BY customer_unique_id;

-- Produtos: Tratamento de Nulos
CREATE OR REPLACE TABLE oltp.products AS
SELECT 
    product_id, 
    COALESCE(product_category_name, 'n/a') as category_name,
    COALESCE(product_weight_g, 0) as weight_g,
    COALESCE(product_length_cm, 0) as length_cm
FROM staging.stg_products 
WHERE product_id IS NOT NULL;

-- Vendedores
CREATE OR REPLACE TABLE oltp.sellers AS
SELECT DISTINCT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM staging.stg_sellers 
WHERE seller_id IS NOT NULL;

-- Pedidos: Filtro de Regra de Negócio
CREATE OR REPLACE TABLE oltp.orders AS
SELECT 
    order_id, customer_id, order_status, 
    CAST(order_purchase_timestamp AS TIMESTAMP) as purchase_ts
FROM staging.stg_orders 
WHERE order_status NOT IN ('canceled', 'unavailable') 
  AND order_purchase_timestamp IS NOT NULL;