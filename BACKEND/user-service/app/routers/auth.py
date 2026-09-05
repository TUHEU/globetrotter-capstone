"""Auth router: POST /register, POST /login, POST /auth/google, GET /me.

Identical business logic to the Phase 1 monolith's auth.py — the point of
this service isn't to change WHAT it does, it's to change WHERE it lives:
its own process, its own port, its own data file, deployable and scalable
independently of the other two services.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from google.auth import exceptions as google_exceptions
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from .. import storage
from ..config import GOOGLE_CLIENT_IDS
from ..models import RegisterRequest, LoginRequest, GoogleAuthRequest, TokenResponse, UserPublic
from ..security import hash_password, verify_password, create_access_token, get_current_user

router = APIRouter(tags=["Auth"])


def _public(user: dict) -> dict:
    return {k: user.get(k) for k in ("id", "full_name", "email", "preferences", "avatar")}


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest):
    if storage.find_user_by_email(body.email):
        raise HTTPException(status_code=409, detail="Email already registered")
    user = {
        "id": storage.new_id(),
        "full_name": body.full_name.strip(),
        "email": body.email.lower().strip(),
        "password_hash": hash_password(body.password),
        "preferences": [p.lower() for p in body.preferences],
    }
    storage.create_user(user)
    token = create_access_token(user["id"], user["full_name"], user["email"], user.get("avatar"))
    return {"access_token": token, "token_type": "bearer", "user": _public(user)}


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest):
    user = storage.find_user_by_email(body.email)
    if not user or not verify_password(body.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    storage.record_login(user["id"])
    token = create_access_token(user["id"], user["full_name"], user["email"], user.get("avatar"))
    return {"access_token": token, "token_type": "bearer", "user": _public(user)}


@router.post("/auth/google", response_model=TokenResponse)
def login_with_google(body: GoogleAuthRequest):
    if not GOOGLE_CLIENT_IDS:
        raise HTTPException(
            status_code=503,
            detail="Google Sign-In n'est pas configuré côté serveur (GOOGLE_CLIENT_IDS manquant).",
        )
    try:
        # Vérifie la signature du token auprès de Google (clés publiques Google,
        # mises en cache automatiquement) — on ne fait JAMAIS confiance à un
        # token sans le vérifier cryptographiquement.
        idinfo = google_id_token.verify_oauth2_token(
            body.id_token, google_requests.Request()
        )
    except google_exceptions.TransportError:
        # Le serveur n'a pas pu joindre Google (réseau/pare-feu VPS) —
        # ce n'est PAS la faute de l'utilisateur, donc pas un 401.
        raise HTTPException(
            status_code=503,
            detail="Impossible de contacter Google pour vérifier la connexion. Réessayez.",
        )
    except (ValueError, google_exceptions.GoogleAuthError):
        # Token malformé, expiré, signature invalide, etc. — celui-là, oui,
        # c'est un vrai jeton invalide.
        raise HTTPException(status_code=401, detail="Jeton Google invalide ou expiré")

    # "aud" = à quelle appli ce token était destiné. On vérifie nous-mêmes
    # contre notre liste blanche (web + android) plutôt que de laisser
    # verify_oauth2_token exiger un seul audience fixe.
    if idinfo.get("aud") not in GOOGLE_CLIENT_IDS:
        raise HTTPException(status_code=401, detail="Ce jeton Google n'est pas destiné à cette application")

    if not idinfo.get("email_verified", False):
        raise HTTPException(status_code=401, detail="Email Google non vérifié")

    user = storage.find_or_create_google_user(
        email=idinfo["email"],
        full_name=idinfo.get("name") or idinfo["email"].split("@")[0],
        google_sub=idinfo["sub"],
    )
    storage.record_login(user["id"])
    token = create_access_token(user["id"], user["full_name"], user["email"], user.get("avatar"))
    return {"access_token": token, "token_type": "bearer", "user": _public(user)}


@router.get("/me", response_model=UserPublic)
def me(current=Depends(get_current_user)):
    return _public(current)


@router.patch("/me/avatar", response_model=TokenResponse)
def update_avatar(avatar: str, current=Depends(get_current_user)):
    """Sets the picked avatar and returns a freshly-minted token carrying
    it — chat and other services read avatar/name straight off the JWT
    (no per-request lookup), so without reissuing the token here the new
    avatar wouldn't show up anywhere until the next login."""
    if avatar not in storage.ALLOWED_AVATARS:
        raise HTTPException(
            status_code=400,
            detail=f"avatar must be one of {sorted(storage.ALLOWED_AVATARS)}",
        )
    user = storage.set_avatar(current["id"], avatar)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    token = create_access_token(user["id"], user["full_name"], user["email"], user.get("avatar"))
    return {"access_token": token, "token_type": "bearer", "user": _public(user)}
