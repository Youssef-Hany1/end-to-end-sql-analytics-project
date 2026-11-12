# Advanced Business Analytics

## 1. Objective

Turn the Gold layer into business insight: how performance changes over time, how it accumulates, how it compares with benchmarks, which parts drive the total, and how customers and products can be segmented. The phase ends with two reusable report views: `gold.report_customers` and `gold.report_products`.

| Step | Script | Analysis |
|---|---|---|
| 7 | `07_change_over_time_analysis.sql` | Trends and seasonality |
| 8 | `08_cumulative_analysis.sql` | Running totals and moving averages |
| 9 | `09_performance_analysis.sql` | Year-over-year and versus-average comparison |
| 10 | `10_part_to_whole_analysis.sql` | Category share of total sales |
| 11 | `11_data_segmentation.sql` | Product cost ranges and customer segments |
| 12 | `12_report_customers.sql` | Customer report view |
| 13 | `13_report_products.sql` | Product report view |

(The numbering continues from the EDA scripts `01` to `06`.)

## 2. Data Source

The Gold star schema: `gold.fact_sales`, `gold.dim_customers`, `gold.dim_products` (see `gold_data_catalog.md`). Every time-based query filters `order_date IS NOT NULL`, because invalid source dates become NULL in the Silver layer.

## 3. Analyses

### 3.1 Change Over Time (`07_change_over_time_analysis.sql`)

Tracks sales, distinct customers, and quantity by period. The same query is written three ways to compare date functions.

| Approach | Grouping expression | Result | Caveat |
|---|---|---|---|
| `DATEPART` | `DATEPART(year, ...)`, `DATEPART(month, ...)` | Two numeric columns (year, month) | Two columns to manage |
| `DATETRUNC` | `DATETRUNC(month, order_date)` | One proper date column | Requires SQL Server 2022 or later |
| `FORMAT` | `FORMAT(order_date, 'yyyy-MMM')` | Readable label such as `2013-Dec` | Returns text, so `ORDER BY` sorts alphabetically (Apr, Aug, Dec...) and not in time order |

```sql
SELECT
    DATETRUNC(month, order_date) AS order_date,
    SUM(sales_amount)            AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity)                AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);
```

Best choice for analysis: `DATETRUNC` (correct sorting and a real date). Use `FORMAT` for display only.

### 3.2 Cumulative Analysis (`08_cumulative_analysis.sql`)

| Query | Aggregation level | Window logic |
|---|---|---|
| Monthly running total | Month | `SUM(total_sales) OVER (PARTITION BY YEAR(order_date) ORDER BY order_date)`; the total restarts every year |
| Yearly running total and moving average | Year | `SUM(total_sales) OVER (ORDER BY order_date)` and `AVG(avg_price) OVER (ORDER BY order_date)` |

Pattern: aggregate first in a subquery (`DATETRUNC` plus `SUM`/`AVG`), then apply the window function over the aggregated rows. The moving average here is a cumulative average of yearly average prices, not a fixed-size sliding window.

### 3.3 Performance Analysis (`09_performance_analysis.sql`)

Compares each product's yearly sales with (a) the product's own average yearly sales and (b) the previous year.

| Output column | Logic |
|---|---|
| `current_sales` | `SUM(sales_amount)` per product per year |
| `avg_sales` | `AVG(current_sales) OVER (PARTITION BY product_name)` |
| `diff_avg`, `diff_avg_flag` | Difference from average; `Above Avg` / `Below Avg` / `Avg` |
| `prev_year_sales` | `LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year)` |
| `diff_prev_year`, `diff_prev_year_flag` | Year-over-year change; `Increase` / `Decrease` / `No Change` |

Notes:
- The first year of each product has no previous year, so its `prev_year_sales` and difference are NULL and the flag shows `No Change`.
- The CTE also computes `AVG(sales_amount) AS avg_sales`, but the final select recomputes `avg_sales` with the window function. The CTE column is unused and can be removed.

### 3.4 Part-to-Whole Analysis (`10_part_to_whole_analysis.sql`)

Share of each product category in total sales.

```sql
WITH category_sales AS (
    SELECT p.category, SUM(s.sales_amount) AS total_sales
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_products p ON s.product_key = p.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER () AS overall_sales,
    CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100, 2), '%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;
```

`SUM() OVER ()` with an empty window gives the grand total on every row; the cast to `FLOAT` avoids integer division.

### 3.5 Data Segmentation (`11_data_segmentation.sql`)

**Product cost ranges** (count of products per range):

| Range label | Rule |
|---|---|
| `< 100` | `cost < 100` |
| `100 - 500` | `cost BETWEEN 100 AND 500` |
| `5000 - 1000` | `cost BETWEEN 500 AND 1000` |
| `> 1000` | everything else |

**Customer segments** (count of customers per segment):

| Segment | Rule |
|---|---|
| VIP | Lifespan of 12 or more months **and** total spending above 5,000 |
| Regular | Lifespan of 12 or more months **and** total spending of 5,000 or less |
| New | Lifespan under 12 months |

Lifespan is `DATEDIFF(month, first_order_date, last_order_date)`.

Issues to fix in this script:
- The third range label is misspelled: `'5000 - 1000'` should be `'500 - 1000'`.
- `BETWEEN` is inclusive, so the boundary values 500 and 1000 belong to two ranges. The first matching `WHEN` wins (500 lands in `100 - 500`, 1000 in `500 - 1000`). Use `cost < 500`-style conditions to make the boundaries explicit.
- The comment mentions euros (`€5,000`), while the data has no currency; keep the unit consistent with your dataset.

## 4. Final Reports

Both reports are views built with the same three-step CTE pattern:

1. **Base query:** join `fact_sales` to the dimension, keeping only rows with a valid `order_date`.
2. **Aggregation:** summarize per customer or per product.
3. **Final select:** add segments, recency, and KPIs.

### 4.1 Customer Report: `gold.report_customers`

| Column group | Columns |
|---|---|
| Identity | `customer_key`, `customer_number`, `customer_name` (first and last name concatenated) |
| Demographics | `customer_age`, `age_group` (`Under 20`, `20-29`, `30-39`, `40-49`, `50 and above`, `n/a` when unknown) |
| Segment | `customer_segment` (VIP / Regular / New, same rules as 3.5) |
| Activity | `last_order_date`, `recency` (months since last order, using `GETDATE()`) |
| Totals | `total_orders`, `total_sales`, `total_quantity`, `total_products`, `lifespan` (months) |
| KPIs | `average_order_value` (`total_sales / total_orders`), `average_monthly_spend` (`total_sales / lifespan`, 0 when lifespan is 0) |

### 4.2 Product Report: `gold.report_products`

| Column group | Columns |
|---|---|
| Identity | `product_key`, `product_name`, `category`, `subcategory`, `cost` |
| Segment | `product_segment`: **High-Performer** (total sales above 50,000), **Mid-Range** (10,000 to 50,000), **Low-Performer** (below 10,000) |
| Activity | `last_sale_date`, `recency` (months since last sale) |
| Totals | `total_orders`, `total_sales`, `total_customers` (unique), `total_quantity`, `lifespan` (months) |
| KPIs | `avg_selling_price` (average of `sales_amount / NULLIF(quantity, 0)`), `average_order_revenue`, `average_monthly_revenue` (0 when lifespan is 0) |

### Report notes
- `recency` is measured against today's date (`GETDATE()`), so it grows every month. If the sales data is historical, recency values will be large; use a fixed reference date (such as the last order date in the data) if you want stable numbers.
- Age uses `DATEDIFF(year, birth_date, GETDATE())`, which counts year boundaries, so it can be off by one year.
- A customer or product with only one active month has `lifespan = 0`, so its monthly average is reported as 0 rather than the actual value.
- Sales rows with no matching customer (NULL `customer_key`) form a single group with NULL identity columns in the customer report.

## 5. Insights

> Fill in from your own query output.

| Analysis | Insight | Evidence |
|---|---|---|
| Change over time | Peak and lowest months or years; seasonality | |
| Cumulative | Overall growth trend and yearly running total | |
| Performance | Products increasing or decreasing year over year | |
| Part-to-whole | Category with the largest share of sales, and its percentage | |
| Segmentation | Share of customers in VIP / Regular / New; product count per cost range | |
| Customer report | Highest-value segment and age group | |
| Product report | Number of High-Performer, Mid-Range, and Low-Performer products | |

## 6. Techniques Summary

| Category | Techniques |
|---|---|
| Aggregation | `SUM`, `AVG`, `COUNT`, `COUNT(DISTINCT ...)`, `MIN`, `MAX`, `GROUP BY` |
| Window functions | `SUM() OVER`, `AVG() OVER`, `LAG`, `ROW_NUMBER`, `RANK`, partitioned and unpartitioned windows |
| Query structure | CTEs, subqueries, `CASE WHEN`, `LEFT JOIN`, views |
| Dates | `DATETRUNC`, `DATEPART`, `FORMAT`, `YEAR`, `DATEDIFF`, `GETDATE` |
| Safe math | `NULLIF` to avoid division by zero, `CAST ... AS FLOAT` to avoid integer division |
