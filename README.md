# ITCS 6190 / 8190 — AWS Core Services Hands-On (S3 + Glue + CloudWatch + Athena)

This repo contains my end-to-end workflow to ingest a transactional CSV into **S3**, catalog it with **Glue**, verify logs in **CloudWatch**, and analyze it using **Athena**. It includes the **five required queries** (each with `LIMIT 10`) and the **CSV outputs**, plus screenshots and a troubleshooting section.

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

aws-core-services-hands-on/
├─ sql/
│ ├─ q1.sql
│ ├─ q2.sql
│ ├─ q3.sql
│ ├─ q4.sql
│ └─ q5.sql
├─ results/
│ ├─ q1.csv
│ ├─ q2.csv
│ ├─ q3.csv
│ ├─ q4.csv
│ └─ q5.csv
├─ screenshots/
│ ├─ cloudwatch_crawler.png
│ ├─ iam_role.png
│ └─ s3_buckets.png
└─ README.md



---

## 🧭 Overview

**Goal:** Analyze an Amazon sales CSV with SQL in Athena using a minimal, reproducible cloud stack.

**Pipeline:**

Local CSV → S3 (raw/amazon/) → Glue Crawler → Glue Data Catalog (table) → Athena queries → CSV results
↘ CloudWatch Logs (evidence)


---

## ✅ Prerequisites

- You have a local file named **Amazon Sale Report.csv** (order-level transactions).
- You can access the AWS Console (S3, Glue, IAM, CloudWatch, Athena).

---

## 1) S3: Upload the Data

**Console path:** S3 → Buckets → **awsassignmentl11**

Create folders and upload:
- `raw/amazon/` → upload **Amazon Sale Report.csv**

> Final object should be at: `s3://awsassignmentl11/raw/amazon/Amazon Sale Report.csv`  
> (Spaces are fine; optional rename to `Amazon-Sale-Report.csv`.)

---

## 2) IAM: Role for Glue (one-time)

Create role **`AWSGlueServiceRole-ITCS6190`** (trusted entity: Glue) and attach managed policy **AWSGlueServiceRole**.  
Add this **inline policy** (scopes Glue to this bucket and enables logs):

```json
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
