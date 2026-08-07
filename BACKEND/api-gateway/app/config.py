"""API Gateway - Configuration: where each backend service lives."""
import os

USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://localhost:8001")
ITINERARY_SERVICE_URL = os.getenv("ITINERARY_SERVICE_URL", "http://localhost:8002")
RECOMMENDATION_SERVICE_URL = os.getenv("RECOMMENDATION_SERVICE_URL", "http://localhost:8003")
AI_SERVICE_URL = os.getenv("AI_SERVICE_URL", "http://localhost:8004")

# Ordered path-prefix -> service mapping. First match wins, so put more
# specific prefixes before shorter/overlapping ones.
ROUTES = [
    ("/register", USER_SERVICE_URL),
    ("/login", USER_SERVICE_URL),
    ("/auth", USER_SERVICE_URL),          # /auth/google (Google Sign-In)
    ("/me", USER_SERVICE_URL),
    ("/reviews", USER_SERVICE_URL),        # avis sur l'application
    ("/favorites", USER_SERVICE_URL),      # destinations sauvegardées
    ("/users", USER_SERVICE_URL),          # recherche d'utilisateurs (amis)
    ("/follow", USER_SERVICE_URL),         # suivre / ne plus suivre
    ("/itineraries", ITINERARY_SERVICE_URL),
    ("/recommendations", RECOMMENDATION_SERVICE_URL),
    ("/destinations", RECOMMENDATION_SERVICE_URL),
    ("/categories", RECOMMENDATION_SERVICE_URL),
    ("/assistant", AI_SERVICE_URL),        # chat IA
]
