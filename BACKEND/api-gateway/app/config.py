"""API Gateway - Configuration: where each backend service lives."""
import os

USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://localhost:8001")
ITINERARY_SERVICE_URL = os.getenv("ITINERARY_SERVICE_URL", "http://localhost:8002")
RECOMMENDATION_SERVICE_URL = os.getenv("RECOMMENDATION_SERVICE_URL", "http://localhost:8003")
AI_SERVICE_URL = os.getenv("AI_SERVICE_URL", "http://localhost:8004")
CHAT_SERVICE_URL = os.getenv("CHAT_SERVICE_URL", "http://localhost:8005")

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
    ("/notifications", USER_SERVICE_URL),  # cloche de notifications - routeur déjà prêt côté user-service, juste absent d'ici (404 permanent avant ce correctif)
    ("/follow", USER_SERVICE_URL),         # suivre / ne plus suivre
    ("/messages", USER_SERVICE_URL),       # messagerie directe
    ("/static/message_images", USER_SERVICE_URL),  # photos envoyées en message
    ("/chat", CHAT_SERVICE_URL),           # global group chat (REST)
    ("/ws/chat", CHAT_SERVICE_URL),        # global group chat (WebSocket)
    ("/static/chat_uploads", CHAT_SERVICE_URL),    # chat media files
    ("/itineraries", ITINERARY_SERVICE_URL),
    ("/recommendations", RECOMMENDATION_SERVICE_URL),
    ("/destinations", RECOMMENDATION_SERVICE_URL),
    ("/categories", RECOMMENDATION_SERVICE_URL),
    ("/static", RECOMMENDATION_SERVICE_URL),  # real destination photos (static/images/*.jpg)
    ("/assistant", AI_SERVICE_URL),        # chat IA
]
