-- 00_STAGING.SQL
-- Camada de Abstração sobre CSVs (ELT)

-- Garante schemas limpos
CREATE SCHEMA IF NOT EXISTS staging;

-- Views com leitura otimizada (Lazy Loading)
CREATE OR REPLACE VIEW staging.stg_orders AS 
SELECT * FROM read_csv_auto('./data/olist/olist_orders_dataset.csv', normalize_names=True);

CREATE OR REPLACE VIEW staging.stg_customers AS 
SELECT * FROM read_csv_auto('./data/olist/olist_customers_dataset.csv', normalize_names=True);

CREATE OR REPLACE VIEW staging.stg_order_items AS 
SELECT * FROM read_csv_auto('./data/olist/olist_order_items_dataset.csv', normalize_names=True);

CREATE OR REPLACE VIEW staging.stg_products AS 
SELECT * FROM read_csv_auto('./data/olist/olist_products_dataset.csv', normalize_names=True);

CREATE OR REPLACE VIEW staging.stg_sellers AS 
SELECT * FROM read_csv_auto('./data/olist/olist_sellers_dataset.csv', normalize_names=True);

CREATE OR REPLACE VIEW staging.stg_payments AS 
SELECT * FROM read_csv_auto('./data/olist/olist_order_payments_dataset.csv', normalize_names=True);

CREATE OR REPLACE VIEW staging.stg_categories AS 
SELECT * FROM read_csv_auto('./data/olist/product_category_name_translation.csv', normalize_names=True);

CREATE OR REPLACE VIEW staging.stg_reviews AS 
SELECT * FROM read_csv_auto('./data/olist/olist_order_reviews_dataset.csv', normalize_names=True);