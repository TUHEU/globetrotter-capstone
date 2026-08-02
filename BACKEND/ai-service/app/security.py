"""AI Service - JWT verification ONLY (même modèle que Recommendation Service :
ce service n'émet jamais de token, il vérifie juste celui déjà émis par
User Service)."""
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

from .config import SECRET_KEY, ALGORITHM

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="http://localhost:8001/login")


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

    return {
        "id": user_id,
        "full_name": payload.get("full_name", ""),
        "email": payload.get("email", ""),
    }


def get_raw_token(token: str = Depends(oauth2_scheme)) -> str:
    return token
