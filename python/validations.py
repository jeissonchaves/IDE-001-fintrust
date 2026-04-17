"""
validations.py
Checks de calidad de datos post-carga de tablas raw_fintrust.

Ejecutar de forma independiente:
    python validations.py

O importar desde pipeline.py:
    from validations import run_checks
    passed = run_checks(bq_client)
"""

import os
from dataclasses import dataclass

from dotenv import load_dotenv
from loguru import logger
from google.cloud import bigquery

load_dotenv()

PROJECT_ID = os.environ["GCP_PROJECT_ID"]

# ---------------------------------------------------------------------------
# Definición de checks
# ---------------------------------------------------------------------------

@dataclass
class Check:
    name: str
    query: str
    expect_zero: bool = True


def build_checks(project_id):
    return [
        # Table Customers
        Check(
            name="customers sin customer_id",
            query=f"SELECT COUNT(*) FROM `{project_id}.raw_fintrust.customers` WHERE customer_id IS NULL",
        ),
        Check(
            name="customers sin full_name",
            query=f"SELECT COUNT(*) FROM `{project_id}.raw_fintrust.customers` WHERE full_name IS NULL",
        ),
        Check(
            name="customers duplicados (mismo customer_id)",
            query=f"""
                SELECT COUNT(*) FROM (
                    SELECT customer_id FROM `{project_id}.raw_fintrust.customers`
                    GROUP BY customer_id HAVING COUNT(*) > 1
                )
            """,
        ),

        # Table Loans
        Check(
            name="Loan sin loan_id",
            query=f"SELECT COUNT(*) FROM `{project_id}.raw_fintrust.loans` WHERE loan_id IS NULL",
        ),         
        Check(
            name="Loan sin customer_id",
            query=f"SELECT COUNT(*) FROM `{project_id}.raw_fintrust.loans` WHERE customer_id IS NULL",
        ), 
        Check(
            name="loans con principal_amount <= 0",
            query=f"SELECT COUNT(*) FROM `{project_id}.raw_fintrust.loans` WHERE principal_amount <= 0",
        ),

        # Table installments 
        Check(
            name="installments con installment_number anómalo (>= 99)",
            query=f"""
                SELECT COUNT(*) FROM `{project_id}.raw_fintrust.installments`
                WHERE installment_number >= 99
            """,
        ),
        #  Table Payments 
        Check(
            name="payments different to CONFIRMED",
            query=f"""
                SELECT COUNT(*) FROM `{project_id}.raw_fintrust.payments`
                WHERE payment_status NOT IN ('CONFIRMED')
            """,
        ),
        Check(
            name="payments con payment_amount <= 0",
            query=f"""
                SELECT COUNT(*) FROM `{project_id}.raw_fintrust.payments`
                WHERE payment_amount <= 0
            """,
        ),
        Check(
            name="payments con payment_channel NULL",
            query=f"""
                SELECT COUNT(*) FROM `{project_id}.raw_fintrust.payments`
                WHERE payment_channel IS NULL
            """,
        ),         
        Check(
            name="payments con installment_id que no existe en installments",
            query=f"""
                SELECT COUNT(*) FROM `{project_id}.raw_fintrust.payments` p
                WHERE NOT EXISTS (
                    SELECT 1 FROM `{project_id}.raw_fintrust.installments` i
                    WHERE i.installment_id = p.installment_id
                )
            """,
        ),
        Check(
            name="payments con mismatch loan_id / installment_id",
            query=f"""
                SELECT COUNT(*) FROM `{project_id}.raw_fintrust.payments` p
                INNER JOIN `{project_id}.raw_fintrust.installments` i
                    ON p.installment_id = i.installment_id
                WHERE p.loan_id != i.loan_id
            """,
        ),
    ]

def run_checks(client):
    """
    Ejecuta todos los checks de calidad.
    Retorna True si todos pasan, False si hay alguna advertencia.
    """
    checks = build_checks(PROJECT_ID)
    all_passed = True

    for check in checks:
        job = client.query(check.query)
        rows = list(job.result())
        count = rows[0][0]

        if check.expect_zero and count > 0:
            logger.warning(f"  [ADVERTENCIA] {check.name}: {count:,} registro(s) afectado(s)")
            all_passed = False
        else:
            logger.info(f"  [OK] {check.name}")
    return all_passed