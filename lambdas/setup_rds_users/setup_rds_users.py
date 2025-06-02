import os
import urllib3
import boto3
import logging
import json
from sqlalchemy import Engine, create_engine, text


def lambda_handler(event, context):
    resp = urllib3.request("GET", "http://google.com", timeout = 5)
    DB_USER = os.environ["DB_USER"]
    DB_HOST = os.environ["DB_HOST"]
    DB_NAME = os.environ["DB_NAME"]
    DB_PASS_ARN: str = os.environ[
        "DB_PASS_ARN"
    ]
    secrets_client = boto3.client("secretsmanager", config=boto3.session.Config(
        connect_timeout=3,  # seconds
        read_timeout=5,
        retries = { "max_attempts": 2 }
    ))
    DB_CREDS = secrets_client.get_secret_value(
        SecretId=DB_PASS_ARN
    )["SecretString"]
    DB_PASS = json.loads(DB_CREDS)["password"]
    
    APPLICATION_USERNAME = "application_user"

    engine: Engine = create_engine(
        f"postgresql+pg8000://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}"  
    )

    with engine.begin() as conn:
        if event.get("create_users", False):
            conn.execute(text(f"CREATE ROLE {APPLICATION_USERNAME} WITH LOGIN"))
        conn.execute(text(f"GRANT rds_iam TO {APPLICATION_USERNAME}"))
        conn.execute(
            text(f"GRANT CONNECT ON DATABASE {DB_NAME} TO {APPLICATION_USERNAME}")
        )
        conn.execute(
            text(
                f"ALTER DEFAULT PRIVILEGES FOR ROLE {DB_USER} IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO {APPLICATION_USERNAME};"
            )
        )
