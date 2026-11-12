# Exploratory Data Analysis (EDA)

## 1. Objective

Understand the structure, dimensions, and measures of the Gold layer before running any business analysis. The EDA moves through six steps, each in its own script:

| Step | Script | Question answered |
|---|---|---|
| 1 | `01_database_exploration.sql` | What objects and columns exist? |
| 2 | `02_dimensions_exploration.sql` | What categories and values exist in the dimensions? |
| 3 | `03_date_range_exploration.sql` | What time span does the data cover? |
| 4 | `04_measures_exploration.sql` | What are the headline business numbers? |
| 5 | `05_magnitude_analysis.sql` | How do measures split across dimensions? |
| 6 | `06_ranking_analysis.sql` | Which products and customers perform best and worst? |

## 2. Data Source

All queries run against the Gold star schema from Project 1 (see `01_medallion_architecture_etl.md` and `gold_data_catalog.md`).

| View | Type | Columns used |
|---|---|---|
| `gold.dim_customers` | Dimension | `customer_key`, `first_name`, `last_name`, `country`, `gender`, `birth_date` |
| `gold.dim_products` | Dimension | `product_key`, `product_name`, `category`, `subcategory`, `cost` |
| `gold.fact_sales` | Fact | `order_number`, `customer_key`, `product_key`, `order_date`, `sales_amount`, `quantity`, `price` |

| Kind | Meaning | Examples in this model |
|---|---|---|
| Dimension | Descriptive, non-additive attribute used to group and filter | `country`, `gender`, `category`, dates |
| Measure | Numeric, additive value that can be aggregated | `sales_amount`, `quantity`, `price`, `cost` |

## 3. Methodology and Query Logic

### Step 1: Database Exploration (`01_database_exploration.sql`)

Reads the metadata views to learn what exists before querying it.

| Query | Purpose |
|---|---|
| `SELECT * FROM INFORMATION_SCHEMA.TABLES` | Lists all tables and views in the database |
| `SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'dim_customers'` | Lists column names, data types, and nullability for one object |

### Step 2: Dimensions Exploration (`02_dimensions_exploration.sql`)

Techniques: `DISTINCT`, `ORDER BY`.

| Query | Purpose |
|---|---|
| Distinct `country` from `dim_customers` | Where customers come from |
| Distinct `category`, `subcategory`, `product_name` from `dim_products` | The product hierarchy (ordered by columns 1, 2, 3) |

### Step 3: Date Range Exploration (`03_date_range_exploration.sql`)

Techniques: `MIN`, `MAX`, `DATEDIFF`, `GETDATE`.

| Query | Output |
|---|---|
| Sales date range | `first_order_date`, `last_order_date`, `order_range_years`, `order_range_months` |
| Customer age range | `youngest_birthdate` and `youngest_age`, `oldest_birthdate` and `oldest_age`, `age_range_years` |

```sql
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(year,  MIN(order_date), MAX(order_date)) AS order_range_years,
    DATEDIFF(month, MIN(order_date), MAX(order_date)) AS order_range_months
FROM gold.fact_sales;
```

> `DATEDIFF(year, ...)` counts calendar-year boundaries crossed, not completed years. A customer born on 31 Dec is counted one year older on 1 Jan. Ages are therefore approximate.

### Step 4: Measures Exploration (`04_measures_exploration.sql`)

Techniques: `SUM`, `AVG`, `COUNT`, `UNION ALL`.

| Metric | Logic | Source |
|---|---|---|
| Total sales | `SUM(sales_amount)` | `fact_sales` |
| Total quantity | `SUM(quantity)` | `fact_sales` |
| Average price | `AVG(price)` | `fact_sales` |
| Total orders | `COUNT(DISTINCT order_number)` | `fact_sales` |
| Total products | `COUNT(product_key)` | `dim_products` |
| Total customers | `COUNT(customer_key)` | `dim_customers` |
| Customers who ordered | `COUNT(DISTINCT customer_key)` | `fact_sales` |

The script ends with a single **key metrics report** that stacks six of these metrics (all except "customers who ordered") as `measure_name` / `measure_value` rows using `UNION ALL`.

### Step 5: Magnitude Analysis (`05_magnitude_analysis.sql`)

Techniques: `SUM`, `COUNT`, `AVG`, `GROUP BY`, `ORDER BY ... DESC`, `LEFT JOIN`.

| Question | Measure | Grouped by | Joins |
|---|---|---|---|
| Total customers by country | `COUNT(customer_key)` | `country` | none |
| Total customers by gender | `COUNT(customer_key)` | `gender` | none |
| Total products by category | `COUNT(product_key)` | `category` | none |
| Average cost per category | `AVG(cost)` | `category` | none |
| Total revenue per category | `SUM(sales_amount)` | `category` | `fact_sales` to `dim_products` |
| Total revenue per customer | `SUM(sales_amount)` | customer | `fact_sales` to `dim_customers` |
| Items sold per country | `SUM(quantity)` | `country` | `fact_sales` to `dim_customers` |

### Step 6: Ranking Analysis (`06_ranking_analysis.sql`)

Techniques: `TOP N`, `ROW_NUMBER()`, `RANK()`.

| Question | Approach |
|---|---|
| Top 5 products by revenue | `TOP 5 ... ORDER BY total_revenue DESC` |
| Top 5 products by revenue (flexible) | Subquery with `ROW_NUMBER() OVER (ORDER BY SUM(sales_amount) DESC)`, filtered to `<= 5` |
| 5 worst products by revenue | `TOP 5 ... ORDER BY total_revenue ASC` |
| Top 10 customers by revenue | `TOP 10 ... ORDER BY total_revenue DESC` |
| 3 customers with the fewest orders | `TOP 3 ... ORDER BY total_orders ASC` |
| Customers with the fewest orders (flexible) | Subquery with `RANK() OVER (ORDER BY COUNT(DISTINCT order_number))`, filtered to `rank = 1` |

When to use which: `TOP N` is simplest. The window version is more flexible. `RANK() ... = 1` returns **all** customers tied for the fewest orders, while `TOP 3` returns exactly three rows and picks arbitrarily among ties.

## 4. Data Quality Observations to Verify

Because the Gold layer uses `LEFT JOIN`s, check the following when reading the results:

| Check | Why it matters |
|---|---|
| `fact_sales` rows with NULL `customer_key` or `product_key` | They group under a NULL name in revenue-by-customer and revenue-by-product results |
| Sales of discontinued products | `dim_products` keeps active products only, so these sales have a NULL `product_key` |
| NULL `country` or `birth_date` in `dim_customers` | Customers without ERP records have no location or birth date; this affects the country and age queries |
| NULL `order_date` | Invalid source dates become NULL in Silver; they are ignored by `MIN`/`MAX` |
| Customers with no orders | They appear in `dim_customers` counts but never in revenue-by-customer results (those start from `fact_sales`) |

## 5. Findings

> Fill in from your own query output. The scripts produce the numbers; they are not stored in the repository.

| Area | Finding | Value |
|---|---|---|
| Time span | First order date, last order date, range in months | |
| Customer ages | Youngest and oldest customer age | |
| Key metrics | Total sales, quantity, average price, orders, products, customers | |
| Active customers | Customers who placed an order, out of all customers | |
| Geography | Country with the most customers; country with the most items sold | |
| Categories | Category with the most products; with the highest revenue; with the highest average cost | |
| Top performers | Top 5 products and top 10 customers by revenue | |
| Low performers | 5 worst products; customers with the fewest orders | |
