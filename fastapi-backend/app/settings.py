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
    REQUIRE_SSL: bool = True
    DEFAULT_NFT_OWNER: str
    NFT_IMAGE_STORAGE_URL: str
    FRONTEND_URL: str
    SUCCESSFULL_PURCHASE_URL: str
    FAILED_PURCHASE_URL: str
    STRIPE_SECRET_KEY: str = ""
    CROSSMINT_SECRET_KEY: str = ""
    REGION: str
    LOG_LEVEL: str = "DEBUG"
    NFTBYAI_WALLET_ADDRESS: str
    SMTP_HOST: str
    SMTP_PORT: str
    SMTP_USER: str
    SMTP_PASS: str
    REPORT_TO_EMAIL: str


Settings = _Settings


def get_settings() -> Settings:
    return _settings


_settings = _Settings()


if not _settings.CROSSMINT_SECRET_KEY:
    pass
    # TODO implement this
if not _settings.STRIPE_SECRET_KEY:
    pass
if not _settings.SMTP_PASS:
    pass
