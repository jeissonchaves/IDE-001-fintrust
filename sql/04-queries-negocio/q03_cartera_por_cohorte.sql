SELECT
    fc.cohort_month,
    fc.cohort_quarter,
    dl.customer_segment AS segmento,
    dl.product_type AS tipo_producto,
    COUNT(DISTINCT fc.loan_id) AS creditos,
    SUM(fc.total_due) AS cartera_total_cuotas,
    SUM(fc.outstanding_balance) AS saldo_total,
    SUM(CASE WHEN NOT fc.is_overdue THEN fc.outstanding_balance ELSE 0 END) AS saldo_al_dia,
    SUM(CASE WHEN fc.is_overdue     THEN fc.outstanding_balance ELSE 0 END) AS saldo_en_mora,
    SAFE_DIVIDE(
        SUM(CASE WHEN fc.is_overdue THEN fc.outstanding_balance ELSE 0 END),
        NULLIF(SUM(fc.outstanding_balance), 0)
    ) AS pct_mora
FROM `{project_id}.dm_fintrust.fact_cartera` fc
JOIN `{project_id}.dm_fintrust.dim_loan` dl ON fc.loan_id = dl.loan_id
WHERE fc.outstanding_balance > 0
GROUP BY 1, 2, 3, 4;
