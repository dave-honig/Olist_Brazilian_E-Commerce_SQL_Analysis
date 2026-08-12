# Olist Brazilian E-Commerce: Customer Satisfaction Analysis

## Problem Statement

What operational factors, such as delivery time, freight cost, and seller behavior, most strongly predict a negative customer experience, and which product categories and sellers represent the highest risk to customer satisfaction?

> A "bad review" is defined as a review score of 1, 2, or 3. These customers are less likely to return making them a churn risk.

---

<p align="center">
  <a href="https://public.tableau.com/views/OlistProjectinTableau/OlistProject_v3?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link">
    <img src="images/olist_tableau_dashboard.png" width="80%" alt="Tableau dashboard showing metrics which drive bad reviews">
  </a>
  <br>
  <a href="https://public.tableau.com/views/OlistProjectinTableau/OlistProject_v3?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link">View the Tableau dashboard</a>
</p>

---

## Key Findings

- **Delivery time is the dominant driver of bad reviews.** The bad review rate climbs from 14.1% for orders delivered within a week to 75.7% for orders taking 31 days or more. The break comes after 21 days, where the rate nearly doubles from 22.6% to 40.6%. Orders rated 1 star took 20.8 days to arrive on average against 10.2 days for 5-star orders, and every step up in review score corresponded to a shorter delivery time without exception.

<p align="center">
<img src="images/orders_taking_over_31_days_graph.png" width="60%" alt="Line chart showing bad review rate rising from 14.1% to 75.7% across delivery day buckets">
</p>

- **The problem is the wait itself, not missed promises.** Olist pads its delivery estimates heavily — 93.2% of orders arrive on or before the estimated date, and even 1-star orders arrive 3.4 days early on average. Customers are not reacting to broken promises. They are reacting to how long they waited.

<p align="center">
<img src="images/padded_delivery_estimates_graph.png" width="60%" alt="Bar chart showing average days each review score arrived before the estimated delivery date">
</p>

- **Shipping cost looks like a factor, but the typical order shows almost no difference.** A 1-star order typically paid R$18.79 to ship against R$16.79 for a 5-star order, a spread of R$2. Averages diverge much further, R$28.15 against R$21.71, because bad-review orders contain more unusually expensive shipments.

<p align="center">
<img src="images/1_star_orders_typically_pay_graph.png" width="60%" alt="Dumbbell chart comparing median and average shipping cost for each review score">
</p>

- **Controlling for delivery time removes the effect.** Splitting each delivery bucket into cheaper and costlier halves, the bad review rate climbs from 12.7% to 80.5% among cheap-shipping orders and from 17.0% to 73.9% among expensive ones. Within any single bucket the shipping gap is small and reverses direction between fast and slow orders. Delivery time points the same way in every group; shipping cost does not.

<p align="center">
<img src="images/delivery_time_drives_bad_reviews_graph.png" width="60%" alt="Two-line chart showing bad review rate by delivery bucket for orders above and below the median shipping cost">
</p>

- **Orders split across multiple sellers fail at over three times the rate, whatever the delivery speed.** Among orders delivered within a week, 58.5% of split orders received a bad review against 13.2% of single-seller orders. The gap holds at 60.8% against 16.7% for 8-14 days, and 68.9% against 22.3% for 15-21 days. Split orders are only 1.3% of volume, but they are the only factor besides delivery time that survived the same control test. One caveat: Olist records a single delivery date per order, so it cannot be ruled out that some customers reviewed while part of a split order was still in transit.

<p align="center">
<img src="images/orders_from_multiple_sellers_graph.png" width="60%" alt="Two-line chart comparing bad review rates for single-seller and multi-seller orders across delivery buckets">
</p>

- **Bad reviews are a platform-wide logistics problem, not a bad seller problem.** Sellers with a bad review rate above 35% account for only 13.9% of all bad reviews. The remaining 86.1% come from sellers below that threshold, including a large band sitting well above the 21.1% platform average. Removing every high-risk seller would leave the vast majority of the problem untouched.

<p align="center">
<img src="images/only_14_percent_of_bad_reviews_graph.png" width="60%" alt="Stacked bar showing the share of all bad reviews contributed by each seller risk segment">
</p>

- **Home and furniture categories carry the highest risk.** `office_furniture` has a 36.6% bad review rate across 1,244 orders, over 1.7 times the platform average. `bed_bath_table` is the single largest source of bad reviews in absolute terms — 2,398 across 9,175 orders — despite a more moderate 26.1% rate. Six of the top 15 categories by rate are home or furniture goods, pointing to something systematic about bulky, hard-to-ship products.

<p align="center">
<img src="images/of_the_1244_office_furniture_orders_graph.png" width="60%" alt="Bar chart ranking the top 15 product categories by bad review rate">
</p>


---
## OLD version

- **Delivery time is the dominant driver of bad reviews.** Orders with a score of 1 averaged 20.8 days to deliver versus 10.2 days for orders with a score of 5. Every step up in review score corresponded to a shorter delivery time without exception.

<p align="center">
<img src="images/1_star_orders_take_21_days_to_deliver_graph.png" width="60%" margin-left= "10%" alt="Horizontal bar chart showing Star Rating vs Delivery Time">
</p>

- **Deliveries over 21 days significantly increase risk.** Bad review rates rise gradually from 14.1% to 22.6% below that point, then nearly double crossing it, reaching 40.6% for orders taking 22 to 30 days and 75.7% for orders taking 31 or more days.

<p align="center">
<img src="images/delivery_buckets_graph.png" width="60%" margin-left= "10%" alt="Horizontal bar chart showing Bad Review Rate by Delivery Day Bucket">
</p>

- **Freight cost does not hold up as a driver of bad reviews once delivery time is accounted for.** The median freight spread across all five review scores is only about 2 Brazilian Real. Splitting each delivery bucket into cheap and expensive halves tests it directly: within a bucket the freight gap is small and reverses direction between fast and slow orders, while delivery time drives the bad review rate from 12.7% to 80.5% among cheap-freight orders and from 17.0% to 73.9% among expensive ones. Delivery time points the same way in every group; freight does not.

<p align="center">
<img src="images/median_freight_varies_by_2_real_graph.png" width="60%" alt="Horizontal bar chart showing Freight Costs vs Review Score">
</p>

- **Arriving late relative to the estimate is not the core problem.** Olist pads delivery estimates enough that even the worst-reviewed orders arrive on average 3.4 days <u>before</u> the estimated date. Raw delivery time, not relative lateness, drives dissatisfaction. A customer waiting 20 days for their order is unhappy regardless of what the estimate said.

<p align="center">
<img src="images/1_star_orders_arrived_3.4_days_before_graph.png" width="60%" alt="Horizontal Bar chart showing 1-Star Orders arrive 3.4 days before the estimate delivery date on average">
</p>

- **Bad reviews are a platform-wide logistics problem, not a bad seller problem.** Sellers with a bad review rate above 35% account for only 14% of all bad reviews on the platform. The remaining 86% come from sellers with bad review rates below 35%, including a large band well above the 21.1% platform average. Removing every high-risk seller would leave the vast majority of the problem untouched.

<p align="center">
<img src="images/only_14_percent_of_bad_reviews_come_from_graph.png" width="60%" alt="Horizontal bar chart showing only 14% of bad reviews come from High Risk Sellers">
</p>

- **Home and furniture categories have the worst bad review rates on the platform.** `office_furniture` has a 36.6% bad review rate across 1,244 orders, nearly double the platform average. `bed_bath_table` is the single largest contributor with 2,398 bad reviews across 9,175 orders. Home comfort, furniture, and mattress categories dominate the top 15 by bad review rate, suggesting something wrong with bulky, hard-to-ship products.

<p align="center">
<img src="images/of_the_1244_office_furniture_orders_graph.png" width="60%" alt="Horizontal bar chart showing Product Categories Ranked by Bad Review Rate">
</p>

---

## Dataset

The Brazilian E-Commerce Public Dataset by Olist is available on [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). It contains approximately 100,000 orders from 2016 to 2018 across 9 tables.

| Table | Rows |
|---|---|
| customers | 99,441 |
| orders | 99,441 |
| order_items | 112,650 |
| reviews | 99,224 |
| products | 32,951 |
| sellers | 3,095 |
| payments | 103,886 |
| geolocation | 1,000,163 |
| category_translation | 71 |

**Tools:** PostgreSQL, DBeaver

<p align="center">
<img src="images/entity_relationship_diagram.png" width="65%" alt="Entity Relationship Diagram">
</p>

---

## Methodology

### Data Quality Findings

**Reviews table:** `review_id` is not a reliable unique identifier. The same `review_id` appears across multiple `order_id` values with identical comment text, indicating a bug in Olist's review assignment system. Some orders also have multiple reviews with different scores. A `reviews_deduped` view was created using `DISTINCT ON (order_id)` ordered by `review_score ASC, review_id`, keeping the most conservative score per order. The `review_id` was added as a tiebreaker due to the fact that 346 orders have two reviews tied on the lowest score. Without it, a third party running the SQL would not have an identical view. Keeping the lowest score rather than the highest or the average moves the platform bad review rate by only 0.11 points, from 21.11% to 21.00%, so the choice does not drive any finding. The view contains 98,673 rows with every `order_id` appearing exactly once.

**Orders table:** 8 orders marked as delivered had no `order_delivered_customer_date` and were excluded. 13 orders had a calculated delivery time of 0 days, likely recording errors, and were also excluded. The final `orders_clean` view contains 96,457 rows.

**Products table:** 610 products had empty string values ("") for `product_category_name`, which were converted to NULL before adding the foreign key constraint. Two categories, `pc_gamer` and `portateis_cozinha_e_preparadores_de_alimentos`, existed in the products table but were missing from `category_translation`. Both were inserted manually with English translations. 

**Category translation table:** Nine English category labels were incorrect or unclear. Seven were corrected: five misspellings (`fashio_female_clothing`, `home_confort`, `costruction_tools_garden`, `costruction_tools_tools`, `arts_and_craftmanship`) and two mistranslations — `seguros_e_servicos` rendered as `security_and_services` when seguros means insurance, and `cds_dvds_musicais` rendered as `cds_dvds_musicals`, the stage genre. 
Two translations were renamed for readability: `cine_photo` to `photography_and_video_equipment`, and `fixed_telephony` to `landline_telephony`. Only the English column was changed as the Portuguese column is the primary key and carries the foreign key from products. 

### Key Metric Definitions

- **`delivery_days`:** Total days from purchase timestamp to actual delivery. Median: 10 days. Average: 12 days. 90th percentile: 23 days.
- **`delivery_delay_days`:** Days between actual delivery and estimated delivery. Positive means late, negative means early. Median: -11 days. Only 6.8% of orders arrived late, so Olist's estimates are consistently conservative.

---

## Repository Structure

```
sql/
    01_setup.sql                  -- Load reviews CSV, verify row counts, rename tables
    02_data_quality.sql           -- Data quality investigation, fixes, views, and constraints
    03_exploration.sql            -- Distribution checks and all analytical queries
images/                           -- Screenshots of query results
csv_exports/					  -- Exported csv files from DBeaver 
Olist Project in Tableau.twbx     -- Packaged Tableau workbook
README.md
```
The Olist dataset CSVs are sourced from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). 

## How to Run

1. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and load each CSV into a PostgreSQL database using DBeaver or psql.
2. Update the file path in the `COPY` command in `01_setup.sql` to match your local environment.
3. Run the scripts in order: `01_setup.sql` → `02_data_quality.sql` → `03_exploration.sql`.
4. Note: the data fixes and foreign key constraints in `02_data_quality.sql` must complete before `03_exploration.sql` runs, or the views and analysis queries that depend on clean data will not produce correct results.
