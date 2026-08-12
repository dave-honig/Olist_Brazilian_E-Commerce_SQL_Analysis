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


-- The 'delivery_days' column uses the double precision data type with values that could run over ten decimal places. This is unnecessary and it wouldn't be accurate as the delivery time is only recorded down to the second. 
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


-- Removing the old orders_clean view
DROP VIEW orders_clean;


-- Recreating orders_clean view to exclude the 13 zero-day deliveries.
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
- With deliveries taking over 30 days, 75% of customers leave a bad review from their experience.
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
Higher freight costs go with worse reviews, but delivery time is the more likely explanation.
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

-- Does freight still matter once delivery time is held constant?
-- Each delivery bucket is split at the median freight cost of 17.17 Brazilian Real.
-- Bad review rates climb steeply with delivery time in both halves, 12.7% to 80.5% and 17.0% to 73.9%.
-- Inside any single bucket the freight gap is small and switches direction, so freight is the weaker signal.
WITH order_freight AS (
    SELECT order_id, 
    SUM(freight_value) AS total_freight
    FROM order_items
    GROUP BY order_id
),
freight_median AS (
    SELECT PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY f.total_freight) AS med
    FROM order_freight f
    INNER JOIN orders_clean o ON f.order_id = o.order_id
    INNER JOIN reviews_deduped r ON o.order_id = r.order_id
)
SELECT
    CASE
        WHEN o.delivery_days <= 7 THEN '1. 0-7 days'
        WHEN o.delivery_days <= 14 THEN '2. 8-14 days'
        WHEN o.delivery_days <= 21 THEN '3. 15-21 days'
        WHEN o.delivery_days <= 30 THEN '4. 22-30 days'
        ELSE '5. 31+ days'
    END AS delivery_bucket,
    COUNT(*) FILTER (WHERE f.total_freight <= m.med) AS low_freight_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 3 AND f.total_freight <= m.med)
        / COUNT(*) FILTER (WHERE f.total_freight <= m.med), 1) AS low_freight_bad_pct,
    COUNT(*) FILTER (WHERE f.total_freight > m.med) AS high_freight_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 3 AND f.total_freight > m.med)
        / COUNT(*) FILTER (WHERE f.total_freight > m.med), 1) AS high_freight_bad_pct
FROM orders_clean o
INNER JOIN reviews_deduped r ON o.order_id = r.order_id
INNER JOIN order_freight f ON o.order_id = f.order_id
CROSS JOIN freight_median m
GROUP BY delivery_bucket
ORDER BY delivery_bucket;

-- Do expensive shipping outliers explain the difference between the average and median?
-- The 75th percentile is R$32.11 at 1 star against R$23.13 at 5 stars.
-- The 99th percentile is R$144.31 against R$96.41, so more 1 star orders had expensive shipping, not just a few extreme ones.
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
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY f.total_freight)::NUMERIC, 2) AS p25_freight,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY f.total_freight)::NUMERIC, 2) AS median_freight,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY f.total_freight)::NUMERIC, 2) AS p75_freight,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY f.total_freight)::NUMERIC, 2) AS p99_freight
FROM orders_clean o
INNER JOIN reviews_deduped r ON o.order_id = r.order_id
INNER JOIN order_freight f ON o.order_id = f.order_id
GROUP BY r.review_score
ORDER BY r.review_score;

--DELIVERY DELAY VS REVIEW SCORE--------------------------

/*
- Negative values mean the order arrived before the estimate. A value of zero means arriving exactly on the estimated date.
- At the median, 1-star orders arrive 6 days early and 5-star orders arrive 12 days early relative to the delivery date estimate at checkout.
- Compared to the median, the 1-star average is closer to zero at -3.4 days while the 5-star median and mean are about the same.
- Genuinely late deliveries are likely pulling the 1-star average closer to zero.
- Higher satisfaction is associated with beating the estimate by a wider margin, not just arriving on time.
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
-- Seller counts fall steeply below 15 then flatten, losing 288 sellers from 10 to 15 but only 165 from 15 to 20.
-- A minimum of 20 orders sits past the steep part, keeping 818 of the 3,095 sellers in this table.  
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
Sellers with the highest percentage of bad reviews, filtered to sellers with at least 20 orders.
- 800 sellers have at least 20 delivered and reviewed orders.
- The worst seller has a 70.1% bad review rate across 107 orders.
- Every seller in the top 15 by bad review rate has at least double the platform average of 21.1%.
- Note: individual seller outliers are context for the segmentation analysis below, which shows
  that high-risk sellers as a group account for only 14% of all bad reviews on the platform.
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
ORDER BY bad_review_pct DESC, seller_id
LIMIT 30;

-- All qualifying sellers with rate and volume, for the seller risk scatter plot.
-- Same population as the top 30 query above, without the limit.
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
ORDER BY bad_review_pct DESC, seller_id;


--MULTI-SELLER ORDERS------------------------------------

-- Do orders split across sellers fail more often, independent of delivery time?
-- Multi-seller orders are faster than single-seller orders, with a median of 7 days against 10.
-- The gap holds at 44 to 47 points in the three buckets with usable sample sizes.
-- The 22-30 and 31+ buckets have only 38 and 4 multi-seller orders and should not be read.
WITH seller_count AS (
    SELECT
        i.order_id,
        COUNT(DISTINCT i.seller_id) AS sellers
    FROM order_items i
    INNER JOIN orders_clean o ON i.order_id = o.order_id
    GROUP BY i.order_id
)
SELECT
    CASE
        WHEN o.delivery_days <= 7 THEN '1. 0-7 days'
        WHEN o.delivery_days <= 14 THEN '2. 8-14 days'
        WHEN o.delivery_days <= 21 THEN '3. 15-21 days'
        WHEN o.delivery_days <= 30 THEN '4. 22-30 days'
        ELSE '5. 31+ days'
    END AS delivery_bucket,
    CASE WHEN sc.sellers = 1 THEN '1 seller' ELSE '2+ sellers' END AS seller_group,
    COUNT(*) AS order_count,
    SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END) AS bad_reviews,
    ROUND(
        100.0 * SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END) / COUNT(*),
    1) AS bad_review_pct
FROM orders_clean o
INNER JOIN reviews_deduped r ON o.order_id = r.order_id
INNER JOIN seller_count sc ON o.order_id = sc.order_id
GROUP BY delivery_bucket, seller_group
ORDER BY delivery_bucket, seller_group;

--SELLER RISK DISTRIBUTION-------------------------------

/*
Are bad reviews concentrated in high-risk sellers or spread across the platform?
- Sellers are segmented into three groups against a dynamically calculated platform average.
- The 35% high risk boundary is set manually as a judgement call.
- High risk sellers (35%+) account for only 13.9% of all bad reviews despite having the worst rates.
- The remaining 86.1% come from sellers with bad review rates below 35%, including a large band well above the 21.1% average.
- No minimum order count is applied here, unlike the top 30 query above.
- The question is how bad reviews are spread across all sellers, so every seller is included.
- This indicates bad reviews are a platform-wide logistics problem, not a bad seller problem.
  Removing every high-risk seller would leave the vast majority of the problem untouched.
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
            / COUNT(s.order_id), 1) AS bad_review_pct
    FROM seller_orders s
    INNER JOIN reviews_deduped r ON s.order_id = r.order_id
    GROUP BY s.seller_id
),
platform_avg AS (
    SELECT ROUND(100.0 * SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END) / COUNT(*), 1) AS avg_bad_review_pct
    FROM orders_clean o
    INNER JOIN reviews_deduped r ON o.order_id = r.order_id
)
SELECT
    CASE
        WHEN sr.bad_review_pct < pa.avg_bad_review_pct THEN '1. Below Platform Average'
        WHEN sr.bad_review_pct BETWEEN pa.avg_bad_review_pct AND 35
            THEN '2. Moderate Risk (' || pa.avg_bad_review_pct::TEXT || '% - 35%)'
        ELSE '3. High Risk (35%+)'
    END AS seller_segment,
    COUNT(*) AS seller_count,
    SUM(sr.order_count) AS total_orders,
    SUM(sr.bad_reviews) AS total_bad_reviews,
    ROUND(100.0 * SUM(sr.bad_reviews) / SUM(SUM(sr.bad_reviews)) OVER (), 1) AS pct_of_all_bad_reviews
FROM seller_reviews sr
CROSS JOIN platform_avg pa
GROUP BY seller_segment
ORDER BY seller_segment;



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
- DISTINCT prevents multi-item orders from inflating bad review counts within a category.
- An order spanning two categories is counted once in each, so category totals do not sum to the platform total.
- Each category rate is still valid because the order appears once in both the numerator and the denominator.
- Row 1, portable_kitchen_and_food_preparers, has a 46.2% bad review rate but only 13 orders.
- Row 2, office_furniture, with 1,244 orders has 36.6% bad reviews, over 1.7 times the platform average.
- That is a high rate on moderate volume, producing 455 bad reviews in total. 
- Row 11, bed_bath_table, with 9,175 orders has 26.1% bad reviews, only modestly above the platform average.
- Its volume makes it the largest single source of bad reviews at 2,398, ahead of health_beauty at 1,650.
- The home and furniture categories dominate the top of the list, with home_comfort, home_comfort_2, furniture_mattress_and_upholstery, and furniture_decor all in the top 15.
- furniture_living_room follows just outside at row 16.
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
ORDER BY bad_review_pct DESC, category_english;

-- Headline figures for the dashboard KPI cards.
SELECT
    (SELECT COUNT(*) FROM orders_clean) AS orders_analyzed,
    COUNT(*) AS reviewed_orders,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY o.delivery_days) AS median_delivery_days,
    ROUND(
        100.0 * SUM(CASE WHEN r.review_score <= 3 THEN 1 ELSE 0 END) / COUNT(*),
    1) AS bad_review_pct
FROM orders_clean o
INNER JOIN reviews_deduped r ON o.order_id = r.order_id;
