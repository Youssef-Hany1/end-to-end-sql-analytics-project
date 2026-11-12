/*
===============================================================================
Date Range Exploration
===============================================================================
Purpose:
    - To determine the temporal boundaries of key data points.
    - To understand the range of historical data.

SQL Functions Used:
    - MIN()
    - MAX()
    - DATEDIFF()
    - GETDATE()
===============================================================================
*/

-- Retrieve the first and last order dates and the sales date range
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(year, MIN(order_date), MAX(order_date)) AS order_range_years,
    DATEDIFF(month, MIN(order_date), MAX(order_date)) AS order_range_months
FROM gold.fact_sales;

-- Retrieve the youngest and oldest customer birthdates and ages
SELECT
    MAX(birth_date) AS youngest_birthdate,
    DATEDIFF(year, MAX(birth_date), GETDATE()) AS youngest_age,
    MIN(birth_date) AS oldest_birthdate,
    DATEDIFF(year, MIN(birth_date), GETDATE()) AS oldest_age,
    DATEDIFF(year, MIN(birth_date), MAX(birth_date)) AS age_range_years
FROM gold.dim_customers;