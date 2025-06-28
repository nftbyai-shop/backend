from typing import Annotated, Any, Optional

import jwt
from fastapi import Depends
from fastapi.exceptions import HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer, SecurityScopes

from app.settings import get_settings


class _TokenVerifier:
    def __init__(self) -> None:
        self.config = get_settings()
        jwks_url: str = f"{self.config.auth0_domain}/.well-known/jwks.json"
        self.jwks_client = jwt.PyJWKClient(jwks_url)

    # TODO: get_signing_key_from_jwt is an event loop blocking call
    # later we need to adjust it for async.
    async def verify(
        self,
        token: Optional[HTTPAuthorizationCredentials],
        security_scopes: SecurityScopes,
    ) -> dict[str, Any]:
        if token is None:
            raise HTTPException(401, detail="Token is missing")
        try:
            signing_key = self.jwks_client.get_signing_key_from_jwt(
                token.credentials
            ).key
            payload = jwt.decode(
                token.credentials,
                signing_key,
                algorithms=self.config.auth0_algorithms,
                audience=self.config.auth0_api_audience,
                issuer=self.config.auth0_issuer,
            )
        except Exception as e:
            raise HTTPException(403, )
        return payload


_token_verifier = _TokenVerifier()

http_bearer = HTTPBearer()


async def verify_token(
    token: Annotated[Optional[HTTPAuthorizationCredentials], Depends(http_bearer)],
    security_scopes: SecurityScopes,
):
    payload: dict[str, Any] = await _token_verifier.verify(
        token=token, security_scopes=security_scopes
    )
    if payload:
        return payload
    else:
        return HTTPException(401)
