# GlobeTrotter Yaoundé — Projet complet (Phase 2 : Microservices)

Projet capstone CS 4122 (Distributed Systems) — The ICT University

## Structure

```
GlobeTrotter_Phase2_Complete/
├── backend/                      4 microservices + API Gateway
│   ├── api-gateway/                port 8000 — SEUL point d'entrée public
│   ├── user-service/                port 8001 — comptes, JWT, préférences
│   ├── itinerary-service/           port 8002 — sorties, appelle Recommendation Service
│   ├── recommendation-service/      port 8003 — recos, appelle User + Itinerary Service
│   ├── docker-compose.yml          lance les 4 services ensemble
│   └── README.md                   explication détaillée de l'architecture
│
├── frontend/                     App Flutter (Web + Android + Windows) — inchangée
│   ├── lib/
│   ├── assets/icon/
│   └── pubspec.yaml
│
└── database/                     Vue isolée du stockage par service (Phase 2 — JSON)
    ├── user-service/               users.json + storage.py
    ├── itinerary-service/          itineraries.json + storage.py
    └── recommendation-service/     destinations.json + storage.py
```

## ⚠️ État actuel — important

- **Le backend Phase 2 a été testé de bout en bout** (register → login →
  recherche → création de sortie → recommandations croisées) et fonctionne
  réellement : les services s'appellent entre eux en HTTP, pas juste en façade.
- **Le frontend pointe TOUJOURS vers le monolithe Phase 1** en production
  (`https://fahglobe.duckdns.org`, encore en ligne sur ton VPS). Ce zip ne
  change PAS `prodUrl` automatiquement, pour ne rien casser tant que la
  Phase 2 n'est pas déployée sur le VPS.
- Pour basculer le frontend sur la Phase 2 une fois déployée : une seule
  ligne à changer dans `frontend/lib/core/constants.dart` → `prodUrl` doit
  pointer vers l'URL publique de l'**API Gateway** (port 8000 en interne),
  jamais directement vers un des 3 services.

## Toujours en JSON (comme la Phase 1)

Chaque service a son propre fichier JSON isolé — ça respecte le principe du
diagramme (chaque service possède ses données, personne d'autre n'y touche
directement), mais ce n'est pas encore du MySQL. Si la spec de cours exige
une vraie base de données à cette phase, dis-le : la conversion est plus
simple maintenant que les services sont déjà séparés.

## Lancer en local (sans Docker) — 4 terminaux

```bash
cd backend/user-service && pip install -r requirements.txt --break-system-packages
uvicorn main:app --reload --port 8001

cd backend/itinerary-service && pip install -r requirements.txt --break-system-packages
RECOMMENDATION_SERVICE_URL=http://127.0.0.1:8003 uvicorn main:app --reload --port 8002

cd backend/recommendation-service && pip install -r requirements.txt --break-system-packages
USER_SERVICE_URL=http://127.0.0.1:8001 ITINERARY_SERVICE_URL=http://127.0.0.1:8002 uvicorn main:app --reload --port 8003

cd backend/api-gateway && pip install -r requirements.txt --break-system-packages
USER_SERVICE_URL=http://127.0.0.1:8001 ITINERARY_SERVICE_URL=http://127.0.0.1:8002 RECOMMENDATION_SERVICE_URL=http://127.0.0.1:8003 uvicorn main:app --reload --port 8000
```

Teste tout via la Gateway (jamais les ports 8001-8003 directement, sauf
pour consulter leur `/docs` en debug) : `http://localhost:4200`.

## Lancer avec Docker Compose (le livrable "single VM" de la slide)

```bash
cd backend
docker compose up --build
```

## Ce qui manque encore (documenté, pas oublié)

- Communication asynchrone (RabbitMQ/SQS) — volontairement absente à ce
  stade, mentionnée dans `backend/README.md`
- Vraie base de données par service (actuellement JSON)
- Service discovery, tracing distribué — prévus Phase 3/4

## Prochaine décision à prendre ensemble

1. Garde-t-on JSON ou passe-t-on à MySQL par service maintenant ?
2. Déploie-t-on ces 4 services sur le VPS (à côté du monolithe ou en
   remplacement) ?
3. Une fois déployé, on bascule `prodUrl` du frontend vers la Gateway.
