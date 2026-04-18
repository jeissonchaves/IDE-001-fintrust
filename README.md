# IDE-001-fintrust

## Descripción general

Proyecto de ingeniería de datos para el caso FinTrust: construcción de un pipeline ETL, data mart analítico y consultas de negocio sobre una cartera de crédito.

## Contexto del negocio

FinTrust es una fintech de crédito de consumo. El objetivo es transformar datos crudos de operaciones de crédito en información analítica que permita responder preguntas clave sobre desembolsos, recaudos, cartera y comportamiento de cohortes.

## Estructura del proyecto

```
├── data/
│   ├── customers.csv
│   ├── loans.csv
│   ├── installments.csv
│   └── payments.csv
│
├── sql/
│   ├── 01-raw/                  # DDL: creación de tablas fuente en BigQuery
│   ├── 02-staging/              # Limpieza y estandarización
│   ├── 03-analytics/            # Modelo estrella
│   └── 04-queries-negocio/      # Consultas que responden las 5 preguntas de negocio
│
├── python/
│   ├── pipeline.py              # Orquestador del pipeline ETL
│   ├── validations.py           # Checks de calidad de datos
│   └── requirements.txt
│
├── docs/
│   ├── decisiones-tecnicas.md   # Supuestos, reglas y decisiones de diseño
│   └── evidencia-calidad-datos.md  # Registro de problemas encontrados
│
└── .env.example                 # Plantilla de variables de entorno
```

---

## Arquitectura

```
GCS (CSVs)
    │
    ▼
raw_fintrust          ← tablas fuente tal cual llegan
    │
    ▼
stg_fintrust          ← limpieza, estandarización, flags de calidad
    │
    ▼
dm_fintrust           ← modelo estrella para consumo analítico
    │
    ▼
vw_bi_cartera         ← vista lista para Power BI / Tableau / Looker
```

## Setup y ejecución

### 1. Prerequisitos

- Proyecto GCP con BigQuery y GCS habilitados
- Variables de entorno configuradas (ver `.env.example`)
- `gcloud` CLI instalado y autenticado:
  ```bash
  gcloud auth application-default login
  gcloud auth application-default set-quota-project TU_PROJECT_ID
  ```
- Python 3.10+

### 2. Configuración

```bash
cp .env.example .env
# Editar .env con las variables GCP_PROJECT_ID y GCS_BUCKET
```

### 3. Instalar dependencias

```bash
pip install -r python/requirements.txt
```

### 4. Subir CSVs a GCS

Asegurar que los archivos CSv existen en GCS. 

### 5. Ejecutar el pipeline

```bash
cd python
python pipeline.py
```

## Tablas fuente

| Tabla | Descripción |
|---|---|
| `customers` | 35 clientes |
| `loans` | 45 créditos |
| `installments` | 135 cuotas programadas |
| `payments` | 107 pagos recibidos |
## Decisiones clave

Ver [`docs/decisiones-tecnicas.md`](docs/decisiones-tecnicas.md) para supuestos de diseño, decisiones arquitectónicas y riesgos conocidos.

## Calidad de datos

Ver [`docs/evidencia-calidad-datos.md`](docs/evidencia-calidad-datos.md) para validaciones aplicadas y resultados observados.