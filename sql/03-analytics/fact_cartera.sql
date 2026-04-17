CREATE OR REPLACE TABLE `{project_id}.dm_fintrust.fact_cartera` AS
WITH payments_per_installment AS (
    SELECT
        installment_id,
        SUM(payment_amount) AS amount_paid
    FROM `{project_id}.stg_fintrust.stg_payments`
    WHERE payment_status = 'CONFIRMED'
    GROUP BY installment_id
)
SELECT
    i.installment_id,
    i.loan_id,
    l.customer_id,
    i.due_date,
    i.installment_number,
    i.principal_due,
    i.interest_due,
    i.total_due,
    COALESCE(p.amount_paid, 0) AS amount_paid,
    i.total_due - COALESCE(p.amount_paid, 0) AS outstanding_balance,
    i.installment_status,
    i.is_overdue,
    i.is_partial,
    i.days_overdue,
    l.cohort_month,
    l.cohort_quarter
FROM `{project_id}.stg_fintrust.stg_installments` i
LEFT JOIN `{project_id}.stg_fintrust.stg_loans` l
    ON i.loan_id = l.loan_id
LEFT JOIN payments_per_installment p
    ON i.installment_id = p.installment_id;
