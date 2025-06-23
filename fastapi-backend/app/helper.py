from typing import Any, Literal

import httpx
from tenacity import (
    retry,
    stop_after_attempt,
    wait_random_exponential,
)


@retry(
    wait=wait_random_exponential(
        max=60,
    ),
    stop=stop_after_attempt(6),
    reraise=True,
)
async def async_fetch_with_retry(
    method: Literal["POST", "GET"], url: str, **kwargs: Any
) -> httpx.Response:
    kwargs.setdefault("timeout", 10)
    async with httpx.AsyncClient() as client:
        response = await client.request(method, url, **kwargs)
    return response
