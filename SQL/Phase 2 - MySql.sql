use customer_analytics;

-- SHOW ALL TABLES
show tables;

-- VIEW COMPLETE ORDERS DATA
SELECT 
    *
FROM
    stg_orders;

-- CALCULATE TOTAL AMOUNT FOR EACH ORDER ROW
SELECT 
    quantity,
    unit_price,
    (quantity * unit_price) AS total_amount
FROM
    stg_orders;

-- UPDATE TOTAL_AMOUNT COLUMN
SET SQL_SAFE_UPDATES = 0;

UPDATE stg_orders 
SET 
    total_amount = quantity * unit_price;

SET SQL_SAFE_UPDATES = 1;

-- VERIFY UPDATED DATA
SELECT 
    *
FROM
    stg_orders;


-- =====================================================
-- 1. TOP-LINE CUSTOMER KPI
-- =====================================================

SELECT 
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT invoice_no) AS total_orders,
    SUM(total_amount) AS total_revenue,
    SUM(total_amount) / COUNT(DISTINCT invoice_no) AS Avg_Order_Value,
    SUM(total_amount) / COUNT(DISTINCT customer_id) AS Avg_Revenue_Per_Customer
FROM
    stg_orders;

-- =====================================================
-- 2. REPEAT PURCHASE RATE
-- =====================================================

with cust as (
    select 
        customer_id,
        count(distinct invoice_no) as n_orders
    from stg_orders
    group by customer_id
)
select 
    round(
        sum(
            case 
                when n_orders > 1 then 1
                else 0
            end
        ) / count(*) * 100,
    2) as Repeat_Purchase_Rate_Pct
from cust;

-- =====================================================
-- 3. TOP 10 CUSTOMERS BY REVENUE
-- =====================================================

SELECT 
    customer_id, ROUND(SUM(total_amount), 2) AS total_revenue
FROM
    stg_orders
GROUP BY customer_id
ORDER BY total_revenue DESC
LIMIT 10;

-- =====================================================
-- 4. NEW VS REPEAT CUSTOMERS BY MONTH
-- =====================================================

with first_purchase as (
    select 
        customer_id,
        min(invoice_date) as first_date
    from stg_orders
    group by customer_id
)
select 
    date_format(SO.invoice_date, '%Y-%m') as ym,
    count(
        case 
            when date_format(SO.invoice_date, '%Y-%m') =
                 date_format(FP.first_date, '%Y-%m')
            then SO.customer_id
        end
    ) as New_Customers,
    count(
        case 
            when date_format(SO.invoice_date, '%Y-%m') >
                 date_format(FP.first_date, '%Y-%m')
            then SO.customer_id
        end
    ) as Repeat_Customers
from stg_orders as SO
join first_purchase FP
    on SO.customer_id = FP.customer_id
group by ym
order by ym;

-- =====================================================
-- 5. CUSTOMER ORDER FREQUENCY DISTRIBUTION
-- (ONE-TIME, CASUAL, REGULAR, LOYAL, VIP)
-- =====================================================

with cust as (
    select 
        customer_id,
        count(distinct invoice_no) as n_orders
    from stg_orders
    group by customer_id
)
select 
    customer_id,
    n_orders,
    case
        when n_orders = 1 then 'One-Time'
        when n_orders between 2 and 5 then 'Casual'
        when n_orders between 6 and 10 then 'Regular'
        when n_orders between 11 and 20 then 'Loyal'
        else 'VIP'
    end as Frequency_Flag
from cust;

-- =====================================================
-- 6. CHURN SIGNAL
-- =====================================================

SELECT 
    customer_id,
    DATEDIFF((SELECT 
                    MAX(invoice_date)
                FROM
                    stg_orders),
            MAX(invoice_date)) AS date_inactive,
    COUNT(DISTINCT invoice_no) AS total_order,
    SUM(total_amount) AS lifetime_revenue
FROM
    stg_orders
GROUP BY customer_id
HAVING date_inactive >= 90 AND total_order >= 3
ORDER BY lifetime_revenue DESC;

-- =====================================================
-- 7. ONE-AND-DONE PRODUCTS
-- (BOUGHT ONCE, NEVER AGAIN)
-- =====================================================

SELECT 
    `description`, COUNT(DISTINCT customer_id) AS buyers
FROM
    stg_orders
WHERE
    customer_id IN (SELECT 
            customer_id
        FROM
            stg_orders
        GROUP BY customer_id
        HAVING COUNT(DISTINCT invoice_no) = 1)
GROUP BY `description`
HAVING buyers >= 10
ORDER BY buyers DESC
LIMIT 10;

-- =====================================================
-- 8. TOP PRODUCTS DRIVING REPEAT PURCHASE
-- =====================================================

SELECT 
    `description`,
    COUNT(DISTINCT customer_id) AS unique_customer,
    COUNT(DISTINCT invoice_no) AS times_ordered,
    COUNT(DISTINCT invoice_no) / COUNT(DISTINCT customer_id) AS orders_per_customer
FROM
    stg_orders
GROUP BY `description`
HAVING unique_customer >= 20
ORDER BY orders_per_customer DESC
LIMIT 10;

-- =====================================================
-- 9. REVENUE BY COUNTRY
-- =====================================================

SELECT 
    country,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT invoice_no) AS total_orders
FROM
    stg_orders
GROUP BY country
ORDER BY total_revenue DESC;

-- =====================================================
-- 10. REVENUE BY COUNTRY
-- =====================================================

SELECT 
    country,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(total_amount) AS total_revenue,
    SUM(total_amount) / COUNT(DISTINCT customer_id) AS AVG_revenue_per_customer
FROM
    stg_orders
GROUP BY country
ORDER BY total_revenue DESC
LIMIT 10;

-- =====================================================
-- 11. CUSTOMER RANK BY SPEND WITHIN COUNTRY
-- =====================================================

select country, customer_id, revenue,
    rank() over(partition by country order by revenue desc) as customer_rank
from
(
    select country, customer_id, sum(total_amount) as revenue
    from stg_orders
    group by country, customer_id
    order by country, revenue desc
) as t;

-- =====================================================
-- 12. DAYS SINCE LAST ORDER 
-- (Live Churn Score)('Active', 'Cooling', 'At-Risk', Churned)
-- ===================================================== 

SELECT 
    customer_id,
    MAX(invoice_date) AS last_date,
    DATEDIFF((SELECT 
                    MAX(invoice_date)
                FROM
                    stg_orders),
            MAX(invoice_date)) AS date_inactive,
    CASE
        WHEN
            DATEDIFF((SELECT 
                            MAX(invoice_date)
                        FROM
                            stg_orders),
                    MAX(invoice_date)) <= 30
        THEN
            'Active'
        WHEN
            DATEDIFF((SELECT 
                            MAX(invoice_date)
                        FROM
                            stg_orders),
                    MAX(invoice_date)) <= 90
        THEN
            'cooling'
        WHEN
            DATEDIFF((SELECT 
                            MAX(invoice_date)
                        FROM
                            stg_orders),
                    MAX(invoice_date)) <= 180
        THEN
            'At-risk'
        ELSE 'Churned'
    END AS Churn_flag
FROM
    stg_orders
GROUP BY customer_id;

-- =====================================================
-- 13. AVG. DAYS BETWEEN ORDERS PER CUSTOMER
-- =====================================================

with diff as (
select customer_id,
    invoice_date,
    lag(invoice_date) over(
        partition by customer_id 
        order by invoice_date
    ) as pre_date
from (
    select distinct customer_id,
        date(invoice_date) as invoice_date
    from stg_orders
) as t
)
select customer_id,
    avg(datediff(invoice_date, pre_date)) as avg_days_btw_orders
from diff
where pre_date is not null
group by customer_id
order by avg_days_btw_orders desc;

-- =====================================================
-- 14. CUSTOMER LIFETIME VALUE
-- =====================================================

With CLV as
(select customer_id, 
	sum(total_amount) as revenue,
	count(distinct invoice_no) as orders,
	datediff(max(invoice_date),min(invoice_date)) as lifespan_days
from stg_orders
group by customer_id)
select customer_id, revenue as clv, orders,
revenue / orders as Aov,
lifespan_days
from CLV
order by clv desc;

-- =====================================================
-- 15. RFM SCORING 
-- (The CentrePiece)
-- =====================================================

With base As(
select customer_id,
	DateDiff((select max(invoice_date) from stg_orders), max(invoice_date)) as recency,
	count(distinct invoice_no) as frequency,
	sum(total_amount)          as monetary
from stg_orders group by customer_id),
scored as(
       select customer_id, recency, frequency, monetary,
               NTILE(5) over(order by recency desc) as R_score,
               NTILE(5) over(order by frequency desc) as F_score,
               NTILE(5) over(order by monetary desc) as M_score
	   from base 
       )
select customer_id,  recency, frequency, monetary
        r_score, f_score, m_score,
        (r_score + f_score + m_score) as RFM_score
from scored;

-- =====================================================
-- 16. COHORT RETENTION MATRIX
-- =====================================================

with first_order as (
select customer_id,
    date_format(min(invoice_date), '%Y-%m') as cohort_month
from stg_orders
group by customer_id
),
activity as (
select SO.customer_id, fo.cohort_month,
    date_format(SO.invoice_date, '%Y-%m') as active_month,
    period_diff(
        date_format(SO.invoice_date, '%Y%m'),
        date_format(
            str_to_date(concat(fo.cohort_month, '-01'), '%Y-%m-%d'),
            '%Y%m'
        )
    ) as month_number
from stg_orders SO
join first_order fo
on SO.customer_id = fo.customer_id
)
select cohort_month, month_number,
    count(distinct customer_id) as active_customers
from activity
group by cohort_month, month_number
order by cohort_month, month_number;

-- =====================================================
-- 17. AOV BY CUSTOMER SEGMENT
-- =====================================================

with freq as (
select customer_id,
    count(distinct invoice_no) as n_orders
from stg_orders
group by customer_id
),
seg as (
select customer_id,
    case
        when n_orders = 1 then 'One-Time'
        when n_orders <= 3 then 'Casual'
        when n_orders <= 6 then 'Regular'
        else 'Loyal'
    end as segment
from freq
)
select s.segment,
    count(distinct SO.invoice_no) as orders,
    round(sum(SO.total_amount) / count(distinct SO.invoice_no), 2) as aov
from stg_orders SO
join seg s using (customer_id)
group by s.segment;

-- =====================================================
-- 18. FIRST ORDER VALUE VS LIFETIME VALUE
-- =====================================================

with first_order as (
select customer_id, invoice_no,
    row_number() over(partition by customer_id order by invoice_date) as rn
from (
    select distinct customer_id,
        invoice_no,
        invoice_date
    from stg_orders
) d
),
fov as (
select o.customer_id,
    sum(o.total_amount) as first_order_value
from stg_orders o
join first_order f
on o.customer_id = f.customer_id
and o.invoice_no = f.invoice_no
where f.rn = 1
group by o.customer_id
),
ltv as (
select customer_id,
    sum(total_amount) as lifetime_value
from stg_orders
group by customer_id
)
select fov.customer_id,
    fov.first_order_value,
    ltv.lifetime_value,
    round(ltv.lifetime_value / nullif(fov.first_order_value, 0), 2) as ltv_to_fov_ratio
from fov
join ltv
using (customer_id)
order by lifetime_value desc
limit 50;

-- =====================================================
-- 19. RFM SEGMENT ASSIGNMENT
-- =====================================================

WITH rfm AS (
   SELECT customer_id, recency, frequency, monetary,
          NTILE(5) OVER (ORDER BY recency DESC) AS r,
          NTILE(5) OVER (ORDER BY frequency)    AS f,
          NTILE(5) OVER (ORDER BY monetary)     AS m
   FROM (
      SELECT customer_id,
             DATEDIFF((SELECT MAX(invoice_date) FROM stg_orders), MAX(invoice_date)) AS recency,
             COUNT(DISTINCT invoice_no) AS frequency,
             SUM(total_amount) AS monetary
      FROM stg_orders GROUP BY customer_id
   ) base
)
SELECT customer_id, r, f, m,
   CASE
     WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'VIP / Champions'
     WHEN r >= 4 AND f >= 3            THEN 'Loyal Customers'
     WHEN r >= 4 AND f <= 2            THEN 'New Customers'
     WHEN r <= 2 AND f >= 4            THEN 'At-Risk'
     WHEN r <= 2 AND f <= 2 AND m >= 3 THEN 'Hibernating'
     WHEN r <= 1                       THEN 'Lost'
     ELSE                                   'Others'
   END AS segment
FROM rfm;

-- =====================================================
-- 20. BUILD THE POWER BI MASTER VIEW
-- =====================================================

CREATE VIEW 
customer_mart AS
WITH base AS (
   SELECT customer_id, country,
          MIN(invoice_date) AS first_order_date,
          MAX(invoice_date) AS last_order_date,
          COUNT(DISTINCT invoice_no) AS frequency,
          SUM(total_amount)          AS monetary,
          DATEDIFF((SELECT MAX(invoice_date) FROM stg_orders), MAX(invoice_date)) AS recency
   FROM stg_orders GROUP BY customer_id, country
),
scored AS (
   SELECT *,
     NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
     NTILE(5) OVER (ORDER BY frequency)    AS f_score,
     NTILE(5) OVER (ORDER BY monetary)     AS m_score
   FROM base
)
SELECT *,
   (r_score + f_score + m_score) AS rfm_total,
   CASE
     WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'VIP / Champions'
     WHEN r_score >= 4 AND f_score >= 3                  THEN 'Loyal'
     WHEN r_score >= 4 AND f_score <= 2                  THEN 'New'
     WHEN r_score <= 2 AND f_score >= 4                  THEN 'At-Risk'
     WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Hibernating'
     WHEN r_score <= 1                                   THEN 'Lost'
     ELSE                                                     'Others'
   END AS segment,
   ROUND(monetary / NULLIF(frequency,0), 2) AS aov,
   DATEDIFF(last_order_date, first_order_date) AS lifespan_days
FROM scored;
select * from vw_customer_mart;