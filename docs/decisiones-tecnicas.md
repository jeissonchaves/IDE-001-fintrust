# Decisiones Técnicas

## Supuestos

- Los datos fuente se reciben en archivos CSV planos con encoding UTF-8 alojados en GCS.
- Las fechas siguen el formato `YYYY-MM-DD` en todas las tablas fuente.
- Un crédito puede tener múltiples cuotas; cada cuota es una fila independiente en la tabla de pagos.
- El campo `installment_status` del sistema fuente no siempre se actualiza automáticamente de `DUE` a `LATE` cuando vence. En el ETL se corrige esto comparando `due_date` con `CURRENT_DATE()`.
- Solo se consideran pagos con `payment_status = 'CONFIRMED'` para cálculos de recaudo y saldo.
- El plazo máximo de un crédito en el portafolio actual es 24 meses. Cualquier cuota con `installment_number > term_months` del crédito se considera anómala.
- La fecha de corte para todos los cálculos de mora es `CURRENT_DATE()` de BigQuery en el momento de ejecución del pipeline.

## Decisiones de diseño

### Arquitectura de capas
| Capa | Dataset BigQuery | Propósito |
|---|---|---|
| Raw | `raw_fintrust`|datos crudos, reflejo exacto de la fuente |
| Staging | `stg_fintrust` | Limpieza, estandarización y validación |
| Analytics | `dm_fintrust` | Modelo estrella optimizado para BI |

### Modelado dimensional
- Se utiliza un esquema estrella con tabla de hechos `fact_cartera y fact_payments` y dimensiones de tiempo, cliente y credito.

### Motor de base de datos
BigQuery (GCP). Se ejecutan las transformacion en Bigquery por su capacidad de computo, se usa python para schedule y automatizacion del pipeline.

### Idempotencia del pipeline

Staging y analytics usan `CREATE OR REPLACE TABLE / VIEW`. El pipeline puede ejecutarse múltiples veces sin efectos secundarios — cada ejecución produce el mismo resultado.

## Riesgos conocidos
- Valores nulos en payments, esto significa pagos sin canal, se normaliza a `'UNKNOWN'` pero indica un problema en el sistema de captura del canal de pago.
- Duplicados en tabla de pagos
- outstanding_balance estático: se calcula en el momento de la ejecución del pipeline. No refleja cambios en tiempo real. 