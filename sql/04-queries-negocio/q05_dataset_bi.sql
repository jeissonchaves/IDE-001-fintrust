-- Una fila por cuota con toda la información dimensional desnormalizada.
-- Ejecutada por pipeline.py como paso final del pipeline.

CREATE OR REPLACE VIEW `{project_id}.dm_fintrust.vw_bi_cartera` AS
SELECT
    -- Identificadores
    fc.installment_id,
    fc.loan_id,
    fc.customer_id,

    -- Dimensión cliente
    dc.full_name          AS cliente,
    dc.city               AS ciudad,
    dc.segment            AS segmento,
    dc.monthly_income     AS ingreso_mensual,

    -- Dimensión crédito
    dl.product_type       AS tipo_producto,
    dl.loan_status        AS estado_credito,
    dl.origination_date   AS fecha_desembolso,
    dl.principal_amount   AS monto_desembolsado,
    dl.annual_rate        AS tasa_anual,
    dl.term_months        AS plazo_meses,
    dl.cohort_month       AS cohorte_mes,
    dl.cohort_quarter     AS cohorte_trimestre,

    -- Cuota
    fc.installment_number AS numero_cuota,
    fc.due_date           AS fecha_vencimiento,
    fc.principal_due      AS capital_cuota,
    fc.interest_due       AS interes_cuota,
    fc.total_due          AS valor_cuota,

    -- Saldos y estado
    fc.amount_paid        AS monto_pagado,
    fc.outstanding_balance AS saldo_pendiente,
    fc.installment_status AS estado_cuota,
    fc.is_overdue         AS en_mora,
    fc.is_partial         AS pago_parcial,
    fc.days_overdue       AS dias_mora,

    -- Fecha de corte para partición en BI
    CURRENT_DATE()        AS fecha_corte
FROM `{project_id}.dm_fintrust.fact_cartera` fc
JOIN `{project_id}.dm_fintrust.dim_customer` dc ON fc.customer_id = dc.customer_id
JOIN `{project_id}.dm_fintrust.dim_loan`     dl ON fc.loan_id     = dl.loan_id;
