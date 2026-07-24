# Changelog — GlobeTrotter Yaoundé

Projet capstone CS 4122 (Distributed Systems) — The ICT University
Superviseur : Eng. Mughe Godlove · Équipe : Fahdil, Nsangou Hamed Mochtar Ben Bilal

Ce changelog couvre tout le travail réalisé depuis le lancement du projet,
de la Phase 1 (Monolithe) jusqu'à la mise en production.

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
| **Phase 1 — Monolithe** | ✅ Complétée et déployée en production | API REST unique, stockage JSON, Flutter multi-plateforme |
| Phase 2 — Microservices | À venir | Décomposition en services, introduction de MySQL |
| Phase 3 — Déploiement cloud | À venir | Conteneurisation, load balancing, auto-scaling |
| Phase 4 — Résilience | À venir | Cache, files de messages, circuit breakers |

---

## Infrastructure actuelle (production)

| Composant | Emplacement | Détails |
|---|---|---|
| Backend API | VPS Ubuntu, service systemd `fahglobe` | Gunicorn + Uvicorn workers, port interne 4200 |
| Reverse proxy | Nginx | HTTPS (Let's Encrypt), routage API + site statique |
| Domaine | `fahglobe.duckdns.org` | DNS dynamique DuckDNS |
| Site + téléchargements | `/var/www/GLOBE` | Vitrine, hub de téléchargement, app Flutter Web |
| Sauvegardes | `/root/BACKEND-GLOBE/backups/` | Automatiques à chaque `update.sh`, 10 dernières conservées |
| Dépôt de code (backend) | GitHub (`TUHEU/BACKEND-GLOBE`) | Permet `git pull` automatique via `update.sh` |
