/*
===============================================================================
Ranking Analysis
===============================================================================
Purpose:
    - To rank items (e.g., products, customers) based on performance or other metrics.
    - To identify top performers or laggards.

SQL Functions Used:
    - Window Ranking Functions:
		- RANK()
		- DENSE_RANK()
		- ROW_NUMBER()
	- TOP
    - Clauses:
		- GROUP BY
		- ORDER BY
===============================================================================
*/

-- Which 5 products generate the highest revenue?
-- Simple Ranking
SELECT TOP 5
	p.product_name,
	SUM(s.sales_amount) AS total_revenue
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
ON s.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC;

-- Complex but Flexibly Ranking Using Window Functions
SELECT *
FROM (
	SELECT
		p.product_name,
		SUM(s.sales_amount) AS total_revenue,
		ROW_NUMBER() OVER (ORDER BY SUM(s.sales_amount) DESC) AS rank
	FROM gold.fact_sales s
	LEFT JOIN gold.dim_products p
	ON s.product_key = p.product_key
	GROUP BY p.product_name
)t WHERE rank <= 5;

-- What are the 5 worst-performing products in terms of sales
SELECT TOP 5
	p.product_name,
	SUM(s.sales_amount) AS total_revenue
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
ON s.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue ASC;

-- Find the top 10 customers who have generated the highest revenue
SELECT TOP 10
	c.customer_key,
	c.first_name,
	c.last_name,
	SUM(s.sales_amount) AS total_revenue
FROM gold.fact_sales s
LEFT JOIN gold.dim_customers c
ON s.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;

-- The 3 customers with the fewest orders placed
SELECT TOP 3
	c.customer_key,
	c.first_name,
	c.last_name,
	COUNT(DISTINCT s.order_number) AS total_orders
FROM gold.fact_sales s
LEFT JOIN gold.dim_customers c
ON s.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_orders ASC;

-- OR

SELECT *
FROM (
	SELECT
		c.customer_key,
		c.first_name,
		c.last_name,
		COUNT(DISTINCT f.order_number) AS total_orders,
		RANK() OVER (ORDER BY COUNT(DISTINCT f.order_number)) AS rank
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_customers c
	ON c.customer_key = f.customer_key
	GROUP BY c.customer_key, c.first_name, c.last_name
)t WHERE rank = 1;