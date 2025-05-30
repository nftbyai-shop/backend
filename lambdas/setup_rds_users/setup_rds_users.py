import os

import boto3
from sqlalchemy import Engine, create_engine, text


def lambda_handler(event, context):
    DB_USER = os.environ["DB_USER"]
    DB_HOST = os.environ["DB_HOST"]
    DB_NAME = os.environ["DB_NAME"]
    PATH_TO_DB_PASSWORD_IN_SECRETS_MANAGER: str = os.environ[
        "DB_PASS_ARN"
    ]
    secrets_client = boto3.client("secretsmanager", config=boto3.session.Config(
        connect_timeout=3,  # seconds
        read_timeout=5,
        retries = { "max_attempts": 2 }
    ))
    DB_PASS = secrets_client.get_secret_value(
        SecretId=PATH_TO_DB_PASSWORD_IN_SECRETS_MANAGER
    )["SecretString"]

    MIGRATION_USERNAME = os.environ["MIGRATION_USERNAME"]
    APPLICATION_USERNAME = os.environ["APPLICATION_USERNAME"]

    engine: Engine = create_engine(
        f"postgresql+psycopg://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}" + "?connect_timeout=5"  
    )

    with engine.begin() as conn:
        conn.execute(text(f"CREATE ROLE {MIGRATION_USERNAME} WITH LOGIN"))
        conn.execute(text(f"GRANT rds_iam TO {MIGRATION_USERNAME}"))
        conn.execute(
            text(f"GRANT CONNECT ON DATABASE {DB_NAME} TO {MIGRATION_USERNAME}")
        )
        conn.execute(
            text(f"GRANT USAGE, CREATE ON SCHEMA public TO {MIGRATION_USERNAME}")
        )

        conn.execute(text(f"CREATE ROLE {APPLICATION_USERNAME} WITH LOGIN"))
        conn.execute(text(f"GRANT rds_iam TO {APPLICATION_USERNAME}"))
        conn.execute(
            text(f"GRANT CONNECT ON DATABASE {DB_NAME} TO {APPLICATION_USERNAME}")
        )
        conn.execute(
            text(
                f"GRANT SELECT, INSERT, UPDATE  ON ALL TABLES IN SCHEMA public TO {APPLICATION_USERNAME}; "
            )
        )
