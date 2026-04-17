-- Procesa la tabla de cuotas programadas.
-- Reglas aplicadas:
--   Excluir cuotas con installment_number >= 99.
--   Calcular total_due = principal_due + interest_due.
--   Marcar is_overdue = TRUE si:
--        a. installment_status = 'LATE', o
--        b. installment_status IN ('DUE', 'PARTIAL') y marcadas como DUE o PARTIAL pero la fehca de vencimiento ya paso
--   Calcular days_overdue = días desde due_date hasta hoy.

CREATE OR REPLACE TABLE `{project_id}.stg_fintrust.stg_installments` AS
SELECT
    installment_id,
    loan_id,
    installment_number,
    due_date,
    principal_due,
    interest_due,
    (principal_due + interest_due) AS total_due,
    installment_status,
    CASE
        WHEN UPPER(TRIM(installment_status)) = 'LATE'
            THEN TRUE
        WHEN UPPER(TRIM(installment_status)) IN ('DUE', 'PARTIAL')
             AND due_date < CURRENT_DATE()
            THEN TRUE
        ELSE FALSE
    END AS is_overdue,
    CASE
        WHEN UPPER(TRIM(installment_status)) = 'PARTIAL'
            THEN TRUE
        ELSE FALSE
    END AS is_partial,
    CASE
        WHEN UPPER(TRIM(installment_status)) IN ('LATE', 'DUE', 'PARTIAL')
             AND due_date < CURRENT_DATE()
            THEN DATE_DIFF(CURRENT_DATE(), due_date, DAY)
        ELSE 0
    END AS days_overdue,
    CURRENT_TIMESTAMP() AS loaded_at
FROM `{project_id}.raw_fintrust.installments`
INNER JOIN `{project_id}.raw_fintrust.loans` l
    ON i.loan_id = l.loan_id
    AND i.installment_number <= l.term_months
WHERE i.installment_id IS NOT NULL;