"""User Service - JWT issuing + password hashing.

This is the only service that ISSUES tokens (since it's the only one that
knows about passwords). Itinerary Service and Recommendation Service only
VERIFY tokens using the same SECRET_KEY - they never see a password.
"""
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

from . import storage
from .config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(user_id: str, full_name: str = "", email: str = "", avatar: str | None = None) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    # full_name/email/avatar are non-secret and rarely change, so we embed
    # them as claims: other services can trust "who is this" without a
    # network call back to User Service on every request. Tradeoff: if a
    # user renames themselves or changes avatar, existing tokens show the
    # old value until they log in again (or, for avatar specifically, until
    # the /me/avatar endpoint hands back a freshly-minted token — see
    # routers/auth.py::update_avatar).
    payload = {"sub": user_id, "full_name": full_name, "email": email, "avatar": avatar, "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    credentials_exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: Optional[str] = payload.get("sub")
        if user_id is None:
            raise credentials_exc
    except JWTError:
        raise credentials_exc

    user = storage.find_user_by_id(user_id)
    if user is None:
        raise credentials_exc
    return user
