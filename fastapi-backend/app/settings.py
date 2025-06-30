import logging

import boto3
from dotenv import load_dotenv
from pydantic_settings import BaseSettings

logger = logging.getLogger()
load_dotenv()


class _Settings(BaseSettings):
    auth0_custom_domain: str
    auth0_default_domain: str
    auth0_api_audience: str
    auth0_issuer: str
    auth0_algorithms: str
    environment: str
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
    CROSSMINT_API_KEY_SSM_PATH: str = ""
    STRIPE_SECRET_KEY_SSM_PATH: str = ""
    STRIPE_WEBHOOK_SIGNING_SECRET: str = ""
    STRIPE_WEBHOOK_SIGNING_SECRET_SSM_PATH: str = ""
    REGION: str
    LOG_LEVEL: str = "DEBUG"
    NFTBYAI_WALLET_ADDRESS: str
    SMTP_HOST: str
    SMTP_PORT: str
    SMTP_USER: str
    SMTP_PASS: str = ""
    SMTP_PASS_SSM_PATH: str = ""
    SMTP_NFTBYAI_HOST: str = "smtp.zohocloud.ca"
    SMTP_NFTBYAI_PORT: str = "465"
    SMTP_NFTBYAI_USER: str = "support@nftbyai.shop"
    SMTP_NFTBYAI_PASS: str = ""
    SMTP_NFTBYAI_PASS_SSM_PATH: str = ""

    REPORT_TO_EMAIL: str


Settings = _Settings


_settings = _Settings()


def get_settings() -> Settings:
    return _settings


logger = logging.getLogger()
logger.setLevel(_settings.LOG_LEVEL)

ssm = boto3.client(
    "ssm",
    config=boto3.session.Config(
        connect_timeout=10, read_timeout=10, retries={"max_attempts": 4}
    ),
    region_name=_settings.REGION,
)

if not _settings.CROSSMINT_SECRET_KEY:
    logger.debug("CROSSMINT_API_KEY_SSM_PATH: ", _settings.CROSSMINT_API_KEY_SSM_PATH)
    CROSSMINT_API_KEY: str = ssm.get_parameter(
        Name=_settings.CROSSMINT_API_KEY_SSM_PATH, WithDecryption=True
    )["Parameter"]["Value"]
    _settings.CROSSMINT_SECRET_KEY = CROSSMINT_API_KEY

if not _settings.STRIPE_SECRET_KEY:
    STRIPE_API_KEY: str = ssm.get_parameter(
        Name=_settings.STRIPE_SECRET_KEY_SSM_PATH, WithDecryption=True
    )["Parameter"]["Value"]
    _settings.STRIPE_SECRET_KEY = STRIPE_API_KEY

if not _settings.SMTP_PASS:
    smtp_pass: str = ssm.get_parameter(
        Name=_settings.SMTP_PASS_SSM_PATH, WithDecryption=True
    )["Parameter"]["Value"]
    _settings.SMTP_PASS = smtp_pass

if not _settings.SMTP_NFTBYAI_PASS:
    smtp_pass_nftbyai: str = ssm.get_parameter(
        Name=_settings.SMTP_NFTBYAI_PASS_SSM_PATH, WithDecryption=True
    )["Parameter"]["Value"]
    _settings.SMTP_NFTBYAI_PASS = smtp_pass_nftbyai

if not _settings.STRIPE_WEBHOOK_SIGNING_SECRET:
    stripe_webhook_signing_secret: str = ssm.get_parameter(
        Name=_settings.STRIPE_WEBHOOK_SIGNING_SECRET_SSM_PATH, WithDecryption=True
    )["Parameter"]["Value"]
    _settings.STRIPE_WEBHOOK_SIGNING_SECRET = stripe_webhook_signing_secret
