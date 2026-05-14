-- Supprimer les colonnes parasites de décembre
ALTER TABLE `customeranalysis-496118.customeranalysis.sales202512`
DROP COLUMN string_field_5,
DROP COLUMN string_field_6,
DROP COLUMN string_field_7;


-- Step 1: Append all monthly sales tables together
CREATE OR REPLACE TABLE `customeranalysis-496118.customeranalysis.sales_2025` AS
SELECT * FROM `customeranalysis-496118.customeranalysis.sales202501`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202502`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202503`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202504`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202505`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202506`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202507`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202508`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202509`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202510`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202511`
UNION ALL SELECT * FROM `customeranalysis-496118.customeranalysis.sales202512`;


-- Step 2: Calculate recency, frequency, monetary, r, f, m ranks
CREATE OR REPLACE VIEW `customeranalysis-496118.customeranalysis.customeranalysis_metrics`
AS
WITH current_date AS (
  SELECT DATE('2026-05-05') AS analysis_date
),
customeranalysis AS (
  SELECT
    CustomerID,
    MAX(OrderDate) AS last_order_date,
    DATE_DIFF((SELECT analysis_date FROM current_date), MAX(OrderDate), DAY) AS recency,
    COUNT(*) AS frequency,
    SUM(OrderValue) AS monetary
  FROM `customeranalysis-496118.customeranalysis.sales_2025`
  GROUP BY CustomerID
)
SELECT
  customeranalysis.*,
  ROW_NUMBER() OVER (ORDER BY recency ASC) AS r_rank,
  ROW_NUMBER() OVER (ORDER BY frequency DESC) AS f_rank,
  ROW_NUMBER() OVER (ORDER BY monetary DESC) AS m_rank
FROM customeranalysis;


-- Step 3: Assign deciles (10=best, 1=worst)
CREATE OR REPLACE VIEW `customeranalysis-496118.customeranalysis.customer_scores`
AS
SELECT
  *,
  NTILE(10) OVER (ORDER BY r_rank DESC) AS r_score,
  NTILE(10) OVER (ORDER BY f_rank DESC) AS f_score,
  NTILE(10) OVER (ORDER BY m_rank DESC) AS m_score
FROM `customeranalysis-496118.customeranalysis.customeranalysis_metrics`;


-- Step 4: Total score
CREATE OR REPLACE VIEW `customeranalysis-496118.customeranalysis.customer_total_scores`
AS
SELECT
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  (r_score + f_score + m_score) AS customer_total_score
FROM `customeranalysis-496118.customeranalysis.customer_scores`
ORDER BY customer_total_score DESC;


-- Step 5: BI ready customer segments table
CREATE OR REPLACE TABLE `customeranalysis-496118.customeranalysis.customer_segments_final`
AS
SELECT
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  customer_total_score,
  CASE
    WHEN customer_total_score >= 28 THEN 'Champion'
    WHEN customer_total_score >= 24 THEN 'Loyal VIPs'
    WHEN customer_total_score >= 20 THEN 'Potential Loyalists'
    WHEN customer_total_score >= 16 THEN 'Promising'
    WHEN customer_total_score >= 12 THEN 'Engaged'
    WHEN customer_total_score >= 8 THEN 'Requires Attention'
    WHEN customer_total_score >= 4 THEN 'At risk'
    ELSE 'Lost/inactive'
  END AS customer_segment
FROM `customeranalysis-496118.customeranalysis.customer_total_scores`
ORDER BY customer_total_score DESC;