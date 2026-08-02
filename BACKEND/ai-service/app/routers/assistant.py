"""Assistant router: POST /assistant/chat.

Ce service NE STOCKE PAS l'historique de conversation - le client (l'app
Flutter) renvoie les derniers messages à chaque appel, comme un chat
"stateless" classique (même modèle que l'API ChatGPT/Claude côté client).
Plus simple à faire correctement pour un projet de cours qu'une vraie
persistance de conversation, et suffisant pour l'usage prévu.
"""
from fastapi import APIRouter, Depends, HTTPException

from .. import clients
from ..config import GEMINI_MODEL
from ..gemini_client import ask_gemini, GeminiError
from ..openrouter_client import ask_openrouter, OpenRouterError
from ..models import ChatRequest, ChatResponse
from ..security import get_current_user, get_raw_token

router = APIRouter(prefix="/assistant", tags=["Assistant"])


def _build_system_instruction(user: dict, destinations: list, itineraries: list) -> str:
    dest_lines = "\n".join(
        f"- {d['name']} ({d.get('category', '?')}, quartier {d.get('quartier', '?')}, "
        f"~{d.get('avg_price_fcfa', 0)} FCFA) : {d.get('description', '')[:120]}"
        for d in destinations
    ) or "(aucune donnée de destination disponible pour le moment)"

    trip_lines = "\n".join(
        f"- \"{it['title']}\" ({len(it.get('stops', []))} arrêt(s))" for it in itineraries
    ) or "(aucun itinéraire enregistré pour le moment)"

    return f"""Tu es l'assistant de voyage de GlobeTrotter, une application dédiée
exclusivement à la découverte de Yaoundé, capitale du Cameroun. Tu discutes
avec {user.get('full_name') or "un utilisateur"}.

RÈGLES IMPORTANTES :
- Ne recommande QUE des lieux qui apparaissent dans la liste ci-dessous. Ne
  jamais inventer un lieu, un prix, ou une adresse qui n'y figure pas.
- Si on te demande quelque chose hors de Yaoundé ou hors du champ de
  l'application (voyage, destinations, itinéraires), dis poliment que tu es
  spécialisé sur Yaoundé et recentre la conversation.
- Réponds de façon concise (quelques phrases), chaleureuse, et concrète.
- Réponds dans la langue utilisée par l'utilisateur (français ou anglais).

DESTINATIONS DISPONIBLES DANS L'APP :
{dest_lines}

ITINÉRAIRES DÉJÀ CRÉÉS PAR CET UTILISATEUR :
{trip_lines}
"""


@router.post("/chat", response_model=ChatResponse)
def chat(
    body: ChatRequest,
    current=Depends(get_current_user),
    token: str = Depends(get_raw_token),
):
    destinations = clients.get_top_destinations(limit=20)
    itineraries = clients.get_user_itineraries(token)
    system_instruction = _build_system_instruction(current, destinations, itineraries)

    history = [{"role": m.role, "content": m.content} for m in body.history]

    # Repli silencieux : si Gemini échoue pour n'importe quelle raison (panne,
    # 403 lié à un projet Google fraîchement créé, quota dépassé...), on
    # retente EXACTEMENT la même requête via OpenRouter (gratuit) sans que
    # l'utilisateur ne voie de différence - juste une réponse qui arrive.
    try:
        reply = ask_gemini(system_instruction, history, body.message)
    except GeminiError as gemini_error:
        try:
            reply = ask_openrouter(system_instruction, history, body.message)
        except OpenRouterError:
            # Les deux fournisseurs ont échoué : là on remonte une vraie
            # erreur, en gardant le message Gemini original (plus parlant
            # pour le diagnostic que celui d'OpenRouter en second repli).
            raise HTTPException(status_code=502, detail=str(gemini_error))

    return {"reply": reply}


@router.get("/health")
def assistant_health():
    return {"service": "ai-service", "model": GEMINI_MODEL}
