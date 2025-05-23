from pprint import pprint
from typing import Any

import uvicorn
from fastapi import FastAPI, HTTPException, Request, Security
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
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
def test(request: Request):
    # Print all request details
    print("----- REQUEST INFO -----")
    pprint(f"Method: {request.method}")
    pprint(f"URL: {request.url}")
    pprint(f"Headers: {dict(request.headers)}")
    pprint(f"Query Params: {dict(request.query_params)}")
    print("-------------------------")
    return {"mega": "success"}


@app.get("/api/private")
def private(access_allowed: str = Security(verify_token)) -> dict[Any, Any]:
    if access_allowed:
        return {"access": "allowed"}
    else:
        raise HTTPException(403, "Unauthoriseed")


if __name__ == "__main__":
    uvicorn.run(app=app, port=5000, log_level="debug")
