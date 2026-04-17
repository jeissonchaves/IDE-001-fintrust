-- Limpia y estandariza la tabla de clientes.
-- Reglas aplicadas:
--  TRIM en todos los campos de texto.
--  Excluir filas sin customer_id o full_name (datos críticos).

CREATE OR REPLACE TABLE `{project_id}.stg_fintrust.stg_customers` AS
SELECT
    customer_id,
    TRIM(full_name)                AS full_name,
    city,
    TRIM(segment)                  AS segment,
    monthly_income,
    created_at,
    CURRENT_TIMESTAMP()            AS _loaded_at
FROM `{project_id}.raw_fintrust.customers`
WHERE customer_id IS NOT NULL
  AND full_name   IS NOT NULL
;