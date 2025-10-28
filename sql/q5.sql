WITH m AS (
  SELECT
    date_trunc(
      'month',
      CAST( try(date_parse(regexp_replace("date",'[/-]','-'), '%m-%d-%y')) AS DATE )
    ) AS month,
    SUM(CAST( try(regexp_replace(CAST(amount AS VARCHAR),'[^0-9.-]','')) AS DOUBLE )) AS sales
  FROM itcs6190_db.awsassignmentl11
  GROUP BY 1
),
g AS (
  SELECT
    month,
    sales,
    LAG(sales) OVER (ORDER BY month) AS prev_sales
  FROM m
)
SELECT
  month,
  sales,
  ROUND((sales - prev_sales) / NULLIF(prev_sales, 0), 4) AS sales_growth
FROM g
ORDER BY month
LIMIT 10;