SELECT
    fc.loan_id,
    dc.full_name                                AS cliente,
    dl.customer_city                            AS ciudad,
    dl.customer_segment                         AS segmento,
    dl.product_type                             AS tipo_producto,
    dl.origination_date                         AS fecha_desembolso,
    dl.principal_amount                         AS monto_original,
    COUNT(*)                                    AS cuotas_en_mora,
    MAX(fc.days_overdue)                        AS max_dias_atraso,
    SUM(fc.outstanding_balance)                 AS saldo_pendiente_total
FROM `{project_id}.dm_fintrust.fact_cartera` fc
JOIN `{project_id}.dm_fintrust.dim_customer` dc ON fc.customer_id = dc.customer_id
JOIN `{project_id}.dm_fintrust.dim_loan`     dl ON fc.loan_id     = dl.loan_id
WHERE fc.is_overdue = TRUE
GROUP BY 1, 2, 3, 4, 5, 6, 7
ORDER BY max_dias_atraso DESC, saldo_pendiente_total DESC
LIMIT 10;
