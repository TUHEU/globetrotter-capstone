"""Auth router: POST /register, POST /login, GET /me."""
from fastapi import APIRouter, Depends, HTTPException, status

from .. import storage
from ..models import RegisterRequest, LoginRequest, TokenResponse, UserPublic
from ..security import hash_password, verify_password, create_access_token, get_current_user

router = APIRouter(tags=["Auth"])


def _public(user: dict) -> dict:
    return {k: user[k] for k in ("id", "full_name", "email", "preferences")}


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
    token = create_access_token(user["id"])
    return {"access_token": token, "token_type": "bearer", "user": _public(user)}


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest):
    user = storage.find_user_by_email(body.email)
    if not user or not verify_password(body.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    token = create_access_token(user["id"])
    return {"access_token": token, "token_type": "bearer", "user": _public(user)}


@router.get("/me", response_model=UserPublic)
def me(current=Depends(get_current_user)):
    return _public(current)
