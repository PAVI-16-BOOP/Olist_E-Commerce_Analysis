CREATE VIEW cohort_analysis AS 

-- Cohort Retention Analysis 

/*SELECT MAX(order_purchase_timestamp :: DATE),MIN(order_purchase_timestamp :: DATE)
FROM olist_orders_dataset             */                                  -- MIN : 2016-09-04  ;  MAX : 2018-10-17

-- So we have orders from SEp. 2016 to Oct. 2018

/*SELECT
    DATE_TRUNC('month', order_purchase_timestamp::timestamp) AS month,
    COUNT(*) AS orders
FROM olist_orders_dataset
GROUP BY month
ORDER BY month;*/    -- we found out that the 09/2016 , 12/2016 have very few customers = so im dropping these months 
-- also ,similarly the last 2 months  have no data afterwards as well none of the orders there have been delivered and
-- over that we have very few orders in those 2 months (20 orders),  so they can never show retention = so im dropping these months as well 

-- Assigning cohorts ( by month of first purchase)

-- Dropping the afore-mentioned months
WITH orders_dataframe AS (
    SELECT o.order_id,o.customer_id,c.customer_unique_id ,o.order_status,o.order_purchase_timestamp,
    o.order_approved_at,o.order_delivered_carrier_date,order_delivered_customer_date, o.order_estimated_delivery_date 
    FROM olist_orders_dataset AS o JOIN olist_customers_dataset AS c ON o.customer_id = c. customer_id
    WHERE (DATE_TRUNC('month', o.order_purchase_timestamp::DATE)
          NOT IN (
              DATE '2016-09-01',
              DATE '2016-12-01',
              DATE '2018-09-01',
              DATE '2018-10-01'))  AND (o.order_purchase_timestamp :: DATE IS NOT NULL)
)
,
-- creating order month for each order
order_months AS (
    SELECT o.customer_id, DATE_TRUNC('month', o.order_purchase_timestamp::DATE) AS order_month
    FROM  orders_dataframe AS o JOIN olist_customers_dataset AS c ON o.customer_id = c.customer_id 
)
,
-- actually assigning the cohort month
first_purchase_month AS (
SELECT customer_unique_id ,DATE_TRUNC('month', MIN(order_purchase_timestamp::DATE)) AS cohort_month
FROM orders_dataframe   GROUP BY customer_unique_id
)
,
-- joining the revenue from each order for each unique customer
revenue_by_customer AS (
SELECT c.customer_unique_id,SUM(py.payment_value) AS revenue_per_customer
FROM olist_customers_dataset AS c JOIN olist_orders_dataset AS o ON c.customer_id = o.customer_id JOIN olist_order_payments_dataset AS py 
ON o.order_id = py.order_id 
GROUP BY c.customer_unique_id
)

-- Combined first_purchase_month and revenue PER cohort 

/*SELECT 
 fpm.cohort_month ,SUM(rbc.revenue_per_customer) AS revenue_per_cohort,COUNT(fpm.customer_unique_id ) AS number_of_customer, 
 SUM(rbc.revenue_per_customer)/COUNT(fpm.customer_unique_id ) AS average_revenue_per_customer
FROM first_purchase_month AS fpm JOIN revenue_by_customer AS rbc ON fpm.customer_unique_id = rbc.customer_unique_id
GROUP BY fpm.cohort_month 
ORDER BY average_revenue_per_customer DESC  */            

-- so November , 2017 cohort cutomers produced the most revenue and October, 2016 cohorts produced the least revenue.
--  while November, 2017 also had the highest number of customer who placed an order .


-- For each order , how many months after the first purchase it was placed 

,cohort_data AS (
SELECT c.customer_unique_id ,fpm.cohort_month, o.order_id ,
 DATE_TRUNC('month', order_purchase_timestamp::DATE) AS month_of_purchase,
 ((EXTRACT(YEAR FROM DATE_TRUNC('month', order_purchase_timestamp::DATE))
 	- EXTRACT(YEAR FROM fpm.cohort_month)) *12 
 	+
 	 (EXTRACT(MONTH FROM DATE_TRUNC('month', o.order_purchase_timestamp::DATE))
        -EXTRACT(MONTH FROM fpm.cohort_month))) AS months_since_first_purchase
FROM orders_dataframe AS o JOIN olist_customers_dataset AS c ON o.customer_id = c.customer_id 
JOIN first_purchase_month AS fpm ON c.customer_unique_id = fpm.customer_unique_id 
GROUP BY c.customer_unique_id ,fpm.cohort_month, o.order_id , o.order_purchase_timestamp 
)

-- Retention rate for each cohort month
,
retention_counts AS (
    SELECT
        cohort_month,
        months_since_first_purchase,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_data
    GROUP BY
        cohort_month,
        months_since_first_purchase
)

,
cohort_sizes AS (
    SELECT
        cohort_month,
        active_customers AS cohort_size
    FROM retention_counts
    WHERE months_since_first_purchase = 0
),

retention_rates AS (
SELECT rc.cohort_month,cs.cohort_size,rc.months_since_first_purchase,rc.active_customers,
ROUND (( rc.active_customers * 100.0/ cs.cohort_size)::NUMERIC,2) AS retention_rate
FROM retention_counts AS rc
JOIN cohort_sizes  AS cs ON rc.cohort_month = cs.cohort_month
ORDER BY rc.cohort_month,rc.months_since_first_purchase
)

SELECT *
FROM retention_rates
ORDER BY cohort_month
    ,months_since_first_purchase;






