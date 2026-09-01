"""
API Gateway - request forwarding.

"A single entry point for all client requests. Routes requests to the
appropriate service." That's the whole job: look at the incoming path,
decide which of the three services owns it, forward the request there
(method, headers, query string, body included), and hand the response
straight back. The client never needs to know there are three services
behind this one URL.
"""
import re

import httpx
from fastapi import Request, Response, HTTPException

from .config import ROUTES

# Internal-only paths: real services expose them for service-to-service
# calls, but the public Gateway must never forward to them directly.
# (See recommendation-service's POST /destinations/{id}/visit.)
BLOCKED_PATTERNS = [
    re.compile(r"^/destinations/[^/]+/visit$"),
]

HOP_BY_HOP_HEADERS = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailers", "transfer-encoding", "upgrade", "host", "content-length",
}


def resolve_target(path: str) -> str:
    for prefix, base_url in ROUTES:
        if path == prefix or path.startswith(prefix + "/"):
            return base_url
    raise HTTPException(status_code=404, detail=f"No service registered for {path}")


async def forward(request: Request, path: str) -> Response:
    full_path = "/" + path
    method = request.method

    for pattern in BLOCKED_PATTERNS:
        if pattern.match(full_path) and method == "POST":
            raise HTTPException(status_code=404, detail="Not found")

    base_url = resolve_target(full_path)
    body = await request.body()
    headers = {
        k: v for k, v in request.headers.items()
        if k.lower() not in HOP_BY_HOP_HEADERS
    }

    # 30s (pas 15s) : l'assistant IA (Gemini -> repli OpenRouter) peut
    # légitimement prendre jusqu'à ~20-25s dans son pire cas - avec 15s
    # ici, la Gateway coupait la requête AVANT même que ai-service n'ait
    # fini d'essayer son propre repli, renvoyant un 502 alors que l'appel
    # aurait fini par réussir. 30s laisse aussi de la marge pour l'upload
    # d'une photo (jusqu'à 5 Mo) sur une connexion mobile lente.
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            upstream = await client.request(
                method,
                base_url + full_path,
                params=request.query_params,
                headers=headers,
                content=body,
            )
        except httpx.RequestError:
            raise HTTPException(status_code=502, detail=f"Upstream service unreachable: {base_url}")

    response_headers = {
        k: v for k, v in upstream.headers.items()
        if k.lower() not in HOP_BY_HOP_HEADERS
    }
    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        headers=response_headers,
    )
