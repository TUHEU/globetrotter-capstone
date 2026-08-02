"""AI Service - Configuration (Phase 2)."""
import os

SECRET_KEY = os.getenv("SECRET_KEY", "globetrotter-phase2-secret-change-me")
ALGORITHM = "HS256"

RECOMMENDATION_SERVICE_URL = os.getenv("RECOMMENDATION_SERVICE_URL", "http://localhost:8003")
ITINERARY_SERVICE_URL = os.getenv("ITINERARY_SERVICE_URL", "http://localhost:8002")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
# Modèle Gemini gratuit (voir https://ai.google.dev/gemini-api/docs/pricing) :
# rapide, quota gratuit généreux, largement suffisant pour un assistant de
# conversation + recommandations. Changeable via variable d'env sans redeploy.
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_API_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
)

# --------------------------------------------------------------------------
# Repli automatique sur OpenRouter (gratuit) si Gemini est indisponible - par
# exemple le fameux 403 PERMISSION_DENIED que Google applique parfois à des
# projets tout neufs, sans lien avec notre code. Totalement transparent pour
# l'utilisateur : il ne voit jamais quel fournisseur a répondu, seulement
# le texte de la réponse.
# --------------------------------------------------------------------------
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"
# "openrouter/free" = le routeur automatique d'OpenRouter : il choisit lui-même
# un modèle gratuit actuellement disponible plutôt qu'un ID figé qui pourrait
# disparaître du catalogue gratuit (celui-ci change souvent).
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "openrouter/free")
