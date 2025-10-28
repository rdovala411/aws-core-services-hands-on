WITH parsed AS (
  SELECT
    CAST( try(date_parse(regexp_replace("date",'[/-]','-'), '%m-%d-%y')) AS DATE ) AS order_dt,
    CAST( try(regexp_replace(CAST(amount AS VARCHAR),'[^0-9.-]','')) AS DOUBLE ) AS amount_clean
  FROM itcs6190_db.awsassignmentl11
),
daily AS (
  SELECT order_dt, SUM(amount_clean) AS daily_sales
  FROM parsed
  WHERE order_dt IS NOT NULL AND amount_clean IS NOT NULL
  GROUP BY order_dt
)
SELECT
  order_dt,
  daily_sales,
  SUM(daily_sales) OVER (ORDER BY order_dt
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM daily
ORDER BY order_dt
LIMIT 10;