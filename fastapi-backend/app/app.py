from pprint import pprint
from typing import Any

import uvicorn
from fastapi import FastAPI, HTTPException, Request, Security
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import ScalarResult, select
from sqlalchemy.ext.asyncio.session import AsyncSession, async_sessionmaker

from app.db_connection import get_async_sessionmaker
from app.models import Nft
from app.schemas import NftModel
from app.settings import get_settings
from app.verify_token import verify_token

app = FastAPI()

app.add_middleware(
    
    CORSMiddleware,
    allow_origins=get_settings().client_url,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/test")
async def test(request: Request) -> list[NftModel]:
    # Print all request details
    print("----- REQUEST INFO -----")
    pprint(f"Method: {request.method}")
    pprint(f"URL: {request.url}")
    pprint(f"Headers: {dict(request.headers)}")
    pprint(f"Query Params: {dict(request.query_params)}")
    print("-------------------------")


# TODO add rate limiting everywhere
@app.get("/api/nfts")
async def get_nfts():
    session_maker: async_sessionmaker[AsyncSession] = get_async_sessionmaker()
    pydantic_nfts: list[NftModel] = []
    async with session_maker() as session:
        nfts: ScalarResult[Nft] = await session.scalars(select(Nft))
        for nft in nfts:
            if nft.owner == "email:owner@example.com:polygon":
                data = nft.__dict__.copy()
                data["image_url"] = (
                    get_settings().NFT_IMAGE_STORAGE_URL + "/" + data["s3_object_name"]
                )
                pydantic_nfts.append(
                    NftModel.model_validate(data, from_attributes=False)
                )
    return pydantic_nfts


@app.get("/api/private")
def private(access_allowed: str = Security(verify_token)) -> dict[Any, Any]:
    if access_allowed:
        return {"access": "allowed"}
    else:
        raise HTTPException(403, "Unauthoriseed")


if __name__ == "__main__":
    uvicorn.run(app=app, port=5000, log_level="debug")
