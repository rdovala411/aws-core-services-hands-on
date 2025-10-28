WITH t AS (
  SELECT
    ship_state AS state_key,
    lower(status) AS status_lc,
    CAST( try(regexp_replace(CAST(amount AS VARCHAR),'[^0-9.-]','')) AS DOUBLE ) AS amount_clean
  FROM itcs6190_db.awsassignmentl11
)
SELECT
  state_key AS ship_state,
  SUM(CASE WHEN status_lc LIKE '%cancel%' OR status_lc LIKE '%return%' THEN 1 ELSE 0 END) AS problem_orders,
  ROUND(SUM(CASE WHEN amount_clean < 0 THEN amount_clean ELSE 0 END), 2) AS total_negative_amount
FROM t
GROUP BY state_key
ORDER BY problem_orders DESC, total_negative_amount ASC
LIMIT 10;