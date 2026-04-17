CREATE OR REPLACE TABLE `{project_id}.dm_fintrust.dim_date` AS
WITH dates AS (
    SELECT d AS full_date
    FROM UNNEST(GENERATE_DATE_ARRAY('2025-01-01', '2027-12-31')) AS d
)
SELECT
    CAST(FORMAT_DATE('%Y%m%d', full_date) AS INT64) AS date_id,
    full_date,
    EXTRACT(YEAR    FROM full_date)                 AS year,
    EXTRACT(MONTH   FROM full_date)                 AS month,
    EXTRACT(QUARTER FROM full_date)                 AS quarter,
    EXTRACT(DAY     FROM full_date)                 AS day,
    EXTRACT(DAYOFWEEK FROM full_date)               AS day_of_week,
    FORMAT_DATE('%A',    full_date)                 AS day_name,
    FORMAT_DATE('%B',    full_date)                 AS month_name,
    FORMAT_DATE('%Y-%m', full_date)                 AS month_year
FROM dates;
