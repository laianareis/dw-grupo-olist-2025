-- 02_DW_MODEL.SQL - DuckDB Compatible

-- 1. LIMPEZA (Ordem reversa de dependência)
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_seller;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_date;

-- Limpeza de Sequencias (Necessário no DuckDB para reiniciar IDs)
DROP SEQUENCE IF EXISTS seq_customer;
DROP SEQUENCE IF EXISTS seq_product;
DROP SEQUENCE IF EXISTS seq_seller;

-- 2. CRIAÇÃO DE SEQUÊNCIAS
CREATE SEQUENCE seq_customer START 1;
CREATE SEQUENCE seq_product START 1;
CREATE SEQUENCE seq_seller START 1;

-- 3. CRIAÇÃO DAS TABELAS

-- DIM DATA (Sem sequence, chave é a própria data)
CREATE TABLE dim_date (
    date_key DATE PRIMARY KEY,
    year INT, 
    quarter INT, 
    month INT, 
    day_of_month INT,
    day_name VARCHAR(20), 
    month_name VARCHAR(20), 
    week_of_year INT
);

-- DIM CUSTOMER
CREATE TABLE dim_customer (
    sk_customer INTEGER PRIMARY KEY DEFAULT nextval('seq_customer'),
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_city VARCHAR(100),
    customer_state VARCHAR(2),
    zip_prefix VARCHAR(10),
    valid_from TIMESTAMP,
    valid_to TIMESTAMP DEFAULT '9999-12-31 23:59:59',
    is_current BOOLEAN DEFAULT TRUE
);

-- DIM PRODUTO
CREATE TABLE dim_product (
    sk_product INTEGER PRIMARY KEY DEFAULT nextval('seq_product'),
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_weight_g NUMERIC,
    product_length_cm NUMERIC
);

-- DIM VENDEDOR
CREATE TABLE dim_seller (
    sk_seller INTEGER PRIMARY KEY DEFAULT nextval('seq_seller'),
    seller_id VARCHAR(50),
    seller_city VARCHAR(100),
    seller_state VARCHAR(2)
);

-- FACT SALES
CREATE TABLE fact_sales (
    order_id VARCHAR(50),
    sk_customer INTEGER REFERENCES dim_customer(sk_customer),
    sk_product INTEGER REFERENCES dim_product(sk_product),
    sk_seller INTEGER REFERENCES dim_seller(sk_seller),
    date_key DATE REFERENCES dim_date(date_key),
    price NUMERIC, 
    freight_value NUMERIC,
    payment_value NUMERIC, 
    payment_installments INT,
    order_status VARCHAR(20)
);