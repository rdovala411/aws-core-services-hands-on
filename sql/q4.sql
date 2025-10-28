WITH agg AS (
  SELECT
    category,
    sku,
    SUM(CAST( try(regexp_replace(CAST(amount AS VARCHAR),'[^0-9.-]','')) AS DOUBLE )) AS revenue
  FROM itcs6190_db.awsassignmentl11
  GROUP BY category, sku
),
ranked AS (
  SELECT
    category, sku, revenue,
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) AS rn
  FROM agg
)
SELECT
  category,
  sku,
  ROUND(revenue, 2) AS revenue
FROM ranked
WHERE rn <= 3
ORDER BY category, revenue DESC
LIMIT 10;