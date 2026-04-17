SELECT
    dl.origination_date                  AS fecha_desembolso,
    dl.customer_city                     AS ciudad,
    dl.customer_segment                  AS segmento,
    SUM(dl.principal_amount)             AS monto_desembolsado
FROM `{project_id}.dm_fintrust.dim_loan` dl
GROUP BY 1, 2, 3;