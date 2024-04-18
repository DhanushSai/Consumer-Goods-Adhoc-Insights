SELECT * FROM gdb023.dim_customer;

-- 1. Provide the list of markets in which customer "Atliq Exclusive" 
-- operates its business in the APAC region

	select distinct market from dim_customer
	where customer = "Atliq Exclusive" 
	and region = "APAC";

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The
-- final output contains these fields,
					-- unique_products_2020
					-- unique_products_2021
					-- percentage_chg
                    
with cte2020 as (select count(distinct product_code) as unique_product_2020
from fact_sales_monthly
where fiscal_year = 2020
),

cte2021 as (select count(distinct product_code) as unique_product_2021
from fact_sales_monthly
where fiscal_year = 2021)

select *,
	CONCAT(ROUND((unique_product_2021 - unique_product_2020)*100 / unique_product_2020, 2), '%') as percentage_chg
from cte2020 JOIN cte2021;


 -- 3. Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts. The final output contains 2 fields,
			-- segment
			-- product_count
            
SELECT segment, 
count(distinct product) as product_count
from dim_product
group by segment
order by product_count DESC;

-- Follow-up: 4. Which segment had the most increase in unique products in
-- 2021 vs 2020? The final output contains these fields,
-- segment
-- product_count_2020
-- product_count_2021
-- difference

with cte2020 as (
		select dp.segment, 
		count(distinct product) as product_count_2020
		from dim_product dp
		JOIN fact_sales_monthly fsm
		ON dp.product_code = fsm.product_code
		where fsm.fiscal_year = 2020
		group by dp.segment
),
cte2021 as (
		select dp.segment, 
		count(distinct product) as product_count_2021
		from dim_product dp
		JOIN fact_sales_monthly fsm
		ON dp.product_code = fsm.product_code
		where fsm.fiscal_year = 2021
		group by dp.segment
) 

select product_count_2020, 
product_count_2021, 
(product_count_2021 - product_count_2020) as difference
from cte2020 c1 JOIN cte2021 c2 on
c1.segment = c2.segment
order by difference DESC;

-- 5. Get the products that have the highest and lowest manufacturing costs.
-- The final output should contain these fields,
-- product_code
-- product
-- manufacturing_cost 



select dc.product, dc.product_code 
from dim_product dc
JOIN fact_manufacturing_cost fmc
on dc.product_code = fmc.product_code
where fmc.manufacturing_cost = (select min(manufacturing_cost) from fact_manufacturing_cost) OR 
fmc.manufacturing_cost = (select min(manufacturing_cost) from fact_manufacturing_cost);


-- 6. Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market. The final output contains these fields,
-- customer_code
-- customer
-- average_discount_percentage

select dc.customer_code,
dc.customer, 
ROUND(avg(fpid.pre_invoice_discount_pct), 2) as average_discount_percentage	
from dim_customer dc
JOIN fact_pre_invoice_deductions fpid
ON dc.customer_code = fpid.customer_code
where dc.market = "India" and fpid.fiscal_year = 2021
group by dc.customer_code, dc.customer
order by average_discount_percentage DESC
LIMIT 5;


-- 7. Get the complete report of the Gross sales amount for the customer “Atliq
-- Exclusive” for each month. This analysis helps to get an idea of low and
-- high-performing months and take strategic decisions.
-- The final report contains these columns:
-- Month
-- Year
-- Gross sales Amount

SELECT monthname(s.date) as Month,
year(s.date) AS Year,
round(sum(s.sold_quantity * g.gross_price), 2) AS Gross_sales_Amount
FROM fact_gross_price g
JOIN fact_sales_monthly s 
ON g.product_code = s.product_code
JOIN dim_customer c 
ON c.customer_code = s.customer_code
WHERE c.customer = 'Atliq Exclusive'
GROUP BY monthname(s.date), year(s.date)
ORDER BY Gross_sales_Amount;
         
-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
-- output contains these fields sorted by the total_sold_quantity,
-- Quarter
-- total_sold_quantity

select
	case 
		when month(date) in (9, 10, 11) THEN "Q1"
		when month(date) in (12, 1, 2) THEN "Q2"
		when month(date) in (3, 4, 5) THEN "Q3"
		ELSE "Q4"
	END as Quater,
    sum(sold_quantity) as total_sold_quantity
from fact_sales_monthly
where fiscal_year = 2020
group by Quater;


-- 9. Which channel helped to bring more gross sales in the fiscal year 2021
-- and the percentage of contribution? The final output contains these fields,
-- channel
-- gross_sales_mln
-- percentage

with cte1 as (select dc.channel,
	ROUND(sum(sold_quantity * gross_price) / 1000000, 2) as gross_sales_mln
	from fact_sales_monthly fs
	JOIN fact_gross_price fg
	on fs.product_code = fg.product_code
	JOIN dim_customer dc
	on fs.customer_code = dc.customer_code
    where fs.fiscal_year = 2021
    group by dc.channel
)
select *, 
gross_sales_mln*100 / sum(gross_sales_mln) over() as pct
from cte1;

-- 10. Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021? The final output contains these fields,
-- division
-- product_code
-- product
-- total_sold_quantity
-- rank_order

with top3 as (
		select dp.division, dp.product_code, dp.product,
		sum(sold_quantity) as total_quantity
		from fact_sales_monthly fsm
		JOIN dim_product dp
		ON fsm.product_code = dp.product_code
		where fsm.fiscal_year = 2021
		group by dp.division, dp.product_code, dp.product
	),
    
top3_1 as (
	select *, 
    dense_rank() over(partition by top3.division order by total_quantity DESC) as rnk
    from top3
)
select * from top3_1 where rnk <= 3