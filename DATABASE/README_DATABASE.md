# GlobeTrotter Yaoundé — Phase 1 Database (JSON File Storage)

⚠️ Per the CS 4122 Phase 1 spec, the "database" is JSON files — NO MySQL yet.
(MySQL arrives in Phase 2 when we decompose into microservices.)

## The 3 tables (files)
| File | Role | Equivalent SQL table |
|---|---|---|
| destinations.json | 26 places in Yaoundé (attractions, restaurants, hotels, markets...) | destinations |
| users.json | Registered users (id, full_name, email, bcrypt password_hash, preferences) | users |
| itineraries.json | User trips: title, dates, stops[], shared_with[] | itineraries + stops |

## Where to put these files
Place this `data/` content in: `globetrotter_backend/data/`
The backend reads/writes them through `app/storage.py` (repository pattern).

## Known limitations (this is the POINT of Phase 1 — say it at your defense)
- No transactions: a crash mid-write can corrupt data (mitigated by atomic tmp-file swap)
- No indexing: every search is a full scan O(n)
- No concurrent access control: mitigated by a threading.Lock (single process only!)
- Doesn't scale horizontally: the file lives on ONE server's disk

## Phase 2 migration plan
Replace app/storage.py with a MySQL implementation (PyMySQL/SQLAlchemy).
Nothing else changes — routers and business logic are storage-agnostic.
