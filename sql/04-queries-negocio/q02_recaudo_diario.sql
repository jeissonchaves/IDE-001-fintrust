SELECT
    fp.payment_date AS fecha_pago,
    COUNT(DISTINCT fp.payment_id) AS num_pagos,
    SUM(fp.payment_amount) AS recaudo_total,
    SUM(CASE WHEN fp.applied_to_overdue THEN fp.payment_amount ELSE 0 END)    AS recaudo_en_mora,
    SAFE_DIVIDE(
        SUM(CASE WHEN fp.applied_to_overdue THEN fp.payment_amount ELSE 0 END),
        SUM(fp.payment_amount)
    ) AS pct_recaudo_mora
FROM `{project_id}.dm_fintrust.fact_payments` fp
GROUP BY 1
ORDER BY fecha_pago DESC;
