-- DDL para tablas fuente en el dataset raw_fintrust
-- Nota: Se modifica el script para caregar en bigquery

CREATE TABLE IF NOT EXISTS `{project_id}.raw_fintrust.customers` (
    customer_id    STRING,
    full_name      STRING,
    city           STRING,
    segment        STRING,
    monthly_income NUMERIC,
    created_at     DATE
);

CREATE TABLE IF NOT EXISTS `{project_id}.raw_fintrust.loans` (
    loan_id          STRING,
    customer_id      STRING,
    origination_date DATE,
    principal_amount NUMERIC,
    annual_rate      NUMERIC,
    term_months      INT64,
    loan_status      STRING,
    product_type     STRING
);

CREATE TABLE IF NOT EXISTS `{project_id}.raw_fintrust.installments` (
    installment_id     STRING,
    loan_id            STRING,
    installment_number INT64,
    due_date           DATE,
    principal_due      NUMERIC,
    interest_due       NUMERIC,
    installment_status STRING
);

CREATE TABLE IF NOT EXISTS `{project_id}.raw_fintrust.payments` (
    payment_id      STRING,
    loan_id         STRING,
    installment_id  STRING,
    payment_date    DATE,
    payment_amount  NUMERIC,
    payment_channel STRING,
    payment_status  STRING,
    loaded_at       TIMESTAMP
);
