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
- Se utiliza un esquema estrella con tabla de hechos fact_cartera y fact_payments y dimensiones de tiempo, cliente y credito.

### Motor de base de datos
BigQuery (GCP). Se ejecutan las transformacion en Bigquery por su capacidad de computo, se usa python para schedule y automatizacion del pipeline.

### Idempotencia del pipeline

Staging y analytics usan `CREATE OR REPLACE TABLE / VIEW`. El pipeline puede ejecutarse múltiples veces sin efectos secundarios — cada ejecución produce el mismo resultado.

## Riesgos conocidos
- Valores nulos en payments, esto significa pagos sin canal, se normaliza a `'UNKNOWN'` pero indica un problema en el sistema de captura del canal de pago.
- Duplicados en tabla de pagos
- outstanding_balance estático: se calcula en el momento de la ejecución del pipeline. No refleja cambios en tiempo real. 

## Decisiones pendientes

### Carga incremental para `payments`
- **Estado:** Pendiente de implementación
- **Contexto:** La tabla `payments` es la única con una columna de control de carga (`loaded_at`) que permite identificar registros nuevos sin reprocesar toda la tabla.
- **Propuesta:** Migrar la carga de `WRITE_TRUNCATE` a incremental usando `loaded_at`. Primera carga full_refresh, siguientes cargas lee el MAX(loaded_at) as max_loaded y una funsion load_payments_incremental carga con loaded_at >max_loaded.

### Manejo de errores y monitoreo del pipeline
- **Estado:** Pendiente de implementación
- **Contexto:** El pipeline actual no distingue entre errores críticos y advertencias; cualquier fallo detiene la ejecución sin dejar registro ni notificar al equipo.

- **Propuesta:**

  **Severidad en validaciones**
  Agregar campo severity al dataclass Check en `validations.py` (`CRITICAL`, `HIGH`, `MEDIUM`). Los checks CRITICAL bloquean el pipeline,los demás solo emiten advertencia y el pipeline continúa. 

  **Tabla de auditoría en BigQuery**
  Crear tabla `raw_fintrust.pipeline_runs` con una fila por ejecución. Nos permite construir un dashboard para monitoreo del pipeline. .

- **Alertas:** Slack webhook como mecanismo de notificacion, cuando el pipeline termina en estado FAILED con resumen del error. Si se despliega a produccion en GCP se configura con GCP Cloud Monitoring.