import logging
from typing import Any

import stripe
import uvicorn
from fastapi import FastAPI, HTTPException, Security
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address
from sqlalchemy import ScalarResult, select
from sqlalchemy.ext.asyncio.session import AsyncSession, async_sessionmaker
from stripe.checkout._session import Session
from urllib3 import HTTPResponse

from app.db_connection import get_async_sessionmaker
from app.models import Nft
from app.schemas import NftModel
from app.settings import get_settings
from app.stripe_webhook import webhook_app
from app.verify_token import verify_token

settings = get_settings()

logger = logging.getLogger()

stripe.api_key = settings.STRIPE_SECRET_KEY

app = FastAPI()

app.mount("/webhooks/stripe/", webhook_app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().ALLOW_ORIGINS_URLS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


limiter = Limiter(key_func=get_remote_address, default_limits=["2/second"])
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)


# TODO add rate limiting everywhere
@app.get("/api/nfts")   
async def get_nfts():
    session_maker: async_sessionmaker[AsyncSession] = get_async_sessionmaker()
    pydantic_nfts: list[NftModel] = []
    async with session_maker() as session:
        nfts: ScalarResult[Nft] = await session.scalars(select(Nft))
        for nft in nfts:
            data = nft.__dict__.copy()
            data["image_url"] = (
                get_settings().NFT_IMAGE_STORAGE_URL + "/" + data["s3_object_name"]
            )
            pydantic_nfts.append(NftModel.model_validate(data, from_attributes=False))
    return pydantic_nfts

class CheckoutParams(BaseModel):
    user_email: EmailStr
    item_id: int

@app.post("/api/create-checkout-session")
async def create_checkout_session(
    checkout_params: CheckoutParams,
    payload: bool = Security(verify_token),
) -> dict[str, str]:
    session_maker: async_sessionmaker[AsyncSession] = get_async_sessionmaker()
    async with session_maker() as session:
        results: ScalarResult[Nft] = await session.scalars(
            select(Nft).where(Nft.id == checkout_params.item_id)
        )
        nft: Nft | None = results.first()
        if not nft:
            logger.error("Couldn't find NFT with id: %s", checkout_params.item_id)
            raise HTTPException(status_code=500, detail="Internal server error")
        if not nft.available_for_sale or nft.owner != get_settings().DEFAULT_NFT_OWNER:
            raise HTTPException(status_code=400, detail="Bad request")

        price = stripe.Price.search(query=f'lookup_key:"price_{nft.s3_object_name}"')
        data: Any = price.get("data", [])
        if not data:
            logger.error(
                "Couldn't find stripe price for nft with id: %s",
                checkout_params.item_id,
            )
            raise HTTPException(status_code=500, detail="Internal server error")
        price_id = data[0]["id"]
    settings = get_settings()
    checkout_session: Session = stripe.checkout.Session.create(
        line_items=[
            {"price": price_id, "quantity": 1},
        ],
        mode="payment",
        success_url=settings.SUCCESSFULL_PURCHASE_URL,
        cancel_url=settings.FAILED_PURCHASE_URL,
        automatic_tax={"enabled": True},
        customer_email=checkout_params.user_email,
        payment_method_types=["card"],
    )
    if not checkout_session.url:
        raise HTTPException(status_code=500, detail="Failed to create checkout session")
    return {"checkout_url": checkout_session.url}


@app.get("/api/health")
async def health_check():
    return HTTPResponse(status=200, reason="OK")


@app.get("/api/private")
def private(access_allowed: str = Security(verify_token)) -> dict[Any, Any]:
    if access_allowed:
        return {"access": "allowed"}
    else:
        raise HTTPException(403, "Unauthoriseed")


if __name__ == "__main__":
    uvicorn.run(app=app, port=8000, log_level="debug")
