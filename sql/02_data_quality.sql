-- 02_data_quality.sql
-- Data quality investigation and fixes.
-- Tables were cleaned before Primary and Foreign keys are able to be added 



--CUSTOMERS TABLE-----------------------------------------

-- Table contains both customer_id and customer_unique_id. Need to figure out which one joins to orders.
SELECT 
	COUNT(*) FILTER (WHERE o.customer_id = c.customer_id) AS customer_id_match,
	COUNT(*) FILTER (WHERE o.customer_id = c.customer_unique_id) AS customer_unique_id_match
FROM orders o
FULL JOIN customers c ON o.customer_id = c.customer_id;

-- customer_id matches 99,441 times. customer_unique_id matches 0. customer_id will be used to join the orders table.



--PRODUCTS TABLE------------------------------------------

-- 610 products have an empty string '' for product_category_name. Empty strings are not the same as NULL and would fail as a foreign key later.
SELECT
    product_category_name,
    COUNT(*) AS product_count
FROM products
WHERE product_category_name IS NULL
   OR product_category_name = ''
GROUP BY product_category_name;

-- Converting empty strings to NULL
UPDATE products
SET product_category_name = NULL
WHERE product_category_name = '';

-- Checking for categories in products with no matching rows in the category_translation table.
SELECT DISTINCT p.product_category_name, COUNT(*)
FROM products p
LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
WHERE ct.product_category_name IS NULL
AND p.product_category_name IS NOT NULL
GROUP BY 1;



-- CATEGORY TRANSLATION TABLE------------------------------

-- Two categories are missing from category_translation. Google translated and the new values were inserted.
INSERT INTO category_translation (product_category_name, product_category_name_english)
VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_and_food_preparers');



--REVIEWS TABLE-------------------------------------------

-- To find a suitable primary key, unique review_ids are compared to the total rows. 
-- There are 99,224 total rows but only 98,410 unique review_ids.
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT review_id) AS unique_review_ids
FROM reviews;

-- order_id is also not unique with only 98,673 unique order_ids.
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id) AS unique_order_ids
FROM reviews;

-- Looking at duplicate review_ids, the same review_id and message appear on different order_ids.
SELECT r.*,
       RANK() OVER (PARTITION BY r.review_id ORDER BY r.order_id) AS rnk
FROM reviews r
INNER JOIN (
    SELECT review_id
    FROM reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS dupes ON r.review_id = dupes.review_id
WHERE r.review_comment_message IS NOT NULL
ORDER BY r.review_id
LIMIT 300;

-- Looking at duplicate order_ids, the same order can have multiple different reviews.
SELECT r.*,
       RANK() OVER (PARTITION BY r.order_id ORDER BY r.review_id) AS rnk
FROM reviews r
INNER JOIN (
    SELECT order_id
    FROM reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) AS dupes ON r.order_id = dupes.order_id
ORDER BY r.order_id
LIMIT 300;

-- Could multiple reviews be explained by multiple products per order?
-- This is not the case as the vast majority of orders with multiple reviews only have 1 product.
SELECT
    o.order_id,
    COUNT(DISTINCT r.review_id) AS review_count,
    COUNT(DISTINCT i.product_id) AS product_count
FROM orders o
INNER JOIN reviews r ON o.order_id = r.order_id
INNER JOIN order_items i ON o.order_id = i.order_id
GROUP BY o.order_id
HAVING COUNT(DISTINCT r.review_id) > 1
ORDER BY review_count DESC
LIMIT 300;

-- How much time is there between the duplicate reviews? 
-- Most duplicate reviews are 0-3 seconds apart from each other. 
SELECT 
    r.review_id,
    r.order_id,
    o.order_purchase_timestamp,
    ROW_NUMBER() OVER (PARTITION BY r.review_id ORDER BY o.order_purchase_timestamp),
    LEAD(o.order_purchase_timestamp) 
    	OVER (PARTITION BY r.review_id ORDER BY o.order_purchase_timestamp)
    	- o.order_purchase_timestamp AS time_to_next_order,
    r.review_comment_message,
    o.order_delivered_customer_date
FROM reviews r
INNER JOIN orders o ON r.order_id = o.order_id
INNER JOIN (
    SELECT review_id
    FROM reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS dupes ON r.review_id = dupes.review_id
ORDER BY r.review_id, o.order_purchase_timestamp
LIMIT 200;

-- Reviews table conclusion:
-- Some order_ids have multiple reviews with different scores and comments, not explained by multiple products. 
-- Some review_ids appear on multiple different order_ids with identical comments, indicating a bug in Olist's review assignment system. 
-- Duplicate order_ids will be handled in the deduped view below.
-- review_id will not change as we will not join on it.



-- CLEANING THE REVIEWS TABLE-------------------------------------------

-- The reviews_deduped is created keeping one row per order_id with the lowest review score.
CREATE VIEW reviews_deduped AS
SELECT DISTINCT ON (order_id)
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM reviews
ORDER BY order_id, review_score ASC;

-- Row count and unique order_ids of the new view are both 98,673.
SELECT COUNT(*) AS total,
       COUNT(DISTINCT order_id) AS unique_orders
FROM reviews_deduped;

-- There are no missing values for review_score in the reviews_deduped table.
SELECT
    'reviews_deduped' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END) AS null_review_score
FROM reviews_deduped;



--PRIMARY KEYS--------------------------------------------
--With the steps completed above, Primary and Foreign Keys can be added.
ALTER TABLE public.sellers ADD CONSTRAINT sellers_pk PRIMARY KEY (seller_id);
ALTER TABLE public.orders ADD CONSTRAINT orders_pk PRIMARY KEY (order_id);
ALTER TABLE public.customers ADD CONSTRAINT customers_pk PRIMARY KEY (customer_id);
ALTER TABLE public.products ADD CONSTRAINT product_pk PRIMARY KEY (product_id);
ALTER TABLE public.category_translation ADD CONSTRAINT category_translation_pk PRIMARY KEY (product_category_name);

-- order_items has no single unique column, so a composite key is created using two columns.
ALTER TABLE public.order_items ADD CONSTRAINT order_items_pk PRIMARY KEY (order_id, order_item_id);



--FOREIGN KEYS--------------------------------------------

-- order_items connects to orders, products, and sellers
ALTER TABLE order_items ADD CONSTRAINT fk_order_items_orders
    FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE order_items ADD CONSTRAINT fk_order_items_products
    FOREIGN KEY (product_id) REFERENCES products(product_id);

ALTER TABLE order_items ADD CONSTRAINT fk_order_items_sellers
    FOREIGN KEY (seller_id) REFERENCES sellers(seller_id);

-- orders connects to customers
ALTER TABLE orders ADD CONSTRAINT fk_orders_customers
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

-- reviews connects to orders
ALTER TABLE reviews ADD CONSTRAINT fk_reviews_orders
    FOREIGN KEY (order_id) REFERENCES orders(order_id);

-- payments connects to orders
ALTER TABLE payments ADD CONSTRAINT fk_payments_orders
    FOREIGN KEY (order_id) REFERENCES orders(order_id);

-- products connects to category_translation
ALTER TABLE products ADD CONSTRAINT fk_products_category
    FOREIGN KEY (product_category_name) REFERENCES category_translation(product_category_name);



--DATA CLEANING CONTINUED--------------------------------------------



--ORDERS TABLE--------------------------------------------

-- Checking for Null values across key columns.
-- There are 2,965 missing delivery dates. Orders that were cancelled, in progress, or never delivered would not have a delivery date.
SELECT
    'orders' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_date,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_delivery_date,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS null_estimated_date
FROM orders;

-- Distribution of orders by status
-- Filtering the dataset to only delivered orders will maintain 97.02% of the data with 96,478 orders.
-- This will be accomplished in an orders_clean table.
SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;



--CLEANING THE ORDERS TABLE---------------------------------------------------

-- The orders_clean view adds to new fields: delivery_days and delivery_delay_days
-- These allow us to see how long the packages take to arrive from the moment the customer made the purchase, and
-- how well the estimate delivery date presented to the customer was accurate.
CREATE VIEW orders_clean AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATE_PART('day', o.order_delivered_customer_date - o.order_purchase_timestamp) AS delivery_days,
    DATE_PART('day', o.order_delivered_customer_date - o.order_estimated_delivery_date) AS delivery_delay_days
FROM orders o
WHERE o.order_status = 'delivered'
AND   o.order_delivered_customer_date IS NOT NULL;

-- The new orders_clean table contains 96,470 orders. The 8 order difference is from orders labeled as delivered, but have no delivery date. 
--Removing these 8 orders would not have a significant difference in the results. 
SELECT *
FROM orders
WHERE order_status = 'delivered'
AND order_delivered_customer_date IS NULL;



--ORDER_ITEMS TABLE---------------------------------------
--There are no missing values for price or freight.
SELECT
    'order_items' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END) AS null_freight
FROM order_items;
