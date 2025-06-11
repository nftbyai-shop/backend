import urllib.parse

import boto3
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.settings import Settings, get_settings

settings: Settings = get_settings()

rds = boto3.client("rds", region_name=settings.REGION)

if not settings.DB_PASS:
    print("No DB_PASS provided, generating auth token for RDS database connection.")
    auth_token = rds.generate_db_auth_token(
        settings.DB_HOST, settings.DB_PORT, settings.DB_USER
    )
    db_pass = urllib.parse.quote_plus(auth_token)
else:
    print("Using provided DB_PASS for RDS database connection.")
    db_pass = settings.DB_PASS

_engine: AsyncEngine = create_async_engine(
    f"postgresql+asyncpg://{settings.DB_USER}:{db_pass}@{settings.DB_HOST}/{settings.DB_NAME}",
    echo=True,
    connect_args={"ssl": settings.REQUIRE_SSL},
    # {('?sslmode=require' if settings.REQUIRE_SSL else '')}
)

_async_sessionmaker: async_sessionmaker[AsyncSession] = async_sessionmaker(
    _engine, expire_on_commit=False
)


def get_async_sessionmaker() -> async_sessionmaker[AsyncSession]:
    return _async_sessionmaker
