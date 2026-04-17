import os
from pathlib import Path

from dotenv import load_dotenv
from loguru import logger
from google.cloud import bigquery

load_dotenv()

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

SQL_PATH  = Path(__file__).parent.parent / "sql"
PROJECT_ID = os.environ["GCP_PROJECT_ID"]
GCS_BUCKET = os.environ.get("GCS_BUCKET", f"{PROJECT_ID}-fintrust-raw")
DATASETS = ["raw_fintrust", "stg_fintrust", "dm_fintrust"]

STAGING_FILES = [
    "stg_customers.sql",
    "stg_loans.sql",
    "stg_payments.sql",
    "stg_installments.sql",
]

ANALYTICS_FILES = [
    "dim_date.sql",
    "dim_customer.sql",
    "dim_loan.sql",
    "fact_cartera.sql",
    "fact_payments.sql",
]

# CSVs → (dataset BigQuery, tabla BigQuery)
CSV_TABLE_MAP = {
    "customers.csv":    ("raw_fintrust", "customers"),
    "loans.csv":        ("raw_fintrust", "loans"),
    "installments.csv": ("raw_fintrust", "installments"),
    "payments.csv":     ("raw_fintrust", "payments"),
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def read_sql(path: Path) -> str:
    """Lee un archivo .sql"""
    if not path.exists():
        raise FileNotFoundError(f"SQL no encontrado: {path}")
    return path.read_text(encoding="utf-8").replace("{project_id}", PROJECT_ID)

def run_query(bq_client, query):
    """
    Ejecuta un SQL en BigQuery.
    Maneja múltiples sentencias separadas por ';'
    """
    statements = [s.strip() for s in query.split(";") if s.strip()]
    for stmt in statements:
        job = bq_client.query(stmt)
        job.result()

def load_gcs_to_bq(
    bq_client: bigquery.Client,
    project_id,
    gcs_uri: str,
    dataset: str,
    table: str,
) -> None:
    """Carga un CSV desde GCS a BigQuery (WRITE_TRUNCATE)."""
    table_ref = f"{project_id}.{dataset}.{table}"
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        autodetect=True,
        write_disposition="WRITE_TRUNCATE",
    )
    job = bq_client.load_table_from_uri(gcs_uri, table_ref, job_config=job_config)
    job.result()
    tbl = bq_client.get_table(table_ref)
    logger.info(f"  Cargado: {table_ref} — {tbl.num_rows:,} filas")

# ---------------------------------------------------------------------------
# Pipeline principal
# ---------------------------------------------------------------------------

def run_pipeline():
    bq_client = bigquery.Client(project=PROJECT_ID)

    # 1. Crear tablas RAW (DDL)
    logger.info("PASO 1: Crea tablas RAW")
    sql = read_sql(SQL_PATH / "01-raw" / "create_raw_tables.sql")
    run_query(bq_client, sql)

    # 2. Cargar CSVs desde GCS → BigQuery
    logger.info("PASO 2: Carga CSVs desde GCS")
    for csv_name, (dataset, table) in CSV_TABLE_MAP.items():
        uri = f"gs://{GCS_BUCKET}/csv/{csv_name}"
        load_gcs_to_bq(bq_client, PROJECT_ID, uri, dataset, table)
    # 3. Validaciones de calidad
    logger.info("PASO 3: Ejecucion de validaciones de calidad")
    try:
        from validations import run_checks
        passed = run_checks(bq_client)
        if not passed:
            logger.warning("  Hay advertencias de calidad — el pipeline continúa.")
    except Exception as e:
        logger.warning(f"  Validaciones no disponibles: {e}")
        
    # 4. Ejecucion tablas en staging
    logger.info("PASO 4: Ejecucion tablas en staging")
    for file in STAGING_FILES:
        path = SQL_PATH / "02-staging" / file
        logger.info(f"  Ejecutando: {file}")
        run_query(bq_client, read_sql(path))
    # 5. Analytics (dimensiones,hechos,vistas) 
    logger.info("PASO 5: Analytics")
    for file in ANALYTICS_FILES:
        path = SQL_PATH / "03-analytics" / file
        logger.info(f"  Ejecutando: {file}")
        run_query(bq_client, read_sql(path))
    # 6. Tabla BI
    logger.info("PASO 6: Ejecucion tabla BI")
    bi_view = SQL_PATH / "04-queries-negocio" / "q05_dataset_bi.sql"
    run_query(bq_client, read_sql(bi_view))

    logger.success("Pipeline completado exitosamente.")
        
if __name__ == "__main__":  
    run_pipeline()
