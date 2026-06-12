-- RFM Segmentation

CREATE VIEW  rfm_analysis AS


WITH max_date AS (
    SELECT MAX(order_purchase_timestamp::DATE) AS max_d
    FROM olist_orders_dataset
)

,
rfm_base AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp::DATE) AS last_purchase,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(p.payment_value) AS monetary
    FROM olist_orders_dataset AS  o
    JOIN olist_order_payments_dataset AS p ON o.order_id = p.order_id
    JOIN olist_customers_dataset AS c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

monetary_percentiles AS(
SELECT  
    PERCENTILE_CONT(0.20) WITHIN GROUP (ORDER BY monetary) AS p20,
    PERCENTILE_CONT(0.40) WITHIN GROUP (ORDER BY monetary) AS p40,
    PERCENTILE_CONT(0.60) WITHIN GROUP (ORDER BY monetary) AS p60,
    PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY monetary) AS p80
FROM rfm_base
)                                         -- 55.2599983215332	87.36000061035156	132.69599914550778	208.5500030517578

,

rfm_days AS (
    SELECT 
        b.*,
        (md.max_d - b.last_purchase) AS recency_days
    FROM rfm_base AS b
    CROSS JOIN max_date AS md
),

rfm_scores AS (
    SELECT *,
    NTILE(5) OVER (ORDER BY (recency_days) DESC) AS r_score,
    CASE
    WHEN frequency >= 3 THEN 5
    WHEN frequency = 2 THEN 4
    ELSE 1 END AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_days
)


,
rfm_segmentation AS (
SELECT *,
r_score + f_score + m_score AS rfm_total,
r_score::TEXT || f_score::TEXT || m_score::TEXT AS rfm_segment
FROM rfm_scores 
)

-- Assign segment labels based on RFM total

-- SELECT DISTINCT(rfm_total) , COUNT(customer_unique_id) FROM  rfm_segmentation GROUP BY DISTINCT(rfm_total);

-- SELECT * FROM rfm_segmentation ORDER BY r_score DESC ;

,

/* Champions

Customers who purchased recently, spend a lot, and have made repeat purchases.
These are the most valuable customers and are the highest priority for retention.

Loyal

Customers who purchased fairly recently and contribute good revenue.
They consistently generate value and have the potential to become Champions.

At-Risk

Customers who were valuable in the past but haven't purchased recently.
Without re-engagement efforts, they are likely to stop buying altogether.

Lost/Inactive

Customers with low engagement and low overall value.
They have either stopped interacting with the business or were never highly active customers*/

customer_types AS (
SELECT *,
CASE
    WHEN r_score >= 4
         AND m_score >= 4
         AND f_score >= 3
    THEN 'Champions'

    WHEN r_score >= 3
         AND m_score >= 3
    THEN 'Loyal'

    WHEN r_score <= 2
    THEN 'At-Risk'

    ELSE 'Lost/Inactive'
END AS customer_type
FROM rfm_segmentation
)

-- How many customers we have in each category 

-- SELECT DISTINCT(f_score),COUNT(customer_unique_id) FROM customer_types GROUP BY  DISTINCT(f_score); 1: 90556 , 3: 2573 , 5: 228

-- SELECT customer_type ,COUNT(customer_unique_id) FROM customer_types GROUP BY customer_type;

-- Champions:985 , Lost/Inactive:21,938	 , At-Risk:37,344 , Loyal:33,090  


-- SELECT * FROM customer_types;


-- How much revenue we have in each category 
/*SELECT
customer_type , SUM(monetary) FROM customer_types GROUP BY customer_type; */  -- Champions: 214,093.69 , Lost/Inactive: 1,406,469.2 
																	    	-- At-Risk: 7,120,812.5 ,     Loyal: 6,681,179.5
        


--  what % of total. , we have in each category 


/*SELECT SUM(py.payment_value) FROM olist_order_payments_dataset AS py JOIN olist_orders_dataset AS o ON  py.order_id=o.order_id 
WHERE (DATE_TRUNC('month', o.order_purchase_timestamp::DATE)
          NOT IN (
              DATE '2016-09-01',
              DATE '2016-12-01',
              DATE '2018-09-01',
              DATE '2018-10-01'))  AND (o.order_purchase_timestamp :: DATE IS NOT NULL) ;*/  -- total revenue = 15422504



/*SELECT
customer_type , ROUND((SUM(monetary)/15422504 ):: NUMERIC,4)
FROM customer_types GROUP BY customer_type;*/                    -- Champions	2.38%  ,  Lost/Inactive	7.76%
																-- At-Risk	40.06%     ,    Loyal	49.79% 

/*SELECT DISTINCT(frequency) , COUNT(customer_unique_id) 
FROM customer_types 
GROUP BY DISTINCT(frequency)  */                     -- Mostly one-time buyers .Very few repeat buyers

SELECT * FROM customer_types ;




