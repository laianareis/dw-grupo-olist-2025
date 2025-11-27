-- 01_OLTP.SQL - Normalizado e limpo
DROP TABLE IF EXISTS oltp_customers;
DROP TABLE IF EXISTS oltp_products;
DROP TABLE IF EXISTS oltp_sellers;
DROP TABLE IF EXISTS oltp_orders;

-- Clientes (remove duplicatas customer_unique_id)
CREATE TABLE oltp_customers AS
SELECT DISTINCT customer_unique_id, customer_id, customer_zip_code_prefix,
       customer_city, customer_state
FROM stg_customers WHERE customer_unique_id IS NOT NULL;

-- Produtos (limpa NULLs)
CREATE TABLE oltp_products AS
SELECT product_id, product_category_name,
       COALESCE(product_weight_g, 0) as product_weight_g,
       COALESCE(product_length_cm, 0) as product_length_cm
FROM stg_products WHERE product_id IS NOT NULL;

-- Vendedores
CREATE TABLE oltp_sellers AS
SELECT DISTINCT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM stg_sellers WHERE seller_id IS NOT NULL;

-- Pedidos (status válidos)
CREATE TABLE oltp_orders AS
SELECT order_id, customer_id, order_status, order_purchase_timestamp,
       order_delivered_carrier_date, order_delivered_customer_date,
       order_estimated_delivery_date
FROM stg_orders 
WHERE order_status IN ('delivered', 'shipped', 'invoiced', 'processing', 'canceled')
  AND order_purchase_timestamp IS NOT NULL;
