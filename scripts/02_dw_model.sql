-- 02_DW_MODEL.SQL
-- Definição DDL do Data Warehouse

CREATE SCHEMA IF NOT EXISTS dw;

-- 1. Tabela de Controle de Logs
CREATE TABLE IF NOT EXISTS dw.etl_logs (
    log_id INTEGER PRIMARY KEY,
    process_name VARCHAR,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    rows_affected INT,
    status VARCHAR,
    error_message VARCHAR
);
CREATE SEQUENCE IF NOT EXISTS seq_log_id START 1;

-- 2. Sequências para Sk (Surrogate Keys)
CREATE SEQUENCE IF NOT EXISTS seq_dim_customer START 1;
CREATE SEQUENCE IF NOT EXISTS seq_dim_product START 1;
CREATE SEQUENCE IF NOT EXISTS seq_dim_seller START 1;
CREATE SEQUENCE IF NOT EXISTS seq_fact_sales START 1;

-- 3. Dimensões

-- DIM DATE (Estática)
CREATE TABLE IF NOT EXISTS dw.dim_date (
    date_key INTEGER PRIMARY KEY, -- Format: YYYYMMDD
    full_date DATE,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR,
    day_of_week VARCHAR
);

-- DIM CUSTOMER (SCD Type 2)
CREATE TABLE IF NOT EXISTS dw.dim_customer (
    sk_customer INTEGER PRIMARY KEY DEFAULT nextval('seq_dim_customer'),
    customer_unique_id VARCHAR NOT NULL,
    city VARCHAR,
    state VARCHAR,
    -- Colunas de Controle SCD2
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP DEFAULT CAST('9999-12-31' AS TIMESTAMP),
    is_current BOOLEAN DEFAULT TRUE,
    record_hash VARCHAR -- Para detecção de mudanças
);

-- DIM PRODUCT (SCD Type 1 - Sobrescrita simples para este exemplo)
CREATE TABLE IF NOT EXISTS dw.dim_product (
    sk_product INTEGER PRIMARY KEY DEFAULT nextval('seq_dim_product'),
    product_id VARCHAR NOT NULL,
    category_name VARCHAR,
    weight_g NUMERIC,
    UNIQUE(product_id) -- Índice de busca
);

-- DIM SELLER (SCD Type 0/1)
CREATE TABLE IF NOT EXISTS dw.dim_seller (
    sk_seller INTEGER PRIMARY KEY DEFAULT nextval('seq_dim_seller'),
    seller_id VARCHAR NOT NULL,
    city VARCHAR,
    state VARCHAR,
    UNIQUE(seller_id)
);

-- 4. Fatos

-- FACT SALES (Transacional)
CREATE TABLE IF NOT EXISTS dw.fact_sales (
    sk_sales INTEGER PRIMARY KEY DEFAULT nextval('seq_fact_sales'),
    order_id VARCHAR NOT NULL,
    order_item_id INTEGER NOT NULL, -- Garante grão único
    -- Foreign Keys
    sk_customer INTEGER REFERENCES dw.dim_customer(sk_customer),
    sk_product INTEGER REFERENCES dw.dim_product(sk_product),
    sk_seller INTEGER REFERENCES dw.dim_seller(sk_seller),
    date_key INTEGER REFERENCES dw.dim_date(date_key),
    -- Métricas
    price NUMERIC,
    freight_value NUMERIC,
    total_amount NUMERIC,
    -- Auditoria
    payment_installments INTEGER, 
    payment_type VARCHAR,
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);