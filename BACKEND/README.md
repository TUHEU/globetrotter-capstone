# GlobeTrotter Yaoundé — Phase 1: The Monolith (CS 4122)

Single FastAPI server, JSON file storage (per Phase 1 spec — no database yet).
The data access layer is isolated in `app/storage.py` so Phase 2 can swap in MySQL/microservices without touching business logic.

## Run
```bash
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Interactive docs: http://localhost:8000/docs

## Endpoints (7)
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | /register | – | Register (name, email, password, preferences) |
| POST | /login | – | Login → JWT |
| GET | /me | JWT | Current user profile |
| GET | /destinations | – | Search destinations (?q=, ?tag=, ?country=) |
| GET | /destinations/{id} | – | Destination detail |
| GET | /recommendations | JWT | Personalized recos (preferences + past trips + popularity) |
| POST/GET/PUT/DELETE | /itineraries | JWT | Create, view, manage, share itineraries |

Categories: attraction, museum, nature, market, restaurant, cafe, hotel, entertainment
Preference tags: food, culture, nature, history, art, shopping, nightlife, family, relax, romance, photo, sport, wildlife, hiking, luxury, events
