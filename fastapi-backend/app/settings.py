from dotenv import load_dotenv
from pydantic_settings import BaseSettings

load_dotenv()


class _Settings(BaseSettings):
    auth0_domain: str
    auth0_api_audience: str
    auth0_issuer: str
    auth0_algorithms: str
    ALLOW_ORIGINS_URLS: list[str]
    DB_USER: str
    DB_PASS: str | None = None
    DB_HOST: str
    DB_PORT: int
    DB_NAME: str
    NFT_IMAGE_STORAGE_URL: str
    REGION: str
    REQUIRE_SSL: bool = True
    STRIPE_SECRET_KEY: str = ""


Settings = _Settings

# TODO implement getting strip secret key from ssm


def get_settings() -> Settings:
    return _settings


_settings = _Settings()
