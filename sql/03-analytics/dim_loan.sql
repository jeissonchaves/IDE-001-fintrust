CREATE OR REPLACE TABLE `{project_id}.dm_fintrust.dim_loan` AS
SELECT
    l.loan_id,
    l.customer_id,
    l.product_type,
    l.loan_status,
    l.origination_date,
    l.principal_amount,
    l.annual_rate,
    l.term_months,
    l.cohort_month,
    l.cohort_quarter,
    c.city    AS customer_city,
    c.segment AS customer_segment
FROM `{project_id}.stg_fintrust.stg_loans` l
LEFT JOIN `{project_id}.stg_fintrust.stg_customers` c
    ON l.customer_id = c.customer_id;
