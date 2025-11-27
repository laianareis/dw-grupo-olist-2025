-- 03_ETL_LOAD.SQL - DuckDB Optimized Fixed

-- 1. DIM_DATE (Corrigido: Seleção explícita da coluna gerada)
INSERT INTO dim_date
SELECT 
    ts::DATE as date_key,
    EXTRACT(YEAR FROM ts)::INT, 
    EXTRACT(QUARTER FROM ts)::INT,
    EXTRACT(MONTH FROM ts)::INT, 
    EXTRACT(DAY FROM ts)::INT,
    strftime(ts, '%A'), 
    strftime(ts, '%B'), 
    EXTRACT(WEEK FROM ts)::INT
FROM (
    SELECT generate_series::TIMESTAMP as ts 
    FROM generate_series('2016-01-01'::TIMESTAMP, '2019-01-01'::TIMESTAMP, INTERVAL '1 day')
);

-- 2. DIMS
INSERT INTO dim_product (product_id, product_category_name, product_weight_g, product_length_cm)
SELECT DISTINCT 
    p.product_id, 
    COALESCE(c.product_category_name_english, p.product_category_name),
    p.product_weight_g, 
    p.product_length_cm
FROM oltp_products p 
LEFT JOIN stg_categories c ON p.product_category_name = c.product_category_name;

INSERT INTO dim_seller (seller_id, seller_city, seller_state)
SELECT DISTINCT seller_id, seller_city, seller_state FROM oltp_sellers;

INSERT INTO dim_customer (customer_unique_id, customer_city, customer_state, zip_prefix, valid_from)
SELECT DISTINCT 
    customer_unique_id, 
    customer_city, 
    customer_state, 
    customer_zip_code_prefix,
    CURRENT_TIMESTAMP 
FROM oltp_customers;

-- 3. FACT SALES
INSERT INTO fact_sales
SELECT 
    oi.order_id,
    dc.sk_customer,
    dp.sk_product,
    ds.sk_seller,
    o.order_purchase_timestamp::DATE,
    oi.price, 
    oi.freight_value,
    op.payment_value,      
    op.payment_installments,
    o.order_status
FROM oltp_orders o
JOIN stg_order_items oi ON o.order_id = oi.order_id
JOIN oltp_customers oc ON o.customer_id = oc.customer_id
JOIN dim_customer dc ON oc.customer_unique_id = dc.customer_unique_id AND dc.is_current = TRUE
JOIN dim_product dp ON oi.product_id = dp.product_id
JOIN dim_seller ds ON oi.seller_id = ds.seller_id
LEFT JOIN (
    SELECT order_id, SUM(payment_value) as payment_value, MAX(payment_installments) as payment_installments
    FROM stg_payments
    GROUP BY order_id
) op ON o.order_id = op.order_id
WHERE o.order_purchase_timestamp::DATE BETWEEN '2016-01-01' AND '2019-01-01'; -- Garante integridade