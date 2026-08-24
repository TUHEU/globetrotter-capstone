"""Assistant router: POST /assistant/chat.

Ce service NE STOCKE PAS l'historique de conversation - le client (l'app
Flutter) renvoie les derniers messages à chaque appel, comme un chat
"stateless" classique (même modèle que l'API ChatGPT/Claude côté client).
Plus simple à faire correctement pour un projet de cours qu'une vraie
persistance de conversation, et suffisant pour l'usage prévu.
"""
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException

from .. import clients
from ..config import GEMINI_MODEL
from ..gemini_client import ask_gemini, GeminiError
from ..openrouter_client import ask_openrouter, OpenRouterError
from ..models import ChatRequest, ChatResponse
from ..security import get_current_user, get_raw_token

router = APIRouter(prefix="/assistant", tags=["Assistant"])

# Cameroun est en UTC+1 (WAT) toute l'année, sans heure d'été - inutile
# d'ajouter une dépendance de fuseaux horaires (zoneinfo/pytz) pour un
# décalage fixe qui ne change jamais.
YAOUNDE_TZ = timezone(timedelta(hours=1))


def _time_of_day_label(hour: int) -> str:
    if 5 <= hour < 12:
        return "le matin"
    if 12 <= hour < 18:
        return "l'après-midi"
    return "le soir ou la nuit"


def _build_system_instruction(
    user: dict, destinations: list, itineraries: list, is_new_conversation: bool = True
) -> str:
    dest_lines = "\n".join(
        f"- {d['name']} ({d.get('category', '?')}, quartier {d.get('quartier', '?')}, "
        f"~{d.get('avg_price_fcfa', 0)} FCFA) : {d.get('description', '')[:120]}"
        for d in destinations
    ) or "(aucune donnée de destination disponible pour le moment)"

    trip_lines = "\n".join(
        f"- \"{it['title']}\" ({len(it.get('stops', []))} arrêt(s))" for it in itineraries
    ) or "(aucun itinéraire enregistré pour le moment)"

    now_yaounde = datetime.now(YAOUNDE_TZ)
    time_str = now_yaounde.strftime("%H:%M")
    period = _time_of_day_label(now_yaounde.hour)

    greeting_instruction = (
        f"Il est actuellement {time_str} à Yaoundé ({period}). C'est le DÉBUT de la "
        "conversation (aucun message précédent) : commence ta toute première réponse "
        "par une salutation adaptée à cette heure (\"Bonjour\" le matin/l'après-midi, "
        "\"Bonsoir\" le soir - ou l'équivalent anglais \"Good morning\"/\"Good afternoon\"/"
        "\"Good evening\" si l'utilisateur écrit en anglais), avant de répondre à sa question."
        if is_new_conversation
        else
        f"Il est actuellement {time_str} à Yaoundé. La conversation est déjà en cours : "
        "ne répète PAS de salutation à chaque message, réponds directement."
    )

    return f"""Tu es l'assistant de voyage de GlobeTrotter, une application dédiée
exclusivement à la découverte de Yaoundé, capitale du Cameroun. Tu discutes
avec {user.get('full_name') or "un utilisateur"}.

{greeting_instruction}

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
    destinations, itineraries = clients.get_grounding_data(token)
    is_new_conversation = len(body.history) == 0
    system_instruction = _build_system_instruction(
        current, destinations, itineraries, is_new_conversation
    )

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
