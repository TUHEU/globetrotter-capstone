# GlobeTrotter — Phase 2: Microservices
CS 4122 · Distributed Systems · The ICT University

The Phase 1 monolith is decomposed into three independent services plus an
API Gateway, matching the course's Phase 2 architecture diagram:

```
                     ┌──────────────┐
   Client  ───────►  │ API Gateway  │  :8000
 (Flutter app)        └───┬──┬───┬──┘
                          │  │   │
              ┌───────────┘  │   └───────────────┐
              ▼               ▼                   ▼
      ┌───────────────┐ ┌──────────────────┐ ┌────────────────────────┐
      │ User Service  │ │ Itinerary Service│ │ Recommendation Service │
      │    :8001      │ │      :8002       │ │         :8003          │
      │ users.json    │ │ itineraries.json │ │ destinations.json      │
      └───────────────┘ └────────┬─────────┘ └────────────┬───────────┘
                                  │   (validate/bump popularity)
                                  └──────────────►──────────┘
                          (Recommendation Service also calls
                           User Service + Itinerary Service
                           to build a personalized result)
```

## Why the split is where it is

- **User Service** is the only service that ever sees a password, and the
  only one that *issues* JWTs. Everyone else just *verifies* them with the
  same shared `SECRET_KEY` — no network call needed just to confirm "is
  this token valid."
- **Itinerary Service** no longer has its own copy of the destinations
  catalog. When someone adds a stop to a trip, it makes a real HTTP call
  to Recommendation Service to check the destination exists and to bump
  its popularity counter (`app/clients.py`). If that call fails, adding
  the stop is rejected — a new failure mode that simply didn't exist in
  the monolith.
- **Recommendation Service** is the "hub": it owns the destinations
  catalog *and* calls the other two services (forwarding the caller's own
  bearer token) to get fresh preferences and past-trip data before scoring
  recommendations. This is the textbook "Recommendation Service calling
  User Service" example from the slides.
- **API Gateway** owns no data at all. It just inspects the incoming path
  and forwards the request (method, headers, query string, body) to
  whichever service owns it, then relays the response back untouched. It
  also refuses to forward to `POST /destinations/{id}/visit`, which is
  meant to be service-to-service only, never public.

## Running it locally (no Docker)

Open four terminals, one per service:

```bash
# Terminal 1
cd user-service && pip install -r requirements.txt --break-system-packages
uvicorn main:app --reload --port 8001

# Terminal 2
cd itinerary-service && pip install -r requirements.txt --break-system-packages
uvicorn main:app --reload --port 8002

# Terminal 3
cd recommendation-service && pip install -r requirements.txt --break-system-packages
uvicorn main:app --reload --port 8003

# Terminal 4
cd api-gateway && pip install -r requirements.txt --break-system-packages
uvicorn main:app --reload --port 8000
```

Then point the Flutter app (or curl / Postman) at `http://localhost:8000` —
the Gateway — for everything. Never call 8001/8002/8003 directly except to
poke at each service's own `/docs` page while debugging.

Each service also exposes its own interactive API docs while developing:
`http://localhost:8001/docs`, `:8002/docs`, `:8003/docs`.

## Running it with Docker Compose (matches the "single VM" deliverable)

```bash
docker compose up --build
```

This builds and starts all four containers, wired together with the right
`*_SERVICE_URL` environment variables (see `docker-compose.yml`), and
exposes only port `8000` — the Gateway — as the one entry point. The
individual service ports (8001-8003) are also mapped to the host in this
compose file for easier debugging; **remove those `ports:` lines before
treating this as a real production deployment**, since nothing outside the
Gateway should be publicly reachable.

## Quick smoke test

```bash
# Register through the Gateway
curl -X POST http://localhost:8000/register \
  -H "Content-Type: application/json" \
  -d '{"full_name":"Test User","email":"test@example.com","password":"secret123","preferences":["nature","food"]}'

# Search destinations through the Gateway
curl http://localhost:8000/destinations?tag=nature

# Get personalized recommendations (use the access_token from register/login)
curl http://localhost:8000/recommendations \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

If `/recommendations` works, you've just watched the Gateway route to
Recommendation Service, which in turn called back out to User Service and
Itinerary Service — three services, real network hops, one client request.

## What's deliberately NOT here yet

- No message queue (RabbitMQ/SQS) for asynchronous, event-driven
  communication — the slide lists that as an option alongside synchronous
  REST, but everything here is synchronous request-response, which is
  enough to satisfy this phase's deliverable.
- No service discovery (Consul/etcd/DNS-based) — service locations are
  just env vars. Fine for three known services; the "Service Discovery"
  challenge on the slide is exactly why this doesn't scale to dozens of
  services.
- No distributed tracing — the "Distributed Tracing" challenge on the
  slide (debugging across multiple services) is still open. That's more
  of a Phase 4 (Resilience) concern.
- No automated tests yet for the new inter-service calls (the Phase 1
  pytest suite only covered the old monolith's single-process behavior).
