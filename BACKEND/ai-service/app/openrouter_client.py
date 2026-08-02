"""Thin wrapper around OpenRouter's OpenAI-compatible chat completions API.
Used ONLY as an automatic, silent fallback when Gemini is unavailable -
see routers/assistant.py. The user never knows which provider answered.
"""
from typing import List, Dict

import httpx

from .config import OPENROUTER_API_URL, OPENROUTER_API_KEY, OPENROUTER_MODEL


class OpenRouterError(Exception):
    pass


def ask_openrouter(system_instruction: str, history: List[Dict[str, str]], message: str) -> str:
    if not OPENROUTER_API_KEY:
        raise OpenRouterError(
            "OPENROUTER_API_KEY n'est pas configurée côté serveur (repli désactivé)."
        )

    messages = [{"role": "system", "content": system_instruction}]
    for m in history:
        # OpenRouter suit le format OpenAI : "assistant", pas "model".
        messages.append({"role": m["role"], "content": m["content"]})
    messages.append({"role": "user", "content": message})

    try:
        r = httpx.post(
            OPENROUTER_API_URL,
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
                # Recommandé par OpenRouter pour l'attribution des requêtes -
                # n'affecte pas la réponse, purement informatif côté OpenRouter.
                "X-Title": "GlobeTrotter Yaounde",
            },
            json={"model": OPENROUTER_MODEL, "messages": messages, "max_tokens": 500},
            timeout=20.0,
        )
    except httpx.RequestError as e:
        raise OpenRouterError(f"Impossible de contacter OpenRouter : {e}")

    if r.status_code != 200:
        raise OpenRouterError(f"OpenRouter a renvoyé une erreur ({r.status_code}) : {r.text[:300]}")

    data = r.json()
    try:
        return data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError) as e:
        raise OpenRouterError(f"Réponse OpenRouter inattendue : {e}")
