# Changelog — GlobeTrotter Yaoundé

Projet capstone CS 4122 (Distributed Systems) — The ICT University
Superviseur : Eng. Mughe Godlove · Équipe : Fahdil, Nsangou Hamed Mochtar Ben Bilal

Ce changelog couvre tout le travail réalisé depuis le lancement du projet,
de la Phase 1 (Monolithe) jusqu'à la Phase 2 (Microservices) en production.

---

## [2.5.0] — Bulle de langue déplaçable & corrections diverses
### Ajouté
- Sélecteur de langue transformé en bulle flottante déplaçable (icône globe
  de l'app + badge FR/EN) : un appui simple bascule la langue, un glisser la
  repositionne n'importe où à l'écran — remplace l'ancien sélecteur fixe en
  haut à droite, difficile à toucher précisément sur mobile (chevauchait
  souvent la zone de l'encoche/barre d'état)

### Corrigé
- Build Flutter Web servi dans un sous-dossier (`/app/`) : ajout de
  `--base-href /app/` au build, corrigeant un écran blanc/vide (l'app
  cherchait ses fichiers à la racine du domaine au lieu du bon sous-chemin)
- En-tête HTTP non-ASCII (`X-Title: "GlobeTrotter Yaoundé"`) faisant planter
  le repli OpenRouter avec une `UnicodeEncodeError` — accent retiré

---

## [2.4.0] — Fonctionnalités communautaires (portées du Monolithe Phase 1)
### Ajouté
- **Avis publics sur une destination** (note 1-5 + commentaire), indépendants
  des avis sur l'application elle-même — `GET/POST /destinations/{id}/reviews`
  (recommendation-service), section dédiée sur la fiche de chaque lieu
- **Lieux à proximité** — `GET /destinations/{id}/nearby`, distance à vol
  d'oiseau (formule de haversine) portée telle quelle depuis le monolithe,
  carrousel "À proximité" sur la fiche lieu
- **Localisation en direct** (`geolocator`) : point bleu "vous êtes ici" sur
  la carte d'itinéraire, badge "à X km de vous" sur la fiche lieu et dans la
  liste des arrêts d'un itinéraire
- Coordonnées lat/lng ajoutées aux 26 destinations de Yaoundé (nécessaires
  pour la carte, la météo et les distances — absentes du jeu de données
  initial de la Phase 1)

---

## [2.3.0] — Assistant IA conversationnel
### Ajouté
- Nouveau microservice `ai-service` (FastAPI, sans état), appelant l'API
  Gemini (gratuite, `gemini-2.5-flash`), avec le contexte réel de l'app
  (destinations populaires, itinéraires de l'utilisateur) injecté dans
  chaque requête pour éviter les réponses hors-sujet ou inventées
- **Repli automatique et silencieux vers OpenRouter** (`openrouter/free`) en
  cas d'indisponibilité de Gemini (ex : blocage `403 PERMISSION_DENIED`
  connu et documenté sur les projets Google Cloud tout neufs) — transparent
  pour l'utilisateur, qui ne voit jamais quel fournisseur a répondu
- Écran de discussion (`AssistantScreen`) avec bulle flottante accessible
  depuis n'importe quel onglet de l'app, suggestions de questions au
  premier lancement

---

## [2.2.0] — Favoris
### Ajouté
- `GET/POST/DELETE /favorites` (user-service), stockage `{user_id: [destination_ids]}`
- Icône cœur sur chaque carte destination (mise à jour optimiste, pas
  d'attente réseau perceptible), écran **Favoris** dédié
- Statistiques de profil enrichies (Itinéraires / Région / Favoris)

---

## [2.1.0] — Carte, météo, itinéraires piétons, connexion Google, avis sur l'app
### Ajouté
- Carte interactive (`flutter_map` + OpenStreetMap, gratuite, sans clé API)
  affichant les arrêts d'un itinéraire, avec tracé de trajet à pied
  (OSRM, gratuit) et distance/durée estimée
- Météo en direct par destination (Open-Meteo, gratuite, sans clé API)
- **Connexion Google** (Web + Android) : Client ID OAuth créé sur Google
  Cloud Console, backend `POST /auth/google` vérifiant le jeton et émettant
  le même JWT que la connexion classique
- **Avis sur l'application** (étoiles + commentaire), distincts des avis sur
  les destinations ci-dessus — `POST/GET /reviews` (user-service)

### Modifié
- Migration de `google_sign_in` v6 → v7 (changement d'API cassant :
  singleton `GoogleSignIn.instance`, `initialize()`, `authenticate()`,
  `.authentication` désormais synchrone)
- Images de destinations (Wikimedia Commons) rendues via une balise HTML
  `<img>` native sur le Web (`HtmlElementView`) plutôt que via le canvas
  CanvasKit, qui exige des en-têtes CORS que Wikimedia n'envoie pas
  systématiquement

---

## [2.0.0] — Phase 2 : Microservices
### Ajouté
- Décomposition du monolithe en **5 services indépendants** :
  `user-service`, `itinerary-service`, `recommendation-service`,
  `ai-service`, `api-gateway` — chacun avec son propre stockage JSON et
  son propre conteneur Docker
- Orchestration via **Docker Compose**, déploiement identique en local et
  sur le VPS
- Nouveau `update.sh` adapté à Docker Compose (sauvegarde des données,
  `git pull`, `docker compose up --build -d`, vérification de santé) —
  remplace l'ancien script Phase 1 (venv + systemd)

### Modifié
- **Migration complète du VPS** : arrêt et désactivation du service
  systemd `fahglobe` (Phase 1), passerelle Docker publiée sur le même
  port `4200` pour rester compatible avec la configuration Nginx
  existante sans aucune modification de celle-ci côté domaine public
- Configuration Nginx (`sites-enabled/fahglobe`) mise à jour pour
  proxifier les nouvelles routes Phase 2 (`/auth`, `/reviews`,
  `/favorites`, `/assistant`, `/health`) vers l'API — les anciennes règles
  ne couvraient que les routes historiques de la Phase 1
- Migration des données réelles de production (25 comptes utilisateurs,
  5 itinéraires) vers la nouvelle structure par service

### Corrigé
- Cycle de dépendances circulaire dans `docker-compose.yml`
  (`itinerary-service` ↔ `recommendation-service`) empêchant le démarrage
- Dépendance manquante (`requests`) dans `user-service`, requise par
  `google-auth` pour la vérification des jetons Google

### Sécurité
- **Historique Git nettoyé** (`git filter-repo`) : suppression rétroactive
  des fichiers `users.json`, `reviews.json`, `favorites.json`,
  `itineraries.json` accidentellement committés avec des données réelles
  d'utilisateurs (emails, hachages de mots de passe) dans un dépôt public —
  ces fichiers sont désormais exclus via `.gitignore` et ne vivent que
  sur le VPS (montage Docker), jamais dans le code source

---

## [1.6.0] — Thème & Langue
### Ajouté
- Système de thème clair / sombre / système, persisté localement (`SettingsProvider` + `shared_preferences`)
- Palette dédiée claire et sombre (`AppTheme`), cohérente avec l'identité Cameroun + le site web (vert, orange, or)
- Système de traduction léger FR/EN (`AppStrings`) couvrant toute l'interface (navigation, dashboard, profil, authentification)
- Écran **Paramètres** (`SettingsScreen`) avec sélecteurs de thème et de langue (`SegmentedButton`)
- Sélecteur de langue flottant (FR/EN) visible dès l'écran de connexion, avant toute inscription
- Nouveau **dashboard** sur l'onglet Explorer : bandeau d'accueil dégradé avec avatar, salutation personnalisée et 3 pastilles de statistiques (lieux, catégories, sorties)

### Modifié
- `main.dart` : chargement des préférences (thème/langue) au démarrage, `MaterialApp` piloté par `ThemeMode`
- Tous les écrans principaux (Explore, Recommandations, Sorties, Profil, Login, Register) traduits via `AppStrings`
- Précision : les **données** du backend (noms de lieux, descriptions) restent en français — seul le chrome de l'interface est traduit

### Corrigé
- `auth_scaffold.dart` : classe `_Glow` manquante (référencée mais jamais définie), causant une erreur de compilation
- `register_screen.dart` : chips de centres d'intérêt trop pâles (fond blanc 8% opacité) remplacées par un widget `_InterestChip` à fort contraste (fond marine plein / or plein)
- `constants.dart` : incohérence de slash final entre `prodUrl` et les URLs de développement ; branches conditionnelles mortes nettoyées ; port aligné sur 4200

---

## [1.5.0] — Déploiement production (VPS)
### Ajouté
- Guide complet de déploiement backend sur VPS Ubuntu : systemd + Nginx + Let's Encrypt
- Service systemd `fahglobe` (Gunicorn + workers Uvicorn, redémarrage automatique, logs dédiés)
- Configuration Nginx unique servant à la fois :
  - le site statique (`/var/www/GLOBE`)
  - l'API FastAPI en reverse proxy (port interne 4200) sur les routes `/register`, `/login`, `/destinations`, `/recommendations`, `/itineraries`, `/docs`
- HTTPS via Certbot / Let's Encrypt sur le domaine `fahglobe.duckdns.org`
- `update.sh` — script de mise à jour du backend : sauvegarde automatique des données JSON (`data/*.json`) avant chaque mise à jour, `git pull`, réinstallation des dépendances, redémarrage du service, vérification de santé (`curl` sur l'API)
- `restore.sh` — script de restauration d'une sauvegarde en cas de problème, avec sauvegarde de sécurité de l'état courant avant tout rollback

### Modifié
- `lib/core/constants.dart` (Flutter) : ajout de `prodUrl`, logique `kReleaseMode` pour que tous les builds de production (APK, Web, Windows) utilisent automatiquement le backend hébergé

### Corrigé
- Faute de frappe dans le nom du fichier Nginx (`fahgobe` → `fahglobe`)
- 403 sur le site : mauvais contenu déployé dans `/var/www/GLOBE` (fichier isolé au lieu de la structure complète `index.html` + `app/` + `downloads/`)
- 404 sur `/docs/` : regex Nginx n'acceptait pas le slash final (`/?` ajouté à la regex)

---

## [1.4.0] — Site de téléchargement / vitrine web
### Ajouté
- Site vitrine complet (`website/index.html`) : landing page + hub de téléchargement + présentation des fonctionnalités
- **Détection automatique de l'appareil** du visiteur (Android / Windows / autre) avec mise en avant de la version recommandée
- Mockup de téléphone en pur CSS affichant le vrai contenu de l'app (Mont Fébé, Marché Central, catégories, barre de navigation)
- Section fonctionnalités (6 cartes), section communauté (lien WhatsApp + Google Form), footer institutionnel
- Structure de dossier prête à l'emploi : `app/` (accueil du build Flutter Web) et `downloads/` (APK + zip Windows)
- Animations au scroll, responsive mobile, respect de `prefers-reduced-motion`
- `README_DEPLOY.md` détaillant la procédure de build + déploiement

### Design
- Palette bleu nuit + orange reprenant l'identité visuelle du poster fourni par l'utilisateur
- Typographies Unbounded / Outfit / JetBrains Mono

---

## [1.3.0] — Icônes de l'application
### Ajouté
- Série 1 : 5 concepts d'icônes aux couleurs du Cameroun (Boussole, Les 7 Collines, Le Monument, Globe Afrique, Y Route)
- Série 2 : 5 concepts alternatifs bleu/orange inspirés du poster de présentation du projet (Orbit, Swoosh G, Pin Globe, Trail, Étoile CM)
- Collages de vote prêts pour diffusion WhatsApp (format sondage)
- Sources SVG éditables fournies pour chaque icône

---

## [1.2.0] — Amélioration du design (GUI)
### Ajouté
- Refonte complète de l'écran de connexion (`AuthScaffold`) : fond dégradé Cameroun, silhouette des collines de Yaoundé en `CustomPainter`, halos lumineux, carte en glassmorphism (blur + bordure translucide)
- Layout adaptatif : colonne unique sur mobile, panneau de branding + formulaire côte à côte sur web/desktop (≥ 900px)
- Composants partagés : `glassInput()`, `GradientButton`
- Animations d'entrée (fondu + glissement) sur le logo et la carte de connexion
- Thème global affiné : cartes arrondies, boutons et champs cohérents, snackbars flottantes

---

## [1.1.0] — Questionnaire beta-testeurs
### Ajouté
- Questionnaire Google Form (10 questions max, FR + EN) pour orienter la roadmap produit
- Couvre : profil utilisateur, habitudes de découverte, catégories préférées, fonctionnalités actuelles utilisées, fonctionnalités futures désirées, frustrations, plateforme préférée, score de recommandation (NPS), question ouverte
- Grille d'exploitation des résultats pour la défense académique

---

## [1.0.0] — Phase 1 : Le Monolithe (version initiale)
### Contexte projet
- Recentrage du projet générique "GlobeTrotter" (voyage international) vers **GlobeTrotter Yaoundé**, guide local pour Yaoundé, Cameroun

### Backend (FastAPI, Python)
- Architecture monolithique conforme à la spec Phase 1 : un seul serveur, stockage JSON (volontairement sans base de données, pour illustrer les limites étudiées en cours)
- `app/storage.py` : couche d'accès aux données isolée (repository pattern), écriture atomique par fichier temporaire, verrou `threading.Lock`, prête à être remplacée par MySQL en Phase 2
- `app/security.py` : authentification JWT, hashage bcrypt des mots de passe
- 7 endpoints REST :
  - `POST /register`, `POST /login`, `GET /me`
  - `GET /destinations` (recherche par texte, tag, catégorie, quartier), `GET /destinations/{id}`, `GET /categories`
  - `GET /recommendations` (score pondéré : préférences × 3, affinité sorties passées × 1.5, popularité × 1)
  - `POST/GET/PUT/DELETE /itineraries` (création, consultation, modification, suppression, partage par email)
- Jeu de données : 26 lieux réels de Yaoundé (Monument de la Réunification, Mont Fébé, Marché Central, Marché Mokolo, Musée National, Zoo de Mvog-Betsi, Parc de la Méfou, restaurants, hôtels, etc.) répartis en 8 catégories, avec quartier, prix en FCFA, meilleur moment de visite

### Frontend (Flutter — Web, Mobile, Desktop)
- Architecture Provider (state management) + Dio (client HTTP) + shared_preferences (persistance du JWT)
- Détection automatique de l'URL du backend selon la plateforme (Web, Android émulateur, Windows/Desktop, appareil physique via IP LAN)
- Écrans : Connexion, Inscription (avec sélection des centres d'intérêt), Explorer (recherche + filtres par catégorie), Recommandations personnalisées (avec justification), Mes sorties (création multi-étapes, partage), Détail d'un lieu, Profil
- Composants réutilisables : `DestinationCard`
- Un seul code source pour les 3 plateformes cibles (`flutter build web|apk|windows`)

### Base de données (Phase 1)
- Stockage 100 % fichiers JSON (`destinations.json`, `users.json`, `itineraries.json`) — conforme à la spécification pédagogique de la Phase 1, qui exclut délibérément l'usage d'une base de données pour faire vivre aux étudiants les limites du JSON (absence de transactions, d'indexation, de gestion de la concurrence)

### Documentation
- `README.md` (backend) et `SETUP_GUIDE.md` (frontend) détaillant l'installation et le lancement sur les 3 plateformes

---

## Notes de version — Phase du projet

| Phase | Statut | Contenu |
|---|---|---|
| **Phase 1 — Monolithe** | ✅ Complétée | API REST unique, stockage JSON, Flutter multi-plateforme |
| **Phase 2 — Microservices** | ✅ Complétée et déployée en production | 5 services (user, itinerary, recommendation, ai, api-gateway), Docker Compose, connexion Google, assistant IA, carte, météo, avis, favoris, localisation |
| Phase 3 — Déploiement cloud | À venir | Conteneurisation avancée, load balancing, auto-scaling |
| Phase 4 — Résilience | À venir | Cache, files de messages, circuit breakers |

---

## Infrastructure actuelle (production)

| Composant | Emplacement | Détails |
|---|---|---|
| API Gateway | VPS Ubuntu, Docker Compose | `api-gateway`, port interne 4200 (inchangé depuis la Phase 1 pour compatibilité Nginx) |
| Microservices | Docker Compose (même hôte) | `user-service` (8001), `itinerary-service` (8002), `recommendation-service` (8003), `ai-service` (8004) |
| Assistant IA | `ai-service` | Gemini 2.5 Flash (gratuit), repli automatique vers OpenRouter (`openrouter/free`) |
| Reverse proxy | Nginx | HTTPS (Let's Encrypt), routage API + site statique, règles étendues aux routes Phase 2 |
| Domaine | `fahglobe.duckdns.org` | DNS dynamique DuckDNS |
| Site + téléchargements | `/var/www/GLOBE` | Vitrine, hub de téléchargement, app Flutter Web (dépôt Git séparé `TUHEU/GLOBE`) |
| Sauvegardes backend | `~/BACKEND-GLOBE-V2/backups/` | Automatiques à chaque `update.sh`, 10 dernières conservées |
| Dépôt de code (backend) | GitHub (`TUHEU/BACKEND-GLOBE`) | Historique nettoyé (`git filter-repo`) ; `git pull` automatique via `update.sh` |
| Dépôt de code (site) | GitHub (`TUHEU/GLOBE`) | Build Flutter Web + APK + zip Windows, mis à jour via son propre `update.sh` |