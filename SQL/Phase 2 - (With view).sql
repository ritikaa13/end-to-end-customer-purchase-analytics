use customer_analytics;

show tables;

select * from stg_orders;


#  upadate the total_amount column (quantity * unit_price)
update stg_orders
set total_amount = quantity * unit_price;

select * from stg_orders;


# 1. top-line customers KPI
create view Kpi_summary_vw as
(
select 
count(distinct customer_id) as total_customers,
count(distinct invoice_no) as total_orders,
sum(total_amount)  as total_revenue,
round(sum(total_amount) / count(distinct invoice_no),2) as Avg_order_value,
round(sum(total_amount) / count(distinct customer_id),2) as Avg_revenue_per_customer
from stg_orders
);


# 2. Repeat purchase Rate.
create view Repeat_purchase_Rate_vw as
(
with cust as 
(select customer_id, count(distinct(invoice_no)) as n_orders
from stg_orders group by customer_id)
select round(sum(case when n_orders > 1 then 1 else 0 end) / 
					count(*) * 100, 2) as Repeat_purchase_Rate_pct 
from cust
);


# 3. top 10 customers by revenue. 
(select customer_id, sum(total_amount) as tot_revenue 
from stg_orders
group by customer_id
order by tot_revenue desc
limit 10);


# 4. New VS Repeat Customers by month 
create view new_vs_repeat_vw as
(
with fisrt_perchase as ( 
select customer_id, min(invoice_date) as first_date
from stg_orders group by customer_id
)
select date_format(SO.invoice_date,'%Y-%m') as ym,
count(case when date_format(SO.invoice_date,'%Y-%m') = date_format(FP.first_date,'%Y-%m') 
then SO.customer_id end) As new_customer,
count(case when date_format(SO.invoice_date,'%Y-%m') > date_format(FP.first_date,'%Y-%m') 
then SO.customer_id end)  as repeat_Customers
from stg_orders as SO
join fisrt_perchase FP on  SO.customer_id = FP.customer_id
group by ym
order by ym
);


# 5. Customer order Frequency Distribution (one-time,casual,Regular,loyal,VIP)
create view frequency_distribution_vw as
(
with cust as 
(select customer_id, count(distinct(invoice_no)) as n_orders
from stg_orders group by customer_id )
Select *,  
case
	when n_orders = 1 then 'one-time'
    when n_orders between 2 and 5 then 'Casual'
    when n_orders between 6 and 10 then 'Regular'
    when n_orders between 11 and 20 then 'Loyal'
    else 'VIP'
    end as Frequency_flag
from cust
);


# 6. Churn Signal; 
select customer_id, 
datediff((select max(invoice_date) from stg_orders),max(invoice_date)) as date_incative,
count(distinct invoice_no) as total_order,
sum(total_amount) as lifetime_revenue
from stg_orders
group by customer_id
having date_incative >= 90 and total_order >= 3
order by lifetime_revenue desc;


# 7. One-and-done products (bought once, never again).
CREATE view vw_one_and_done AS
(
select `description`,count(distinct customer_id) as buyers 
from stg_orders
where customer_id in (
select customer_id from stg_orders
group by customer_id
having count(distinct invoice_no) = 1
)
group by `description` 
having  buyers >= 10
order by buyers desc
limit 10
);


#8. top product diving repeat purchasses.
create view repeat_drivers_vw as 
(select `description`, 
count(distinct customer_id) as unique_customers,
count(distinct invoice_no) as times_ordered,
count(distinct invoice_no) /  count(distinct customer_id) as orders_per_customer
from stg_orders
group by `description`
having unique_customers >= 20
order by orders_per_customer desc
limit 10
);


# 9. Revenue by country 
select country,
count(distinct customer_id) as total_customers,
sum(total_amount) as total_revenue,
sum(total_amount) / count(distinct customer_id) as AVG_revenue_per_customer
from stg_orders 
group by country
order by total_revenue desc
limit 10;


# 10. monthly Active Customers Trend.
select date_format(invoice_date, "%Y-%m") as ym,
count(distinct customer_id) as active_customers,
sum(total_amount) as revenue
from stg_orders
group by ym
order by ym;


# 11. customers Rank by Spend within country.
select country,customer_id,revenue,
rank() over(partition by country order by revenue desc) as customer_rank
from 
(select country,customer_id,sum(total_amount) as revenue
from stg_orders 
group by country,customer_id
order by country, revenue desc) as t;


# 12. Days since Last Order ( live churn score) ("active", "cooling", "At-risk", "Churned")
create view churn_status_vw as 
select customer_id, 
max(invoice_date) as last_date,
datediff((select max(invoice_date) from stg_orders),max(invoice_date)) as date_incative,
case 
	when datediff((select max(invoice_date) from stg_orders),max(invoice_date)) <= 30 then "Active"
    when datediff((select max(invoice_date) from stg_orders),max(invoice_date)) <= 90 then "cooling"
    when datediff((select max(invoice_date) from stg_orders),max(invoice_date)) <= 180 then "At-risk"
    else "Churned"
end as "Churn_flag"
from stg_orders
group by customer_id;


#13. Avg Days Between orders Per Customers.
with diff as (
select customer_id, invoice_date,
lag(invoice_date) over(partition by customer_id order by invoice_date) as pre_date
from (select distinct customer_id, invoice_date from stg_orders) as t)
select customer_id,
avg(datediff(invoice_date,pre_date)) as avg_days_btw_orders
from diff
where pre_date is not null
group by customer_id
order by avg_days_btw_orders desc;


# 14. Customer Liftime Value
CREATE VIEW vw_clv_distribution AS
(
with CLV as 
(select customer_id,  sum(total_amount) as revenue, 
count(distinct invoice_no) as orders,
datediff(max(invoice_date),min(invoice_date)) as lifespan_days
from stg_orders 
group by customer_id)
select customer_id,revenue as clv,orders,
revenue / orders  as Aov,
lifespan_days
from CLV
order by clv desc
);


# 15. RFM Scoring (the centrepiece)
WITH base AS (
   SELECT customer_id,
          DATEDIFF((SELECT MAX(invoice_date) FROM stg_orders), MAX(invoice_date)) AS recency,
          COUNT(DISTINCT invoice_no) AS frequency,
          SUM(total_amount)          AS monetary
   FROM stg_orders GROUP BY customer_id
),
scored AS (
   SELECT customer_id, recency, frequency, monetary,
          NTILE(5) OVER (ORDER BY recency DESC)  AS r_score,
          NTILE(5) OVER (ORDER BY frequency)     AS f_score,
          NTILE(5) OVER (ORDER BY monetary)      AS m_score
   FROM base
)
SELECT customer_id, recency, frequency, monetary,
       r_score, f_score, m_score,
       (r_score + f_score + m_score) AS rfm_score
FROM scored;


# 16. Cohort Retention Matrix
create view vw_cohort  as
(
WITH first_order AS (
   SELECT customer_id,
          DATE_FORMAT(MIN(invoice_date),'%Y-%m') AS cohort_month
   FROM stg_orders GROUP BY customer_id
),
activity AS (
   SELECT SO.customer_id, fo.cohort_month,
          DATE_FORMAT(SO.invoice_date,'%Y-%m') AS active_month,
          PERIOD_DIFF(DATE_FORMAT(SO.invoice_date,'%Y%m'),
                      DATE_FORMAT(STR_TO_DATE(CONCAT(fo.cohort_month,'-01'),'%Y-%m-%d'),'%Y%m'))
            AS month_number
   FROM stg_orders SO
   JOIN first_order fo ON SO.customer_id = fo.customer_id
)
SELECT cohort_month, month_number,
       COUNT(DISTINCT customer_id) AS active_customers
FROM activity
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number
);
  

# 17. AOV by Customer Segment
WITH freq AS (
   SELECT customer_id, COUNT(DISTINCT invoice_no) AS n_orders
   FROM stg_orders GROUP BY customer_id
),
seg AS (
   SELECT customer_id,
     CASE
        WHEN n_orders = 1 THEN 'One-Time'
        WHEN n_orders <= 3 THEN 'Casual'
        WHEN n_orders <= 6 THEN 'Regular'
        ELSE 'Loyal'
     END AS segment
   FROM freq
)
SELECT s.segment,
       COUNT(DISTINCT SO.invoice_no) AS orders,
       ROUND(SUM(SO.total_amount)/COUNT(DISTINCT SO.invoice_no), 2) AS aov
FROM stg_orders SO JOIN seg s USING (customer_id)
GROUP BY s.segment;

with frequence as (
select customer_id, count(distinct invoice_no) as N_orders 
from stg_orders group by customer_id),
category as 
(select customer_id, N_orders,
case 
	when N_orders  = 1 then "One-time"
    when N_orders  <= 3 then "Casual"
    when N_orders <= 6 then "Regular"
    else "Loyal"
end as cust_category
from frequence)
select C.cust_category,
count(distinct SO.invoice_no) as total_orders,
round(sum(SO.total_amount) / count(distinct SO.invoice_no),2) as aov
from stg_orders SO
join category C using (customer_id)
group by C.cust_category;


# 18. First Order Value vs Lifetime Value
create view vw_fov_ltv as 
(
WITH first_order AS (
   SELECT customer_id, invoice_no,
          ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY invoice_date) AS rn
   FROM (SELECT DISTINCT customer_id, invoice_no, invoice_date FROM stg_orders) d
),
fov AS (
   SELECT o.customer_id, SUM(o.total_amount) AS first_order_value
   FROM stg_orders o 
   JOIN first_order f
        ON o.customer_id = f.customer_id AND o.invoice_no = f.invoice_no
   WHERE f.rn = 1
   GROUP BY o.customer_id
),
ltv AS (
   SELECT customer_id, SUM(total_amount) AS lifetime_value
   FROM stg_orders GROUP BY customer_id
)
SELECT fov.customer_id, fov.first_order_value, ltv.lifetime_value,
       ROUND(ltv.lifetime_value / NULLIF(fov.first_order_value,0), 2) AS ltv_to_fov_ratio
FROM fov JOIN ltv USING (customer_id)
ORDER BY lifetime_value DESC LIMIT 50
);


# 19. RFM Segment Assignment
create view vw_customer_segments as 
(
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
FROM rfm
);


# 20. Build the Power BI Master View
CREATE VIEW customer_mart AS
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


select * from kpi_summary_vw;

SHOW FULL TABLES IN customer_analytics WHERE TABLE_TYPE = 'VIEW';

select count(distinct invoice_no) from stg_orders;