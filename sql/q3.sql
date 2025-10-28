WITH t AS (
  SELECT
    fulfilment,
    lower(status) AS status_lc,
    CAST( try(regexp_replace(CAST(amount AS VARCHAR),'[^0-9.-]','')) AS DOUBLE ) AS amount_clean
  FROM itcs6190_db.awsassignmentl11
)
SELECT
  fulfilment,
  ROUND(AVG(amount_clean), 2) AS avg_amount,
  SUM(CASE WHEN status_lc LIKE '%cancel%' OR status_lc LIKE '%return%' THEN 1 ELSE 0 END) AS problem_orders
FROM t
GROUP BY fulfilment
ORDER BY avg_amount DESC
LIMIT 10;