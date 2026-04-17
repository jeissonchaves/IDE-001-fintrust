CREATE OR REPLACE TABLE `{project_id}.dm_fintrust.dim_customer` AS
SELECT
    customer_id,
    full_name,
    city,
    segment,
    monthly_income
FROM `{project_id}.stg_fintrust.stg_customers`;
