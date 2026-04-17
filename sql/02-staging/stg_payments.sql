-- Limpia y estandariza la tabla de pagos recibidos.
-- Reglas aplicadas:
--   Excluir pagos ene stado diferente a CONFIRMED, se excluyen los pagos PENDING y REVERSED.
--   Excluir pagos con payment_amount = 0. 
--   Normalizar payment_channel NULL → 'UNKNOWN'.
--   Excluir pagos cuyo installment_id no existe en la tabla raw
--   Excluir pagos sobre cuotas anómalas installment_number por ejemplo  99
--   Excluir pagos donde el installment no pertenece al loan declarado

CREATE OR REPLACE TABLE `{project_id}.stg_fintrust.stg_payments` AS
SELECT
    p.payment_id,
    p.loan_id,
    p.installment_id,
    p.payment_date,
    p.payment_amount,
    COALESCE(NULLIF(UPPER(TRIM(p.payment_channel)), ''), 'UNKNOWN') AS payment_channel,
    p.payment_status,
    p.loaded_at,
    CURRENT_TIMESTAMP() AS _loaded_at
FROM `{project_id}.raw_fintrust.payments` p
INNER JOIN `{project_id}.raw_fintrust.installments` i ON  p.installment_id = i.installment_id AND p.loan_id = i.loan_id
WHERE p.payment_status = 'CONFIRMED'
  AND p.payment_amount  > 0
  AND installment_number < 99;
