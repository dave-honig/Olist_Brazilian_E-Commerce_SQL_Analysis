-- 03_exploration.sql
-- Data exploration and analysis.
-- Run after 02_data_quality.sql.



--REVIEW SCORE DISTRIBUTION-------------------------------

-- Each review includes an integer value on a 5 point scale.
-- 57.72% of reviews are 5 stars. 77.02% are 4 or 5 combined. Distribution is heavily skewed positive.
-- Bad review is defined as scores 1, 2, or 3. A score of 3 is included because the customer is unlikely to return.
SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM reviews_deduped
GROUP BY review_score
ORDER BY review_score;



--DELIVERY DAYS DISTRIBUTION------------------------------

-- An initial attempt to review the distribution ran in to an error.
SELECT
    MIN(delivery_days) AS min_days,
    MAX(delivery_days) AS max_days,
    ROUND(AVG(delivery_days), 1) AS avg_days,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY delivery_days) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY delivery_days) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY delivery_days) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY delivery_days) AS p90
FROM orders_clean;


-- The 'delivery_days' column uses the double precision data type with values that could over ten decimal places. This is unnecessary and it wouldn't be accurate as the delivery time is only recorded down to the second. 
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'orders_clean'
AND column_name = 'delivery_days';


-- Casting delivery_days as numeric in the formula from above.
/* 
- For most of the customers, the typical order takes between 6 and 15 days to deliver, with a median of 10 days. 
- The average of 12.1 days is higher than the median of 10 days, which tells us the distribution is right skewed. A smaller number of very slow deliveries are pulling the average up.
- A minimum of 0 days is suspicious. It likely means the delivery date was recorded on the same day as the purchase, which could be a data entry error or a same day delivery. 
- A maximum of 209 days is a significant outlier. Nearly 7 months for a delivery is certainly an anomaly rather than a genuine delivery time.
- The 90th percentile of 23 days means 90% of orders were delivered within 23 days. The slowest 10% took longer than that, and those are likely candidates for generating bad reviews.
*/
SELECT
    MIN(delivery_days) AS min_days,
    MAX(delivery_days) AS max_days,
    ROUND(AVG(delivery_days)::NUMERIC, 1) AS avg_days,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY delivery_days) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY delivery_days) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY delivery_days) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY delivery_days) AS p90
FROM orders_clean;


-- Orders delivered in 0 days.
-- 13 zero-day deliveries out of 96,470 total orders. These were probably recording errors and will be excluded.
SELECT COUNT(*) AS zero_day_deliveries
FROM orders_clean
WHERE delivery_days = 0;


-- Orders delivered in over 60 days.
-- 288 orders took over 60 days. A customer who waited over 60 days for their order likely left a bad review, so excluding them entirely may understate the relationship between delivery time and satisfaction. However, keeping them could skew our averages. These orders were included.
SELECT COUNT(*) AS very_long_deliveries
FROM orders_clean
WHERE delivery_days > 60;


-- Removing the old orders_clean table
DROP VIEW orders_clean;


-- Recreating orders_clean to exclude the 13 zero-day deliveries.
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
AND o.order_delivered_customer_date IS NOT NULL
AND DATE_PART('day', o.order_delivered_customer_date - o.order_purchase_timestamp) > 0;


-- Confirming 13 rows were removed (96,470 - 96,457 = 13)
SELECT 96470 - COUNT(*)
FROM orders_clean;



--DELIVERY DELAY DISTRIBUTION-----------------------------

/*
Delivery days delay distribution.
- Two extra columns were added at the end to count how many orders arrived late versus on time or early. 
- A positive number means the order arrived after the estimated date, and a negative number means it arrived early. 

- The typical order arrived early. The median is -11 days, meaning half of all orders arrived 11 days ahead of the estimated delivery date. Olist appears to set very conservative delivery estimates.
- Only about 6.8% (6,534 out of 96,457 delivered orders) arrived late. The vast majority, 93.2%, arrived on time or early.
*/
SELECT
    MIN(delivery_delay_days) AS min_delay,
    MAX(delivery_delay_days) AS max_delay,
    ROUND(AVG(delivery_delay_days)::NUMERIC, 1) AS avg_delay,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY delivery_delay_days) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY delivery_delay_days) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY delivery_delay_days) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY delivery_delay_days) AS p90,
    SUM(CASE WHEN delivery_delay_days > 0 THEN 1 ELSE 0 END) AS late_orders,
    SUM(CASE WHEN delivery_delay_days <= 0 THEN 1 ELSE 0 END) AS on_time_or_early_orders
FROM orders_clean;



--DELIVERY TIME VS REVIEW SCORE---------------------------

/*
Comparing Late vs On time or Early orders.
- Late orders averaged a review score of 2.27 vs 4.29 for on-time or early. Nearly a 2 point difference on a 5 point scale.
- Note: Row counts here are lower than orders_clean because not every order has a matching review.
*/
SELECT
    CASE WHEN o.delivery_delay_days > 0 THEN 'Late'
         ELSE 'On Time or Early'
    END AS delivery_status,
    COUNT(*) AS order_count,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score
FROM orders_clean o
INNER JOIN reviews_deduped r ON o.order_id = r.order_id
GROUP BY delivery_status
ORDER BY delivery_status;


/*
How review score is correlated with number of delivery days. 
- Orders with a score of 1 take about twice as long to deliver (20.8 delivery days) compared to orders with the highest score (10.2 delivery days).
- The median is lower than the mean at every score level. Our distribution is right-skewed, with orders taking extra long to arrive pulling the mean upward at each score level. 
- The overall delivery time is a meaningful predictor of satisfaction.
*/
SELECT
    r.review_score,
    COUNT(*) AS order_count,
    ROUND(AVG(o.delivery_days)::NUMERIC, 1) AS avg_delivery_days,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY o.delivery_days) AS median_delivery_days
FROM orders_clean o
INNER JOIN reviews_deduped r ON o.order_id = r.order_id
GROUP BY r.review_score
ORDER BY r.review_score;


/*
When do the bad reviews start spiking for delivery time?
- The risk of bad reviews is relatively low below 21 days, rising gradually from 14.1% to 22.6%.
- The inflection point comes after 21 days. The bad review rate nearly doubles from 22.6% to 40.6% crossing that threshold.
- At 31+ days, 3 out of 4 customers leave a bad review. This essentially a guarantees bad experience.
- The 0-7 day bucket still has a 14.1% bad review rate, which tells us delivery speed is not the only factor. Other factors like product quality, freight cost, or seller behavior are also in play.
*/
SELECT
    CASE
        WHEN o.delivery_days <= 7 THEN '1. 0-7 days'
        WHEN o.delivery_days <= 14 THEN '2. 8-14 days'
        WHEN o.delivery_days <= 21 THEN '3. 15-21 days'
        WHEN o.delivery_days <= 30 THEN '4. 22-30 days'
        ELSE '5. 31+ days'
    END AS delivery_bucket,
    COUNT(*) AS order_count,
    SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END) AS bad_reviews,
    ROUND(
        100.0 * SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END) / COUNT(*),
        1
    ) AS bad_review_pct
FROM orders_clean o
INNER JOIN reviews_deduped r ON o.order_id = r.order_id
GROUP BY delivery_bucket
ORDER BY delivery_bucket;



--FREIGHT COST VS REVIEW SCORE----------------------------

/*
Higher freight costs are associated with worse reviews, but delivery time is likely the real reason.
- The median range is about 2 Brazilian Real across all five scores. This very small spread suggests freight cost alone is not a strong driver of satisfaction.
- There is a growing gap between average and median as scores worsen. Score 1 has a 9.36 Real gap versus 4.92 for score 5. Expensive freight outliers are disproportionately concentrated in bad reviews, but they are outliers, not the norm.
*/
WITH order_freight AS (
    SELECT
        order_id,
        SUM(freight_value) AS total_freight
    FROM order_items
    GROUP BY order_id
)
SELECT
    r.review_score,
    COUNT(*) AS order_count,
    ROUND(AVG(f.total_freight)::NUMERIC, 2) AS avg_freight,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY f.total_freight) AS median_freight
FROM orders_clean o
INNER JOIN reviews_deduped r ON o.order_id = r.order_id
INNER JOIN order_freight f ON o.order_id = f.order_id
GROUP BY r.review_score
ORDER BY r.review_score;


--DELIVERY DELAY VS REVIEW SCORE--------------------------

/*
- The worst-reviewed orders typically arrive 6 days before the estimate. Lateness relative to the estimate is not what is driving bad reviews.
- Orders with a score of 1 arrive, on average, 6 days early while an order with a score of 5 orders arrives 12 days early. Higher satisfaction is associated with beating the estimate by a wider margin, not just arriving on time.
- Raw delivery time is a dominant driver of satisfaction, not relative lateness. A customer receiving an order after 20 days is unhappy regardless of what the estimate said.
*/
WITH order_delay AS (
    SELECT
        order_id,
        delivery_delay_days
    FROM orders_clean
)
SELECT
    r.review_score,
    COUNT(*) AS order_count,
    ROUND(AVG(d.delivery_delay_days)::NUMERIC, 1) AS avg_delay_days,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY d.delivery_delay_days) AS median_delay_days
FROM reviews_deduped r
INNER JOIN order_delay d ON r.order_id = d.order_id
GROUP BY r.review_score
ORDER BY r.review_score;



--SELLER RISK---------------------------------------------


-- Seller volume for different percentiles.
-- Seller distribution is extremely skewed. Half of all sellers have 6 or fewer orders. The bottom 10% have just 1 order. 
WITH seller_order_counts AS (
    SELECT
        seller_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM order_items
    GROUP BY seller_id
)
SELECT
    PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY order_count) AS p1,
    PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY order_count) AS p5,
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY order_count) AS p10,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY order_count) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY order_count) AS p50,
    MIN(order_count) AS min_orders,
    MAX(order_count) AS max_orders
FROM seller_order_counts;


-- How many orders are the sellers making?
-- The steepest single drop is between 10 and 15, losing 288 sellers. From 15 to 20 we only lose another 165.
-- Data on high risk sellers will be limited to those with at least 20 orders.  
WITH seller_order_counts AS (
    SELECT
        seller_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM order_items
    GROUP BY seller_id
)
SELECT
    SUM(CASE WHEN order_count >= 10 THEN 1 ELSE 0 END) AS sellers_10_plus,
    SUM(CASE WHEN order_count >= 15 THEN 1 ELSE 0 END) AS sellers_15_plus,
    SUM(CASE WHEN order_count >= 20 THEN 1 ELSE 0 END) AS sellers_20_plus,
    SUM(CASE WHEN order_count >= 30 THEN 1 ELSE 0 END) AS sellers_30_plus,
    SUM(CASE WHEN order_count >= 40 THEN 1 ELSE 0 END) AS sellers_40_plus,
    SUM(CASE WHEN order_count >= 50 THEN 1 ELSE 0 END) AS sellers_50_plus,
    SUM(CASE WHEN order_count >= 75 THEN 1 ELSE 0 END) AS sellers_75_plus,
    SUM(CASE WHEN order_count >= 100 THEN 1 ELSE 0 END) AS sellers_100_plus,
    COUNT(*) AS total_sellers
FROM seller_order_counts;


/*
Sellers with the highest percentage of bad reviews.
- The worst seller has a 70.1% bad review rate across 107 orders.
- Seller_id starting with 7c67e (row 26) has 967 orders with a 40.4% bad review rate generating roughly 391 bad reviews on its own.

Two different types of risk:
- High rate, moderate volume (rows 1 through 5)
-Moderate rate, high volume (rows 25 and 26)
*/
WITH seller_orders AS (
    SELECT DISTINCT
        i.seller_id,
        i.order_id
    FROM order_items i
    INNER JOIN orders_clean o ON i.order_id = o.order_id
),
seller_reviews AS (
    SELECT
        s.seller_id,
        COUNT(s.order_id) AS order_count,
        SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END) AS bad_reviews,
        ROUND(
            100.0 * SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END)
            / COUNT(s.order_id),
        1) AS bad_review_pct,
        ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score
    FROM seller_orders s
    INNER JOIN reviews_deduped r ON s.order_id = r.order_id
    GROUP BY s.seller_id
    HAVING COUNT(s.order_id) >= 20
)
SELECT
    seller_id,
    order_count,
    bad_reviews,
    bad_review_pct,
    avg_review_score
FROM seller_reviews
ORDER BY bad_review_pct DESC
LIMIT 30;



--CATEGORY RISK-------------------------------------------

-- Distribution of orders across categories.
-- About 90% of the categories have at least 24 orders.
WITH category_order_counts AS (
    SELECT
        ct.product_category_name_english AS category_english,
        COUNT(DISTINCT i.order_id) AS order_count
    FROM order_items i
    INNER JOIN products p ON i.product_id = p.product_id
    INNER JOIN category_translation ct ON p.product_category_name = ct.product_category_name
    INNER JOIN orders_clean o ON i.order_id = o.order_id
    GROUP BY ct.product_category_name_english
)
SELECT
    MIN(order_count) AS min_orders,
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY order_count) AS p10,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY order_count) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY order_count) AS p50,
    MAX(order_count) AS max_orders,
    COUNT(*) AS total_categories
FROM category_order_counts;


/*
Categories with a high percentage of bad reviews with a minimum 10 orders.
- DISTINCT prevents multi-item orders from inflating bad review counts
- Row 1, portable_kitchen_and_food_preparers, has a 46.2% bad review rate but only 13 orders.
- Row 2, office_furniture, with 1,244 orders has 36.6% bad reviews. It has both high volume and a rate nearly double the platform average. 
- Row 11, bed_bath_table, with 9,175 orders has 26.1% bad reviews. Similar to row 2, this category is generating more bad reviews in total than almost anything else.
- The home and furniture categories dominate the top of the list, with home_confort, home_comfort_2, furniture_mattress_and_upholstery, furniture_decor, and furniture_living_room all appearing in the top 15. 
*/
WITH category_orders AS (
    SELECT DISTINCT
        i.order_id,
        ct.product_category_name_english AS category_english
    FROM order_items i
    INNER JOIN products p ON i.product_id = p.product_id
    INNER JOIN category_translation ct ON p.product_category_name = ct.product_category_name
    INNER JOIN orders_clean o ON i.order_id = o.order_id
),
category_reviews AS (
    SELECT
        c.category_english,
        COUNT(c.order_id) AS order_count,
        SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END) AS bad_reviews,
        ROUND(
            100.0 * SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END)
            / COUNT(c.order_id),
        1) AS bad_review_pct,
        ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score
    FROM category_orders c
    INNER JOIN reviews_deduped r ON c.order_id = r.order_id
    GROUP BY c.category_english
    HAVING COUNT(c.order_id) >= 10
)
SELECT
    category_english,
    order_count,
    bad_reviews,
    bad_review_pct,
    avg_review_score
FROM category_reviews
ORDER BY bad_review_pct DESC;
