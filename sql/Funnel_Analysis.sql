-- Funnel Analysis and Additional Insights


-- 1 : Order delivery funnel: what % of orders reach each stage?
-- WHY: Identifies operational bottlenecks. High cancellation at 'processing'
--      stage = payment issue. High abandonment at 'shipped' = logistics issue.

SELECT * FROM olist_orders_dataset ;

SELECT COUNT(*) FROM olist_orders_dataset ;   -- TOtal orders : 99,441

SELECT DISTINCT(order_status),COUNT(*)  , 
ROUND((COUNT(*)*100)/99441 :: NUMERIC,2)::TEXT || '%'  AS pct_of_total_orders 
FROM olist_orders_dataset 
GROUP BY DISTINCT(order_status)
ORDER BY COUNT(*) DESC;

/*Key Findings
 
- 97% of all orders were successfully delivered, which is an excellent fulfillment rate and shows that the overall order process is working well.
- Only about 0.6% of orders were cancelled and 0.6% became unavailable, indicating relatively few operational failures.
- Around 1.1% of orders are still in the shipped stage, suggesting some orders may be delayed in transit or awaiting final delivery confirmation.
- Very few orders remain in processing, approved, or created status, meaning orders are generally moving through the system quickly.

Business Interpretation

- The business has a strong and efficient order fulfillment process.
- Most customers who place an order successfully receive their products.
- Customer trust is likely supported by the high delivery success rate.
- The main opportunities for improvement lie in reducing cancellations, unavailable products, and shipping delays.

Suggestions

- Monitor shipped orders closely and investigate whether any logistics partners are causing delays.
- Reduce unavailable orders by improving inventory forecasting and stock management.
- Send proactive delivery updates to customers to improve their experience while orders are in transit.*/

-- 5.2 Delivery time analysis
-- WHY: Slower delivery = lower review score = higher churn
--      This is a feature you'll engineer in Python


SELECT *
FROM olist_orders_dataset
WHERE order_delivered_customer_date = '';   -- so there are dates where order_delivered_customer_date is '' (not - null) 



SELECT
ROUND(
    AVG(NULLIF(order_delivered_customer_date, '')::DATE
        -NULLIF(order_purchase_timestamp, '')::DATE
    ),2) AS avg_delivery_days
FROM olist_orders_dataset
WHERE order_status = 'delivered';       --avg. delivery days = 12.5


WITH delivery_times AS (
SELECT
    order_id,(NULLIF(order_delivered_customer_date,'')::DATE - NULLIF(order_purchase_timestamp,'')::DATE) AS delivery_days
FROM olist_orders_dataset WHERE order_status='delivered'
)

SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY delivery_days) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY delivery_days) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY delivery_days) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY delivery_days) AS p90
FROM delivery_times;                -- p25 : 7.0	p50 : 10.0	  p75 : 16.0	p90 : 23

/*SELECT delivery_days, COUNT(*)
FROM delivery_times
GROUP BY delivery_days
ORDER BY delivery_days;*/


/*

 Key Findings
 
25%of orders were delivered within 7 days.
50% of orders were delivered within 10 days (median delivery time).
75% of orders were delivered within 16 days.
90% of orders were delivered within 23 days.

Business Interpretation

Most customers received their orders in about 1–2 weeks, which is fairly reasonable for a large e-commerce platform.
The median (10 days) is lower than the average (12.5 days), which suggests a small number of very late deliveries are pulling the average up.
The jump from 16 days (75th percentile) to 23 days (90th percentile) shows that a small group of customers experience noticeably slower deliveries.

Problems Identified

Around 10% of customers wait more than 23 days, which can negatively affect customer satisfaction and reviews.
Extremely delayed orders (such as the 210-day outlier found earlier) indicate operational exceptions that need attention.
Delivery experience is not fully consistent across all customers.

Suggestions for Improvement

Focus on the slowest 10% of deliveries, since they contribute most to customer frustration.
Identify regions, products, or logistics partners associated with long delivery times.
Set internal delivery targets such as delivering 90% of orders within 20 days.
Provide proactive updates and tracking information when delays occur.*/

--3 Review score distribution

SELECT
    review_score,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM olist_order_reviews_dataset  WHERE review_score IS NOT NULL),1) as pct
FROM olist_order_reviews_dataset 
WHERE review_score IS NOT NULL
GROUP BY review_score ORDER BY review_score;
/*
1	11424	11.5
2	3151	3.2
3	8179	8.2
4	19142	19.3
5	57328	57.8*/

/*
  Key Findings
 
5-star reviews dominate the dataset, making up the majority of all reviews.
4-star reviews are also very common, showing that most customers had a positive experience.
1-star reviews are noticeably higher than 2-star and 3-star reviews, suggesting that when customers are unhappy, they tend to give very low ratings rather than moderate ones.
Overall, customer satisfaction appears to be strong.

Business Interpretation

Most customers are satisfied with their purchases, products, and delivery experience.
The high number of 4-star and 5-star reviews indicates a healthy customer experience.
However, the sizeable group of 1-star reviews should not be ignored because these customers are the most likely to churn and leave negative feedback.

Potential Problems

Some customers are having very poor experiences, leading directly to 1-star reviews.
These issues may be related to delayed deliveries, damaged products, incorrect items, or customer service problems.
Negative reviews can affect brand reputation and future sales.

Suggestions

Analyze 1-star reviews separately to identify the most common complaints.
Contact dissatisfied customers quickly and offer support, refunds, or replacements when appropriate.
Study what drives 5-star reviews and try to replicate those factors across more orders.
Monitor delivery delays and product quality, since these are common causes of poor ratings.*/

SELECT * FROM olist_order_reviews_dataset  WHERE review_score <= 2;



--4 MOST IMPORTANT: Does review score correlate with repeat purchase?
-- WHY: If customers who gave low scores never come back, review score is a churn predictor
--      This informs your feature engineering in Python
WITH customer_reviews AS (
SELECT
    c.customer_unique_id,
    AVG(r.review_score) as avg_review_score,
    COUNT(DISTINCT o.order_id) as total_orders
FROM olist_orders_dataset AS o
JOIN olist_customers_dataset AS c ON o.customer_id = c.customer_id
JOIN olist_order_reviews_dataset AS r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN avg_review_score < 3 THEN 'Low (1-2)'
        WHEN avg_review_score < 4 THEN 'Medium (3)'
        ELSE 'High (4-5)'
    END as review_group,
    COUNT(*) as customers,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
    ROUND(COUNT(CASE WHEN total_orders > 1 THEN 1 END) * 100.0 / COUNT(*), 1) AS pct_repeat_buyers
FROM customer_reviews 
GROUP BY review_group

/* 
 Key Findings
 
Most customers gave high ratings (4–5 stars), showing generally good customer satisfaction.
However, repeat purchase rates are low across all groups (around 2–5%).
Customers with medium ratings (3 stars) have the highest repeat purchase rate (5.4%), which is unexpected.
Customers with high ratings buy slightly more often than low-rating customers, but the difference is small.

Business Interpretation

Customer satisfaction alone does not seem to be a strong driver of repeat purchases in this dataset.
Many customers appear to buy only once, regardless of whether they were satisfied or dissatisfied.
This suggests that factors like product type, purchase frequency, promotions, or customer needs may have a bigger impact on repeat buying than review scores.

Possible Business Problems

The business may have a one-time purchase pattern, where customers buy only when they need something.
There may be limited customer retention efforts after the first purchase.
High satisfaction is not being converted into customer loyalty.

Suggestions

Target happy customers (4–5 stars) with loyalty programs, coupons, and personalized recommendations to encourage another purchase.
Follow up with 3-star reviewers, since they surprisingly show the highest repeat rate and may be easier to convert into loyal customers.
Investigate why repeat purchase rates are low overall, even among satisfied customers.
Combine review scores with other factors (delivery speed, order value, product category) to better understand customer retention.*/


