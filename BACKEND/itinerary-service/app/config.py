"""Itinerary Service - Configuration (Phase 2)."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"

# Same shared secret as User Service, so a token minted there verifies here
# without a network call for every request.
SECRET_KEY = os.getenv("SECRET_KEY", "globetrotter-phase2-secret-change-me")
ALGORITHM = "HS256"

ITINERARIES_FILE = DATA_DIR / "itineraries.json"
COMMENTS_FILE = DATA_DIR / "comments.json"
LIKES_FILE = DATA_DIR / "likes.json"

# Where to find the Recommendation Service, which owns destinations.
# Override with an env var in docker-compose / prod (e.g. http://recommendation-service:8003)
RECOMMENDATION_SERVICE_URL = os.getenv("RECOMMENDATION_SERVICE_URL", "http://localhost:8003")

# Where to find the User Service - needed for the "friends' trips" feed
# (GET /itineraries/feed), which first asks User Service who the caller
# follows before filtering to those people's public itineraries.
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://localhost:8001")
