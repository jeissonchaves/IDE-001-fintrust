-- Granularidad: una fila por pago confirmado.
-- applied_to_overdue = TRUE cuando el pago se aplicó a una cuota en mora (status LATE o PARTIAL)
-- sirve para calcular el % de recaudo que cubrió cartera vencida.

CREATE OR REPLACE TABLE `{project_id}.dm_fintrust.fact_payments` AS
SELECT
    p.payment_id,
    p.loan_id,
    p.installment_id,
    l.customer_id,
    p.payment_date,
    p.payment_amount,
    p.payment_channel,
    p.payment_status,
    i.installment_status,
    CASE
        WHEN i.installment_status IN ('LATE', 'PARTIAL') THEN TRUE
        ELSE FALSE
    END AS applied_to_overdue
FROM `{project_id}.stg_fintrust.stg_payments` p
LEFT JOIN `{project_id}.stg_fintrust.stg_loans` l
    ON p.loan_id = l.loan_id
LEFT JOIN `{project_id}.stg_fintrust.stg_installments` i
    ON p.installment_id = i.installment_id;
