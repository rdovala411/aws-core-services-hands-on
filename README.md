# ITCS 6190 / 8190 — AWS Core Services Hands-On (S3 + Glue + CloudWatch + Athena)

This repo contains my end-to-end workflow to ingest a transactional CSV into **S3**, catalog it with **Glue**, (optionally verify logs in **CloudWatch**), and analyze it using **Athena**. It includes the **five required queries** (each with `LIMIT 10`) and the **CSV outputs**, plus a troubleshooting section.

---

## 📌 Project Settings (fill in if you fork)
- **AWS Region:** `us-east-1`  
- **S3 Bucket:** `awsassignmentl11`  
- **Raw data prefix:** `s3://awsassignmentl11/raw/amazon/`  
- **Athena result prefix:** `s3://awsassignmentl11/athena-results/`  
- **Glue Database:** `itcs6190_db`  
- **Final Table Used:** `itcs6190_db.awsassignmentl11`  
  > If you used the manual fallback table, change this to `itcs6190_db.amazon_csv_manual`.

---

## 📂 Repository Structure


```text
aws-core-services-hands-on/
├─ screenshots/
│  ├─ S3.PNG
│  ├─ LOGS.PNG
│  ├─ IAM.PNG
├─ sql/
│  ├─ q1.sql
│  ├─ q2.sql
│  ├─ q3.sql
│  ├─ q4.sql
│  └─ q5.sql
├─ results/
│  ├─ q1.csv
│  ├─ q2.csv
│  ├─ q3.csv
│  ├─ q4.csv
│  └─ q5.csv
└─ README.md
```
---

## 🧭 Overview

**Goal:** Analyze an Amazon sales CSV with SQL in Athena using a minimal, reproducible cloud stack.

**Pipeline:**

Local CSV → S3 (`raw/amazon/`) → Glue Crawler → Glue Data Catalog (table) → Athena queries → CSV results

---

## ✅ Prerequisites

- You have a local file named **Amazon Sale Report.csv** (order-level transactions).
- You can access the AWS Console (S3, Glue, IAM, Athena) or use the AWS CLI.

---

## 1) S3: Upload the Data

**Console path:** S3 → Buckets → **awsassignmentl11**

Create folders and upload:
- `raw/amazon/` → upload **Amazon Sale Report.csv**

> Final object should be at: `s3://awsassignmentl11/raw/amazon/Amazon Sale Report.csv`  
> (Spaces are fine; optional rename to `Amazon-Sale-Report.csv`.)

**CLI alternative**
```bash
aws s3 cp "Amazon Sale Report.csv" s3://awsassignmentl11/raw/amazon/Amazon-Sale-Report.csv --region us-east-1
aws s3 cp /dev/null s3://awsassignmentl11/athena-results/.keep --region us-east-1
```


## 2) IAM: Role for Glue (one-time)

Create role `AWSGlueServiceRole-ITCS6190` (trusted entity: Glue) and attach managed policy AWSGlueServiceRole.
Add this inline policy (scopes Glue to this bucket and enables logs):

```bash
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Effect":"Allow",
      "Action":["s3:ListBucket","s3:GetObject"],
      "Resource":[
        "arn:aws:s3:::awsassignmentl11",
        "arn:aws:s3:::awsassignmentl11/*"
      ]
    },
    {
      "Effect":"Allow",
      "Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      "Resource":"*"
    }
  ]
}
```
## 3) Glue: Database & Crawler

Create database

Glue → Data Catalog → Databases → Add → name: itcs6190_db.

Create crawler

Glue → Crawlers → Create crawler

Name: `itcs6190_raw_amazon`

Data source: S3 path = `s3://awsassignmentl11/raw/amazon/`

IAM role: `AWSGlueServiceRole-ITCS6190`

Target database: `itcs6190_db`

Create → Run crawler → wait for Succeeded

4) Athena: Configure & Verify

Settings

Athena → Settings → set Query result location to
`s3://awsassignmentl11/athena-results/` → Save

Query editor

Data source: `AwsDataCatalog`

Database: `itcs6190_db`

Verify table and rows (replace <table> if needed):
```bash
SHOW TABLES IN itcs6190_db;

SHOW CREATE TABLE itcs6190_db.awsassignmentl11;

-- Should list S3 paths under your raw prefix:
SELECT "$path"
FROM itcs6190_db.awsassignmentl11
LIMIT 10;

-- Expect > 0 once LOCATION is correct and file exists:
SELECT COUNT(*)
FROM itcs6190_db.awsassignmentl11;

-- If COUNT(*) = 0, point the table to the right folder:
ALTER TABLE itcs6190_db.awsassignmentl11
SET LOCATION 's3://awsassignmentl11/raw/amazon/';
```

## Q1 — Cumulative daily sales
```bash
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
```

## Q2 — Problem orders & negative amounts by state
```bash
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
```
##  Q3 — Fulfilment impact (avg order amount + problem rate)
```bash
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
```
## Q4 — Top-3 SKUs by revenue within each category
```bash
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
```
## Q5 — Monthly sales & MoM growth
```bash
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
```

## RESULTS

All tghe reults are stored in the `\results` in the repo as the csv files.

---RUTHWIK DOVALA (801431661)
