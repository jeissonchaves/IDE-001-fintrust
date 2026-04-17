# Evidencia de Calidad de Datos — Fintrust
## 1. Resumen Ejecutivo

El análisis del sample de datos de Fintrust reveló hallazgos de calidad de datos, los más críticos comprometen la integridad referencial del modelo (préstamos cuya fecha de originación es anterior a la creación del cliente), la integridad transaccional (pagos apuntando a cuotas de créditos diferentes) y la confiabilidad del registro de pagos (pagos con monto cero confirmados, estados PENDING con casi un año de antigüedad). Adicionalmente, se identificaron patrones de riesgo de negocio que podrían indicar fallas en las políticas de originación de crédito.


## 2. Hallazgos Críticos

### [C-01] Préstamos originados antes de la creación del cliente
**Tabla afectada:** `loans` ✕ `customers`
**Tipo:** Inconsistencia Lógica + Riesgo de Integridad Referencial
**Registros afectados:** 2

Un préstamo no puede existir antes de que el cliente esté registrado en el sistema. Dos créditos tienen `origination_date` previo al `created_at` del cliente, lo que imposible en el flujo normal de negocio y podría indicar carga retroactiva de datos sin validación o registros de clientes cargados de forma tardía.

| loan_id | customer_id | origination_date | customer_created_at | Diferencia |
|---------|-------------|-----------------|---------------------|------------|
| L035 | C002 (Luis Perez) | 2024-07-10 | 2024-12-02 | **−145 días** |
| L036 | C004 (Carlos Diaz) | 2024-09-01 | 2025-01-03 | **−124 días** |

```sql
-- Validación: Préstamos originados antes del registro del cliente
SELECT
  l.loan_id,
  l.customer_id,
  l.origination_date,
  c.created_at AS customer_created_at,
  DATE_DIFF(l.origination_date, c.created_at, DAY) AS days_diff
FROM `raw_fintrust.loans` l
JOIN `raw_fintrust.customers` c USING (customer_id)
WHERE l.origination_date < c.created_at
ORDER BY days_diff;
```

---

### [C-02] Cuota con número imposible (fantasma)
**Tabla afectada:** `installments`
**Tipo:** Anomalía Transaccional
**Registros afectados:** 1

La cuota `I135` pertenece al crédito `L003` que tiene `term_months = 10`, pero tiene `installment_number = 99`. Ningún crédito del portafolio puede tener más de 24 cuotas según las reglas de negocio documentadas. Adicionalmente, su `due_date` (2025-01-20) es idéntica al `origination_date` del préstamo, lo cual es físicamente imposible.

| installment_id | loan_id | installment_number | due_date | term_months del préstamo |
|---------------|---------|-------------------|----------|--------------------------|
| I135 | L003 | **99** | 2025-01-20 (= origination_date) | 10 |

```sql
-- Validación: Cuotas con número mayor al plazo del crédito
SELECT
  i.installment_id,
  i.loan_id,
  i.installment_number,
  i.due_date,
  l.term_months,
  l.origination_date
FROM `raw_fintrust.installments` i
JOIN `raw_fintrust.loans` l USING (loan_id)
WHERE i.installment_number > l.term_months
   OR i.due_date <= l.origination_date
ORDER BY i.loan_id, i.installment_number;
```

---

### [C-03] Pago referenciando installment_id inexistente
**Tabla afectada:** `payments` ✕ `installments`
**Tipo:** Riesgo de Integridad Referencial
**Registros afectados:** 1

El pago `P101` referencia `I999`, un `installment_id` que no existe en la tabla `installments`. Este registro huérfano representa un pago de 1,450,000 COP que no puede ser reconciliado con ninguna cuota del portafolio.

| payment_id | loan_id | installment_id | payment_amount | Estado |
|-----------|---------|---------------|---------------|--------|
| P101 | L010 | **I999** (no existe) | 1,450,000 | CONFIRMED |

```sql
-- Validación: Pagos con installment_id que no existe en installments
SELECT
  p.payment_id,
  p.loan_id,
  p.installment_id,
  p.payment_amount,
  p.payment_status
FROM `raw_fintrust.payments` p
WHERE NOT EXISTS (
  SELECT 1 FROM `raw_fintrust.installments` i
  WHERE i.installment_id = p.installment_id
);
```

---

### [C-04] Pagos apuntando a cuotas de otro crédito (cross-loan mismatch)
**Tabla afectada:** `payments` ✕ `installments`
**Tipo:** Riesgo de Integridad Referencial + Anomalía Transaccional
**Registros afectados:** 5

Cinco pagos tienen un `loan_id` en la tabla `payments` que no coincide con el `loan_id` de la cuota referenciada en `installments`. Esto genera inconsistencias graves en el cálculo de saldos, recaudo por crédito y reportes regulatorios.

| payment_id | loan_id en payments | installment_id | loan_id real en installments | Notas adicionales |
|-----------|--------------------|-----------------|-----------------------------|-------------------|
| P102 | L013 | I040 | **L012** | Canal de pago NULL |
| P103 | L015 | I050 | **L013** | Status REVERSED, monto > cuota |
| P104 | L014 | I046 | **L013** | — |
| P105 | L028 | I130 | **L043** | Status PENDING, ~1 año de antigüedad |
| P106 | L021 | I081 | **L020** | Monto = 0 COP |

```sql
-- Validación: Mismatch entre loan_id del pago y loan_id de la cuota
SELECT
  p.payment_id,
  p.loan_id           AS payment_loan_id,
  p.installment_id,
  i.loan_id           AS installment_loan_id,
  p.payment_amount,
  p.payment_status,
  p.payment_channel
FROM `raw_fintrust.payments` p
JOIN `raw_fintrust.installments` i USING (installment_id)
WHERE p.loan_id != i.loan_id;
```

---

### [C-05] Pago confirmado con monto cero
**Tabla afectada:** `payments`
**Tipo:** Anomalía Transaccional + Riesgo de Negocio
**Registros afectados:** 1

El pago `P106` tiene `payment_amount = 0` y `payment_status = CONFIRMED`. Un pago de cero pesos no debería existir en el registro de pagos confirmados. Combinado con el hallazgo C-04, también apunta a una cuota del crédito equivocado.

| payment_id | loan_id | installment_id | payment_amount | payment_status |
|-----------|---------|---------------|---------------|---------------|
| P106 | L021 | I081 (es de L020) | **0** | **CONFIRMED** |

```sql
-- Validación: Pagos confirmados con monto <= 0
SELECT
  payment_id,
  loan_id,
  installment_id,
  payment_date,
  payment_amount,
  payment_status
FROM `raw_fintrust.payments`
WHERE payment_amount <= 0
  AND payment_status = 'CONFIRMED';
```

### [A-04] Canal de pago nulo en pago confirmado
**Tabla afectada:** `payments`
**Tipo:** Anomalía de Datos — Calidad de captura
**Registros afectados:** 1

El pago `P102` tiene `payment_channel = NULL` y `payment_status = CONFIRMED`. Según las decisiones técnicas del proyecto, esto se normaliza a `'UNKNOWN'`, pero evidencia un problema en el sistema de captura del canal de pago. Nótese que este pago también incurre en el hallazgo C-04 (cross-loan mismatch).

```sql
-- Validación: Pagos confirmados sin canal de pago
SELECT
  payment_id,
  loan_id,
  installment_id,
  payment_date,
  payment_amount,
  payment_status,
  payment_channel
FROM `raw_fintrust.payments`
WHERE payment_channel IS NULL
  AND payment_status = 'CONFIRMED';
```


## 3. Recomendaciones de Arquitectura de Calidad de Datos

1. **Agregar validaciones en la capa Staging (`stg_fintrust`):** Las reglas C-01 a C-05 deben implementarse como CTEs de validación que bloqueen el pipeline si el conteo de violaciones supera 0.

2. **Separar pagos no-CONFIRMED en tablas de cuarentena:** Los registros con `payment_status IN ('PENDING', 'REVERSED')` deben cargarse en una tabla aparte (`raw_fintrust.payments_quarantine`) para análisis independiente.

3. **Implementar Foreign Key constraints lógicas en BigQuery:** Aunque BigQuery no enforza FKs, agregarlas como documentación (`INFORMATION_SCHEMA` + checks automatizados) establece el contrato de datos esperado.

4 **Alerta de DTI en originación:** Agregar una vista `raw_fintrust.v_customer_dti` que calcule la carga mensual estimada por cliente y emita alertas cuando supere el 40%.

5. **Auditoría de préstamos CLOSED:** Implementar una validación que verifique que todos los créditos en estado `CLOSED` tengan `SUM(i.principal_due) ≈ l.principal_amount` o que exista un registro de cancelación/prepago documentado.
