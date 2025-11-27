-- 00_STAGING.SQL - CSVs crus viram views (sem transformação)
CREATE OR REPLACE VIEW stg_orders AS SELECT * FROM read_csv_auto('.\data\olist\olist_orders_dataset.csv');
CREATE OR REPLACE VIEW stg_customers AS SELECT * FROM read_csv_auto('.\data\olist\olist_customers_dataset.csv');
CREATE OR REPLACE VIEW stg_order_items AS SELECT * FROM read_csv_auto('.\data\olist\olist_order_items_dataset.csv');
CREATE OR REPLACE VIEW stg_products AS SELECT * FROM read_csv_auto('.\data\olist\olist_products_dataset.csv');
CREATE OR REPLACE VIEW stg_sellers AS SELECT * FROM read_csv_auto('.\data\olist\olist_sellers_dataset.csv');
CREATE OR REPLACE VIEW stg_payments AS SELECT * FROM read_csv_auto('.\data\olist\olist_order_payments_dataset.csv');
CREATE OR REPLACE VIEW stg_reviews AS SELECT * FROM read_csv_auto('.\data\olist\olist_order_reviews_dataset.csv');
CREATE OR REPLACE VIEW stg_geolocation AS SELECT * FROM read_csv_auto('.\data\olist\olist_geolocation_dataset.csv');
CREATE OR REPLACE VIEW stg_categories AS SELECT * FROM read_csv_auto('.\data\olist\product_category_name_translation.csv');

-- Validação rápida
SELECT 'orders' as tabela, COUNT(*) as linhas FROM stg_orders
UNION ALL SELECT 'customers', COUNT(*) FROM stg_customers;
