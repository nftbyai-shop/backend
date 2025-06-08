from dotenv import load_dotenv
from pydantic_settings import BaseSettings

from produce_nft.produce_nft import DB_PORT

load_dotenv()


class _Settings(BaseSettings):
    auth0_domain: str
    auth0_api_audience: str
    auth0_issuer: str
    auth0_algorithms: str
    client_url: str
    DB_USER: str
    DB_PASS: str | None = None
    DB_HOST: str
    DB_PORT: int
    DB_NAME: str
    NFT_IMAGE_STORAGE_URL: str
    REGION: str


Settings = _Settings


def get_settings() -> Settings:
    return _settings


_settings = _Settings()
