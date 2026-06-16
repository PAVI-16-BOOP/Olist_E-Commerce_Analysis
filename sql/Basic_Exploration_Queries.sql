-- Finding total revenue , customers , orders

SELECT *
FROM olist_order_payments_dataset;

SELECT COUNT(*)
FROM olist_order_payments_dataset;    -- 103886 orders s(including all the installments for an order_id)

SELECT *
FROM olist_customers_dataset ocd ;

SELECT COUNT(DISTINCT(customer_unique_id))
FROM olist_customers_dataset  ;     -- 96,096 unique customers

SELECT
COUNT(*) as total_orders,
COUNT(DISTINCT c.customer_unique_id) AS total_customers,
COUNT(*) - COUNT(DISTINCT c.customer_unique_id) as repeat_orders
FROM olist_orders_dataset AS o JOIN olist_customers_dataset AS c ON o.customer_id = c.customer_id;    -- 3,345 customers placed >1 orders


SELECT *
FROM olist_orders_dataset ;

SELECT  COUNT(order_id)
FROM olist_orders_dataset ;         -- 99441  = actual number of total orders

-- No. of orders which were delivered at the time of end of data collection 

SELECT order_status, COUNT(*) as count
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY count DESC;          -- about 96,478 orders had been delivered out of a total of 99,441 orders

-- Finding date range of the entire data (from olist_orders_dataset's order_purchase_timestamp)

SELECT
    MIN(order_purchase_timestamp::DATE) AS first_order_date,
    MAX(order_purchase_timestamp::DATE) AS last_order_date
FROM olist_orders_dataset;            


-- null counts in each table's key columns 

SELECT COUNT(customer_unique_id)
FROM olist_customers_dataset 
WHERE customer_unique_id IS NULL ;     -- 0 null values for olist_customers_dataset

SELECT COUNT(geolocation_zip_code_prefix )
FROM olist_geolocation_dataset 
WHERE geolocation_zip_code_prefix  IS NULL ;     -- 0 null values for olist_geolocation_dataset

SELECT COUNT(order_item_id)
FROM olist_order_items_dataset 
WHERE order_item_id IS NULL ;     -- 0 null values for olist_order_items_dataset

SELECT COUNT(order_id )
FROM olist_order_payments_dataset
WHERE order_id IS NULL ;     -- 0 null values for olist_order_payments_dataset

SELECT COUNT(review_id )
FROM olist_order_reviews_dataset
WHERE review_id IS NULL ;     -- 0 null values here also

SELECT COUNT(order_id )
FROM olist_orders_dataset
WHERE order_id IS NULL ;     -- 0 null values here also


SELECT COUNT(seller_id )
FROM olist_sellers_dataset
WHERE seller_id IS NULL ;     -- 0 null values here also

SELECT COUNT(product_id )
FROM olist_products_dataset
WHERE product_id IS NULL ;     -- 0 null values here also

SELECT COUNT(product_category_name)
FROM product_category_name_translation
WHERE product_category_name IS NULL ;     -- 0 null values here also

--- making orders by status 

SELECT DISTINCT(order_status)
FROM  olist_orders_dataset;         -- shipped,unavailable,invoiced,created,approved,processing,delivered,canceled

SELECT order_status,COUNT(order_id)
FROM  olist_orders_dataset
GROUP BY (order_status);           '''
										shipped	1107
										unavailable	609
										invoiced	314
										created	5
										approved	2
										processing	301
										delivered	96478
										canceled	625'''

SELECT *                            -- Sorted by order_status
FROM  olist_orders_dataset
ORDER BY (order_status);

-- Monthly Revenue Trend ( using olist_order_payments and olist_orders_dataset by joining on order_id)

SELECT * FROM olist_orders_dataset;

SELECT 
	EXTRACT(MONTH FROM (o.order_purchase_timestamp::DATE)) AS month_of_purchase,
	EXTRACT(YEAR FROM (o.order_purchase_timestamp::DATE)) AS year_of_purchase ,
	SUM(p.payment_value)
	FROM olist_order_payments_dataset AS p
	JOIN olist_orders_dataset AS o
	ON  p.order_id = o.order_id 
	GROUP BY EXTRACT(MONTH FROM (o.order_purchase_timestamp::DATE)),EXTRACT(YEAR FROM (o.order_purchase_timestamp::DATE))
	ORDER BY EXTRACT(MONTH FROM (o.order_purchase_timestamp::DATE)),EXTRACT(YEAR FROM (o.order_purchase_timestamp::DATE));
	
-- top 10 product categories(total 74 categories are there across all products) by revenue 


SELECT COUNT(DISTINCT(product_category_name)) FROM olist_products_dataset;

SELECT p.product_category_name , SUM(i.price)
FROM olist_order_items_dataset AS i
JOIN olist_products_dataset AS p
ON i.product_id = p.product_id 
GROUP BY p.product_category_name


-- top 10 states by revenue (using olist_customers_dataset, olist_order_payments_dataseta and olist_orders_dataset)

SELECT c.customer_state , SUM(p.payment_value) AS revenue
FROM olist_customers_dataset AS c
JOIN olist_orders_dataset AS o
ON c.customer_id = o.customer_id 
JOIN olist_order_payments_dataset AS p
ON o.order_id = p.order_id 
GROUP BY  c.customer_state ORDER BY revenue DESC;          -- SP,RJ and MG are the top 3 states by revenue 

-- Average order value overall and by category 

SELECT ROUND(AVG(payment_value)::NUMERIC,3) AS average_value_per_order   -- overall
FROM olist_order_payments_dataset ;

SELECT 
	p.product_category_name, ROUND(AVG(i.price)::NUMERIC,2) AS rev
	FROM olist_products_dataset AS p
    JOIN olist_order_items_dataset AS i ON p.product_id = i.product_id 
	GROUP BY p.product_category_name ORDER BY rev DESC;                    -- by category 
	
	
--  Revenue concentration: Do top 25% of customers drive 66%+ of revenue?

WITH customer_spend AS (
    SELECT
        c.customer_unique_id,
        SUM(py.payment_value) AS total_spend_per_customer
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o
        ON c.customer_id = o.customer_id
    JOIN olist_order_payments_dataset py
        ON o.order_id = py.order_id
    GROUP BY c.customer_unique_id
),

quartile_assignment AS (
    SELECT
        customer_unique_id,
        total_spend_per_customer,
        NTILE(4) OVER (ORDER BY total_spend_per_customer DESC) AS spend_quartile
    FROM customer_spend
),

quartile_summary AS (
    SELECT
        spend_quartile,
        COUNT(*) AS customer_count,
        SUM(total_spend_per_customer) AS quartile_revenue
    FROM quartile_assignment
    GROUP BY spend_quartile
)

SELECT
spend_quartile,
customer_count,
ROUND(quartile_revenue::NUMERIC, 2) AS quartile_revenue,
ROUND((
100 * quartile_revenue
/ SUM(quartile_revenue) OVER ())::NUMERIC,
    1) AS pct_of_total_revenue
FROM quartile_summary
ORDER BY spend_quartile;

/*Key Findings

 
The top 25% of customers (Quartile 1) generated nearly 60% of total revenue, even though they represent only a quarter of the customer base. This shows that a relatively small group of customers is driving most of the business.
The bottom 50% of customers (Quartiles 3 and 4) together contributed only about 19% of total revenue. These customers either purchase infrequently or spend very little per order.
Revenue contribution drops sharply as we move from the highest-spending customers to the lowest-spending customers. This indicates a strong concentration of spending among a limited number of customers.
The spending pattern resembles a classic Pareto (80/20) effect, where a small percentage of customers contribute a disproportionately large share of revenue.

Business Suggestions

Focus on retaining and rewarding the highest-spending customers through loyalty programs, exclusive offers, and personalized recommendations. Losing these customers would have a significant impact on revenue.
Create targeted campaigns to move customers from Quartile 2 into Quartile 1, as even a small increase in spending from these customers could generate substantial revenue growth.
For lower-spending customers, encourage larger purchases through bundles, discounts on minimum order values, and cross-selling strategies.
Consider building separate marketing strategies for high-value and low-value customers instead of treating all customers the same, since their revenue contributions differ significantly.*/
