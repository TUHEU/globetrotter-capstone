"""Chat Service – Configuration."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
UPLOAD_DIR = BASE_DIR / "static" / "chat_uploads"

# Create dirs on import
DATA_DIR.mkdir(parents=True, exist_ok=True)
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# Shared JWT secret with user-service (same token, different service)
SECRET_KEY = os.getenv("SECRET_KEY", "globetrotter-phase2-secret-change-me")
ALGORITHM = "HS256"

# 50 MB max per upload
MAX_UPLOAD_BYTES = 50 * 1024 * 1024

# Keep only the last N messages in the JSON file (rolling window)
MAX_STORED_MESSAGES = 500
