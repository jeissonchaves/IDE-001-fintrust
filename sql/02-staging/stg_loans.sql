-- Limpia y estandariza la tabla de créditos.
-- Reglas aplicadas:
--  TRIM en todos los campos de texto
--  Excluir créditos sin loan_id o customer_id.
--  Excluir créditos con principal_amount <= 0.
--  Agregar cohort_month y cohort_quarter para análisis de cohortes.

CREATE OR REPLACE TABLE `{project_id}.stg_fintrust.stg_loans` AS
SELECT
    loan_id,
    customer_id,
    origination_date,
    principal_amount,
    annual_rate,
    term_months,
    TRIM(loan_status) AS loan_status,
    TRIM(product_type) AS product_type,
    FORMAT_DATE('%Y-%m', origination_date) AS cohort_month,
    CONCAT(CAST(EXTRACT(YEAR    FROM origination_date) AS STRING),'-Q',CAST(EXTRACT(QUARTER FROM origination_date) AS STRING)) AS cohort_quarter,
    CURRENT_TIMESTAMP() AS _loaded_at
FROM `{project_id}.raw_fintrust.loans`
WHERE loan_id IS NOT NULL
  AND customer_id IS NOT NULL
  AND principal_amount > 0;
