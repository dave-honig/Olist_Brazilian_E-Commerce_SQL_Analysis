-- 01_setup.sql
-- Load the reviews CSV, verify row counts, and rename tables.


-- olist_order_reviews_dataset.csv had embedded newline characters (regular expression: \n) which broke DBeaver's default parser.
-- Using COPY with explicit QUOTE and ESCAPE settings to fix it.
-- Update the file path in the COPY command before running.
COPY olist_order_reviews_dataset
FROM 'YOUR_FILE_PATH\olist_order_reviews_dataset.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    QUOTE '"',
    ESCAPE '"'
);


-- Row counts for all nine tables
-- Expected: customers 99,441 | geolocation 1,000,163 | order_items 112,650 | payments 103,886 | reviews 99,224 | orders 99,441 | products 32,951 | sellers 3,095 | category_translation 71
SELECT 'olist_customers_dataset' AS table_name, COUNT(*) AS row_count FROM olist_customers_dataset
UNION ALL
SELECT 'olist_geolocation_dataset', COUNT(*) FROM olist_geolocation_dataset
UNION ALL
SELECT 'olist_order_items_dataset', COUNT(*) FROM olist_order_items_dataset
UNION ALL
SELECT 'olist_order_payments_dataset', COUNT(*) FROM olist_order_payments_dataset
UNION ALL
SELECT 'olist_order_reviews_dataset', COUNT(*) FROM olist_order_reviews_dataset
UNION ALL
SELECT 'olist_orders_dataset', COUNT(*) FROM olist_orders_dataset
UNION ALL
SELECT 'olist_products_dataset', COUNT(*) FROM olist_products_dataset
UNION ALL
SELECT 'olist_sellers_dataset', COUNT(*) FROM olist_sellers_dataset
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation;


-- Renaming all tables to shorter names
ALTER TABLE public.olist_customers_dataset RENAME TO customers;
ALTER TABLE public.olist_geolocation_dataset RENAME TO geolocation;
ALTER TABLE public.olist_order_items_dataset RENAME TO order_items;
ALTER TABLE public.olist_order_payments_dataset RENAME TO payments;
ALTER TABLE public.olist_order_reviews_dataset RENAME TO reviews;
ALTER TABLE public.olist_orders_dataset RENAME TO orders;
ALTER TABLE public.olist_products_dataset RENAME TO products;
ALTER TABLE public.olist_sellers_dataset RENAME TO sellers;
ALTER TABLE public.product_category_name_translation RENAME TO category_translation;
