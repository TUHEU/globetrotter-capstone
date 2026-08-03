"""Recommendation Service - Configuration (Phase 2)."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"

SECRET_KEY = os.getenv("SECRET_KEY", "globetrotter-phase2-secret-change-me")
ALGORITHM = "HS256"

DESTINATIONS_FILE = DATA_DIR / "destinations.json"
DESTINATION_REVIEWS_FILE = DATA_DIR / "destination_reviews.json"
# Compteurs de popularité séparés des données de destinations elles-mêmes -
# destinations.json est un contenu CURATÉ suivi par git (noms, images,
# coordonnées) ; popularity_overrides.json est une donnée RUNTIME (comme
# users.json), gitignorée, pour éviter que chaque incrément de popularité
# entre en conflit avec un futur `git pull` sur le VPS.
POPULARITY_FILE = DATA_DIR / "popularity_overrides.json"

# This service is the "hub": it calls BOTH other services to build a
# recommendation (preferences from User Service, past trips from
# Itinerary Service) - exactly the example the course slides give:
# "Recommendation Service calling User Service".
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://localhost:8001")
ITINERARY_SERVICE_URL = os.getenv("ITINERARY_SERVICE_URL", "http://localhost:8002")
