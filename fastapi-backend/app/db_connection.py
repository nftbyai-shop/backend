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
    auth_token = rds.generate_db_auth_token(
        settings.DB_HOST, settings.DB_PORT, settings.DB_USER
    )
    db_pass = urllib.parse.quote_plus(auth_token)

_engine: AsyncEngine = create_async_engine(
    f"postgresql+asyncpg://{settings.DB_USER}:{settings.DB_PASS}@{settings.DB_HOST}/{settings.DB_NAME}",
    echo=True,
)
_async_sessionmaker: async_sessionmaker[AsyncSession] = async_sessionmaker(
    _engine, expire_on_commit=False
)


def get_async_sessionmaker() -> async_sessionmaker[AsyncSession]:
    return _async_sessionmaker
