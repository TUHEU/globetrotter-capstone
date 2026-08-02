"""Thin wrapper around the Gemini API's generateContent endpoint.

Note: unlike OpenAI/Anthropic, the Gemini API key is passed as a URL query
parameter (?key=...), not an Authorization header - a common gotcha.
"""
from typing import List, Dict

import httpx

from .config import GEMINI_API_URL, GEMINI_API_KEY


class GeminiError(Exception):
    pass


def ask_gemini(system_instruction: str, history: List[Dict[str, str]], message: str) -> str:
    if not GEMINI_API_KEY:
        raise GeminiError(
            "GEMINI_API_KEY n'est pas configurée côté serveur. "
            "Ajoutez-la dans backend/.env (voir README de ai-service)."
        )

    # Gemini utilise "model" au lieu de "assistant" pour ses propres tours -
    # traduction nécessaire depuis notre schéma interne (user/assistant).
    contents = [
        {"role": "user" if m["role"] == "user" else "model", "parts": [{"text": m["content"]}]}
        for m in history
    ]
    contents.append({"role": "user", "parts": [{"text": message}]})

    payload = {
        "contents": contents,
        "systemInstruction": {"parts": [{"text": system_instruction}]},
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 500,
        },
    }

    try:
        r = httpx.post(
            GEMINI_API_URL,
            params={"key": GEMINI_API_KEY},
            json=payload,
            timeout=20.0,
        )
    except httpx.RequestError as e:
        raise GeminiError(f"Impossible de contacter l'API Gemini : {e}")

    if r.status_code != 200:
        raise GeminiError(f"Gemini a renvoyé une erreur ({r.status_code}) : {r.text[:300]}")

    data = r.json()
    try:
        candidates = data["candidates"]
        if not candidates:
            raise GeminiError("Gemini n'a renvoyé aucune réponse (contenu probablement filtré).")
        parts = candidates[0]["content"]["parts"]
        return "".join(p.get("text", "") for p in parts).strip()
    except (KeyError, IndexError) as e:
        raise GeminiError(f"Réponse Gemini inattendue : {e}")
