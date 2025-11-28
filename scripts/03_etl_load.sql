-- 03_ETL_LOAD.SQL
-- Pipeline com Tratamento de Erros, Logs Persistentes e Correção de Join

-- ====================================================================
-- ETAPA 1: INICIALIZAÇÃO DO LOG (Fora da Transação de Carga)
-- ====================================================================
INSERT INTO dw.etl_logs (log_id, process_name, status) 
VALUES (nextval('seq_log_id'), 'ETL_MAIN_BATCH', 'RUNNING');

SET VARIABLE v_log_id = (SELECT MAX(log_id) FROM dw.etl_logs);

-- ====================================================================
-- ETAPA 2: CARGA TRANSACIONAL
-- ====================================================================
BEGIN TRANSACTION;

    -- 2.1. FAIL FAST
    SELECT CASE WHEN COUNT(*) = 0 THEN 1/0 ELSE 1 END FROM staging.stg_orders;

    -- 2.2. DIM_DATE
    INSERT INTO dw.dim_date
    SELECT 
        CAST(strftime(ts, '%Y%m%d') AS INTEGER),
        ts::DATE,
        EXTRACT(YEAR FROM ts),
        EXTRACT(QUARTER FROM ts),
        EXTRACT(MONTH FROM ts),
        strftime(ts, '%B'),
        strftime(ts, '%A')
    FROM (
        SELECT generate_series::TIMESTAMP as ts 
        FROM generate_series('2016-01-01'::TIMESTAMP, '2020-01-01'::TIMESTAMP, INTERVAL '1 day')
    ) WHERE NOT EXISTS (SELECT 1 FROM dw.dim_date);

    -- 2.3. DIMENSIONS (SCD1)
    
    -- Product
    INSERT INTO dw.dim_product (product_id, category_name, weight_g)
    SELECT p.product_id, COALESCE(t.product_category_name_english, p.category_name), p.weight_g
    FROM oltp.products p
    LEFT JOIN staging.stg_categories t ON p.category_name = t.product_category_name
    ON CONFLICT (product_id) DO UPDATE 
    SET category_name = EXCLUDED.category_name, weight_g = EXCLUDED.weight_g;

    -- Seller
    INSERT INTO dw.dim_seller (seller_id, city, state)
    SELECT seller_id, seller_city, seller_state FROM oltp.sellers
    ON CONFLICT (seller_id) DO UPDATE SET city = EXCLUDED.city, state = EXCLUDED.state;

    -- 2.4. DIM_CUSTOMER (SCD2 Logic)
    
    CREATE TEMP TABLE tmp_customer_source AS
    SELECT customer_unique_id, city, state, md5(concat(city, state)) as row_hash
    FROM oltp.customers;

    UPDATE dw.dim_customer
    SET valid_to = CURRENT_TIMESTAMP, is_current = FALSE
    WHERE sk_customer IN (
        SELECT dim.sk_customer
        FROM dw.dim_customer dim
        JOIN tmp_customer_source src ON dim.customer_unique_id = src.customer_unique_id
        WHERE dim.is_current = TRUE AND dim.record_hash <> src.row_hash
    );

    INSERT INTO dw.dim_customer (customer_unique_id, city, state, valid_from, record_hash)
    SELECT src.customer_unique_id, src.city, src.state, CURRENT_TIMESTAMP, src.row_hash
    FROM tmp_customer_source src
    LEFT JOIN dw.dim_customer dim ON src.customer_unique_id = dim.customer_unique_id AND dim.is_current = TRUE
    WHERE dim.sk_customer IS NULL;

    DROP TABLE tmp_customer_source;

    -- 2.5. FACT SALES
    
    DELETE FROM dw.fact_sales WHERE order_id IN (SELECT order_id FROM oltp.orders);

    CREATE TEMP TABLE tmp_payments AS
    SELECT 
        order_id,
        MAX(payment_installments) as max_installments,
        FIRST(payment_type) as main_type
    FROM staging.stg_payments
    GROUP BY order_id;

    INSERT INTO dw.fact_sales (
        order_id, order_item_id, sk_customer, sk_product, sk_seller, date_key, 
        price, freight_value, total_amount, 
        payment_installments, payment_type
    )
    SELECT 
        o.order_id, 
        oi.order_item_id, 
        dc.sk_customer, 
        dp.sk_product, 
        ds.sk_seller,
        CAST(strftime(o.purchase_ts, '%Y%m%d') AS INTEGER),
        oi.price, 
        oi.freight_value, 
        (oi.price + oi.freight_value),
        COALESCE(pay.max_installments, 1), -- Default 1 se nulo
        COALESCE(pay.main_type, 'unknown')
    FROM oltp.orders o
    -- Join com Order Items
    JOIN staging.stg_order_items oi ON o.order_id = oi.order_id
    -- RESOLUÇÃO DO CLIENTE: Order -> Staging Customer (Traduz ID) -> Dim Customer (Pega SK)
    JOIN staging.stg_customers sc ON o.customer_id = sc.customer_id
    JOIN dw.dim_customer dc ON sc.customer_unique_id = dc.customer_unique_id
        AND o.purchase_ts >= dc.valid_from AND o.purchase_ts < dc.valid_to
    -- Join Dimensions
    JOIN dw.dim_product dp ON oi.product_id = dp.product_id
    JOIN dw.dim_seller ds ON oi.seller_id = ds.seller_id
    LEFT JOIN tmp_payments pay ON o.order_id = pay.order_id; -- LEFT JOIN pois pode não ter pagamento
    
    DROP TABLE tmp_payments;

-- ====================================================================
-- ETAPA 3: FINALIZAÇÃO DO LOG
-- ====================================================================
UPDATE dw.etl_logs 
SET end_time = CURRENT_TIMESTAMP, 
    status = 'SUCCESS', 
    rows_affected = (SELECT COUNT(*) FROM dw.fact_sales)
WHERE log_id = getvariable('v_log_id');