"""User Service - Configuration (Phase 2)."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"

# NOTE: in real life every service would have its OWN secret / trust boundary,
# often via a shared auth provider. For this course, we use one shared signing
# secret across services so a token issued by User Service is verifiable by
# Itinerary Service and Recommendation Service without them calling back here
# for every single request.
SECRET_KEY = os.getenv("SECRET_KEY", "globetrotter-phase2-secret-change-me")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24h for dev

# Google Sign-In: liste blanche des Client IDs OAuth autorisés (Web + Android),
# séparés par des virgules. Un token Google n'est accepté que si son
# claim "aud" correspond à l'un de ces identifiants — sinon n'importe quelle
# app Google tierce pourrait usurper un utilisateur.
# Exemple : "123-web.apps.googleusercontent.com,123-android.apps.googleusercontent.com"
GOOGLE_CLIENT_IDS = [
    c.strip() for c in os.getenv("GOOGLE_CLIENT_IDS", "").split(",") if c.strip()
]

USERS_FILE = DATA_DIR / "users.json"
REVIEWS_FILE = DATA_DIR / "reviews.json"
FAVORITES_FILE = DATA_DIR / "favorites.json"
FOLLOWS_FILE = DATA_DIR / "follows.json"
MESSAGES_FILE = DATA_DIR / "messages.json"
