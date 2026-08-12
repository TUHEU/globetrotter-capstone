# Changelog — GlobeTrotter Yaoundé

Projet capstone CS 4122 (Distributed Systems) — The ICT University
Superviseur : Eng. Mughe Godlove · Équipe : Fahdil, Nsangou Hamed Mochtar Ben Bilal

Ce changelog couvre tout le travail réalisé depuis le lancement du projet,
de la Phase 1 (Monolithe) jusqu'à la Phase 2 (Microservices) en production.

---

## [2.13.0] — Assistant IA : fiabilité et vitesse
### Corrigé
- **"L'IA ne répond pas / répond lentement"** : le client HTTP global a un
  délai d'attente de 15s, pensé pour de simples appels REST (destinations,
  connexion...). Le pire cas côté serveur pour UN message à l'assistant
  pouvait légitimement dépasser ce délai : jusqu'à 5s pour récupérer les
  destinations + jusqu'à 5s pour les itinéraires de l'utilisateur (les deux
  À LA SUITE, pas en parallèle) + jusqu'à 20s pour Gemini + jusqu'à 20s de
  PLUS si Gemini échoue et qu'on bascule sur OpenRouter — jusqu'à 50s au
  total. Le client abandonnait souvent avant même que le serveur ait fini
  de générer une réponse pourtant valide, perçu comme "ne répond pas du
  tout" alors que la réponse arrivait simplement trop tard pour un appel
  déjà expiré. `AssistantProvider.send()` utilise désormais un délai dédié
  de 60s pour cet appel précis, sans toucher au délai des 15s ailleurs
  dans l'app

### Modifié
- `ai-service/app/clients.py` : les deux appels de "grounding" (destinations
  + itinéraires de l'utilisateur) tournent désormais EN PARALLÈLE
  (`ThreadPoolExecutor`) plutôt qu'à la suite — jusqu'à 5s de gagnées sur
  CHAQUE message, avant même d'atteindre Gemini/OpenRouter
- Bulle "en train d'écrire" (`AssistantScreen`) : affiche "Encore un
  instant…" après 6 secondes d'attente, pour qu'une réponse légitimement
  lente (normal pour une IA, surtout sur le chemin de repli OpenRouter) ne
  donne plus l'impression que l'app est plantée

---

## [2.12.0] — Données des lieux : liens Google Maps & fabrications rejetées
### Ajouté
- **`maps_url` sur les 50 destinations** + bouton "Voir sur Google Maps"
  sur la fiche de chaque lieu (`url_launcher`) : liens Google Maps réels,
  fournis un par un pour chaque lieu — contrairement aux photos (voir
  Corrigé ci-dessous), ceux-ci ouvrent directement l'app/le navigateur
  Google Maps avec de vraies photos, avis et itinéraires, sans qu'on ait
  besoin de les héberger ou de les vérifier nous-mêmes

### Corrigé (fabrications rejetées, sans changement de données)
- Deux nouveaux jeux de données d'images "prêts à coller" fournis pour les
  50 lieux, tous deux rejetés après vérification — même schéma que
  l'incident déjà documenté en v2.8.0 (fichier ChatGPT), mais à l'échelle
  du jeu de données complet cette fois :
  - Lot 1 : URLs `upload.wikimedia.org/wikipedia/commons/X/XY/...` — le
    préfixe `X/XY` correspond au hash MD5 réel du fichier calculé par les
    serveurs Wikimedia ; il ne peut pas être deviné. Confirmé cassé par
    l'utilisateur lui-même après application (plus aucune image nulle
    part, mobile inclus)
  - Lot 2 : URLs `lh3.googleusercontent.com/p/AF1Qip...` (format Google
    Photos) — le caractère juste après "AF1Qip" suivait l'ordre alphabé-
    tique puis numérique EXACT des 50 entrées (M→N→P...→Z→a→b...→9→10),
    la preuve qu'il s'agit d'un compteur habillé en identifiant, pas d'un
    vrai jeton opaque Google
  - `destinations.json` restauré à la dernière version fiable (17 photos
    Wikimedia vérifiées + 33 placeholders Unsplash honnêtes) dans les deux
    cas
- Recherches supplémentaires infructueuses pour Hôpital Central de
  Yaoundé, Bibliothèque Nationale, aéroport de Nsimalen : catégorie
  Wikimedia Commons existante par le NOM (référencée sur Wikidata) mais
  aucun fichier réel trouvé à l'intérieur — même signal d'alerte que
  Palais des Congrès (v2.8.0), laissés en placeholder plutôt que de
  deviner une URL

---

## [2.11.0] — Fiabilité VPS & sécurité
### Corrigé
- **Panne complète de `api-gateway` sur le VPS** (502 Bad Gateway sur
  tout le site, y compris `POST /auth/google` — d'abord suspecté à tort
  comme un problème de configuration Google Sign-In) : le conteneur
  s'était arrêté proprement (`Exited (0)`, aucune trace d'erreur/crash)
  et n'avait pas redémarré tout seul malgré `restart: unless-stopped` —
  cohérent avec un arrêt EXPLICITE (`docker stop`/`docker compose stop`)
  plutôt qu'un plantage, cette politique ne redémarre jamais un conteneur
  arrêté volontairement. `docker compose ps` (sans `-a`) masquait le
  problème en n'affichant que les conteneurs EN COURS D'EXÉCUTION,
  cachant totalement `api-gateway` de la liste plutôt que de le montrer
  arrêté. Résolu par `docker compose up --build -d`

### Sécurité
- `backend/.env` ne définissait pas `SECRET_KEY` (utilisé pour signer les
  JWT) — chaque service se rabattait silencieusement sur la valeur par
  défaut codée en dur dans le code source, visible par quiconque a accès
  au dépôt. Recommandé : générer une vraie valeur
  (`python3 -c "import secrets; print(secrets.token_hex(32))"`) - invalide
  toutes les sessions actives une fois appliqué, à faire en connaissance
  de cause
- Clés API (Gemini, OpenRouter) de nouveau collées en clair dans une
  conversation de travail (`cat .env`) — même recommandation de rotation
  qu'en v2.8.0 ; éviter `cat .env` pour vérifier qu'une clé est définie,
  préférer `grep -c "CLE=." .env` (affiche 1/0 sans jamais montrer la
  valeur)

---

## [2.10.0] — Cartes 3D sur le Web
### Corrigé
- **Carte vide sur le Web** (fonctionnait déjà sur mobile) : `maplibre_gl`
  dessine les cartes via la bibliothèque JavaScript MapLibre GL JS dans le
  navigateur — contrairement à Android/iOS, qui utilisent leurs propres
  bindings natifs. `web/index.html` ne chargeait jamais cette bibliothèque
  (absente du fichier depuis le début du projet, jamais remarqué car
  aucune erreur bruyante ne s'affichait). Ajout des deux balises
  `<script>`/`<link>` MapLibre GL JS (version 5.24.0, alignée sur
  `maplibre_gl: ^0.26.2`), avant `flutter_bootstrap.js` comme requis
- **`Target of URI doesn't exist: 'dart:js_util'`** (bloquait la
  compilation sur TOUTES les plateformes, pas seulement le Web) : le
  correctif d'images du Web (v2.9.0) utilisait `dart:js_util`, une
  bibliothèque qui n'existe que dans le SDK Dart compilé pour le Web —
  absente pour Android/iOS/Windows. Un `kIsWeb` est une vérification
  D'EXÉCUTION, pas une exclusion à la COMPILATION : chaque import doit se
  résoudre pour CHAQUE plateforme ciblée. Remplacé par `dart:js_interop` +
  `package:web` (le remplacement actuel, activement maintenu, documenté
  officiellement par Flutter) ; `network_image_safe_web.dart` extrait dans
  son propre fichier avec import conditionnel (`if (dart.library.html)`),
  même schéma que `google_web_button_web.dart` pour Google Sign-In

### Modifié
- `pubspec.yaml` : `flutter_map`/`latlong2` (déjà retirés en v2.8.0)
  étaient réapparus dans une version locale du fichier — retirés à
  nouveau ; ajout de `web: ^1.1.0` (nécessaire pour `dart:js_interop`)

---

## [2.9.0] — Découverte, navigation vers un lieu & corrections d'affichage
### Ajouté
- **Écran "Découvrir"** (`GET /users/discover`, user-service) : parcourir
  tout le monde utilisant l'app (hors soi-même et les personnes déjà
  suivies), sans avoir à taper une recherche — nouvel onglet dans l'écran
  Amis, complémentaire à la recherche par nom/email qui existait déjà
- **"Le chemin pour y aller" depuis une sortie enregistrée** : `Itinerary
  MapScreen` ne montrait que le trajet ENTRE les arrêts d'une sortie, jamais
  depuis la position actuelle de l'utilisateur jusqu'au premier arrêt.
  Ajout d'un bouton "Itinéraire depuis ma position" qui ouvre le même
  `DirectionsScreen` (flèche boussole + trajet OSRM en direct) déjà utilisé
  depuis la fiche d'un lieu
- Diagrammes d'architecture (SVG interactif + source PlantUML) documentant
  la pile complète : clients → Nginx → passerelle → 4 microservices (avec
  leur propre stockage) → API externes gratuites, plus le détail du
  déploiement (VPS, Docker Compose, dépôt du site séparé)

### Corrigé
- **Images qui ne s'affichaient pas / chargeaient lentement sur le Web**
  (fonctionnaient déjà correctement sur mobile) : pendant le chargement
  d'une image, `_WebImg` n'affichait RIEN — ni le placeholder, ni aucun
  indicateur — un espace vide facilement interprété comme "l'image ne
  s'affiche pas" alors qu'elle chargeait simplement encore. Le placeholder
  reste désormais visible jusqu'à confirmation du chargement (`onload`) ;
  ajout d'un filet de sécurité de 15s (bascule vers "appuyer pour
  réessayer") pour les requêtes qui ne se terminent jamais (ni succès ni
  échec), un cas qui pouvait laisser une image bloquée indéfiniment
- **Bouton de langue toujours injoignable au doigt sur l'écran de connexion**,
  malgré deux séries de correctifs précédentes (geste, taille de la zone de
  contact) — la cause réelle n'était pas dans le bouton lui-même : dans
  `AuthScaffold`, le bouton était placé AVANT le `SafeArea`/`SingleChild
  ScrollView` du formulaire dans le `Stack`. Ce dernier se dimensionne sur
  tout l'écran disponible (pas seulement la carte visible) et, arrivant
  après dans la liste des enfants, était peint ET testé au toucher PAR-DESSUS
  le bouton — absorbant chaque toucher avant qu'il n'atteigne le bouton en
  dessous, quels que soient les réglages de geste appliqués dans le bouton
  lui-même. Corrigé en plaçant le bouton en DERNIER enfant du `Stack`
  (explique aussi pourquoi il semblait "rester coincé à recouvrir du
  contenu" : impossible à faire glisser ailleurs puisqu'il ne recevait
  jamais l'évènement de glissement)

### Recherché (sans changement de code)
- Nouvelle recherche d'images réelles pour Boulangerie Calafatas,
  Supermarché Dôvv et Marché Artisanal (Tsinga) : adresses et historique
  confirmés, mais aucune photo Wikimedia Commons trouvée pour ces trois
  lieux — laissés en placeholder générique honnête plutôt que d'inventer
  une URL non vérifiée (voir la note de sécurité v2.8.0 sur le même sujet
  avec le fichier fourni par ChatGPT)

---

## [2.8.0] — Qualité, données & infrastructure
### Ajouté
- `founded_year` / `history` sur les destinations (année de fondation +
  bloc historique optionnel affiché sur la fiche lieu) — renseignés pour
  11 lieux avec sources vérifiées (Stade Omnisports : 1972, Université de
  Yaoundé I : 1962, ICT University : 2010, Hôpital Central : 1933, Palais
  des Congrès : 1982, Hilton Yaoundé : 1974, etc.)
- Cache mémoire des images (`NetworkImageSafe`) : une photo déjà vue durant
  la session se réaffiche instantanément (LRU, 150 entrées max) au lieu
  d'être re-téléchargée à chaque scroll ou changement d'écran — mobile
  uniquement, le Web s'appuie déjà sur le cache HTTP natif du navigateur
- `.gitignore` (absent du dépôt jusqu'ici) + `.env.example` (backend) :
  protège désormais `backend/.env` d'un commit accidentel
- `update.sh` pour le dépôt du site vitrine (`TUHEU/GLOBE`), jusque-là
  absent/non versionné — sauvegarde avant mise à jour, `git reset --hard
  origin/main` (au lieu d'un `git pull` simple, qui échouait dès qu'un
  artefact de build avait été modifié localement sans être commité),
  vérification des fichiers essentiels du build, contrôle du site en ligne

### Corrigé
- **Doublon de dépendance carte** : `flutter_map` (2D, tuiles plates) et
  `maplibre_gl` (3D) coexistaient ; la fiche d'un lieu (`destination_detail_
  screen.dart`) utilisait encore l'ancienne carte 2D pendant que le reste de
  l'app était déjà passé à la 3D — remplacée par le même `Map3DView` que les
  écrans d'itinéraire, `flutter_map`/`latlong2` retirés du projet
- **Conflit de type `LatLng`** : `maplibre_gl` et `latlong2` définissent
  chacun une classe nommée `LatLng`, non-interchangeables pour le
  compilateur — `directions_service.dart` utilisait celle de `latlong2`
  alors que tous les écrans cartographiques utilisaient déjà celle de
  `maplibre_gl`, provoquant des erreurs de compilation
  (`argument_type_not_assignable`) dans `itinerary_map_screen.dart` et
  `directions_screen.dart`. Uniformisé sur `maplibre_gl` partout
- **23 signalements `flutter analyze`** (niveau info, aucune erreur) :
  commentaires de documentation interprétés comme du HTML, `BuildContext`
  utilisé après un `await` sans vérifier `mounted` (9 occurrences —
  `main.dart`, `create_itinerary_screen.dart`, `friends_screen.dart`,
  `home_screen.dart`, `reviews_screen.dart`), paramètres de callback
  `(_, __)` simplifiés en `(_, _)`, `didUpdateWidget` renommé pour
  correspondre à la convention Flutter, syntaxe d'éléments null-aware
  modernisée (`'tag': ?tag`)
- **Port de développement local incohérent** : `docker compose up --build`
  publie la passerelle sur le port **4200** (aligné sur Nginx en
  production), mais `ApiConstants.baseUrl` ciblait encore le port 8000 en
  mode développement — corrigé pour utiliser 4200 partout ; documentation
  (`README.md`, `backend/README.md`, `SETUP_GUIDE.md`) mise à jour en
  conséquence
- **Minuteur en fuite dans `NetworkImageSafe`** (faisait échouer 4 tests
  widgets avec `A Timer is still pending even after the widget tree was
  disposed`) : la requête Dio et le délai de réessai n'étaient jamais
  annulés à la destruction du widget — ajout d'un `CancelToken` et d'un
  `Timer` de réessai explicitement annulables dans `dispose()`
- `undefined_identifier: ScrollDirection` et paramètre `padding` dupliqué
  dans `home_screen.dart`, introduits lors de l'ajout du masquage de la
  bulle IA au défilement — import manquant ajouté, les deux `padding:`
  fusionnés en un seul `EdgeInsets.fromLTRB`

### Sécurité
- Deux clés API (Gemini, OpenRouter) collées en clair dans une conversation
  de travail — rotation recommandée par précaution, indépendamment du
  `.gitignore` qui ne protège que les commits futurs, pas l'historique déjà
  potentiellement exposé

---

## [2.7.0] — Navigation guidée & partage
### Ajouté
- **Flèche directionnelle boussole** (`DirectionArrow`, `flutter_compass`) :
  pointe en permanence vers la destination quelle que soit l'orientation du
  téléphone (cap absolu vers la cible moins cap actuel de l'appareil),
  avec indication textuelle ("Continuez tout droit" / "Tournez à droite" /
  "à gauche" / "Faites demi-tour"). Position GPS suivie en direct
  (`LocationService.watchPosition`) pendant la navigation, plus seulement
  au chargement de l'écran. Repli sur le cap brut (sans rotation par
  rapport au téléphone) si aucun magnétomètre n'est disponible
- **Liens de partage profonds** : partager un lieu ou une sortie inclut
  désormais un lien (`fahglobe.duckdns.org/app/#/d/<id>` ou `#/i/<id>`) qui
  ouvre l'app directement sur le bon écran. Format en fragment d'URL (`#`)
  choisi pour fonctionner sans aucune modification de la configuration
  Nginx (le fragment n'est jamais envoyé au serveur) ; ouverture directe
  dans l'app installée (Android App Links / iOS Universal Links) non
  configurée — nécessite en plus une empreinte de signature et un fichier
  hébergé côté serveur, non mis en place pour l'instant
- Bulle "flèche boussole" intégrée à la barre d'info trajet de
  `DirectionsScreen`, visible aussi bien en regardant la carte que la
  liste des instructions

---

## [2.6.0] — Réseau social : suivre, partager, communiquer
### Ajouté
- **Messagerie directe** (`user-service`) : `GET /messages/inbox`,
  `GET/POST /messages/{other_user_id}` — accès restreint aux personnes
  qu'on suit ou qui nous suivent (pas de message à un inconnu trouvé via
  la recherche). Écrans **Boîte de réception** et **Conversation**
  (bulles de discussion, envoi optimiste), badge de messages non lus sur
  l'onglet Sorties
- **Commentaires et likes sur les sorties** (`itinerary-service`) :
  `POST /itineraries/{id}/like` (bascule), `GET/POST /itineraries/{id}/
  comments`, `DELETE .../comments/{comment_id}` (auteur uniquement).
  `like_count` / `liked_by_me` / `comment_count` renvoyés sur toutes les
  routes d'itinéraires (mes sorties, fil des amis, sorties publiques d'un
  ami, fiche détaillée). Barre "like + commentaires" (`LikeCommentBar`) et
  feuille de commentaires (`CommentsSheet`) réutilisées sur le fil des
  amis et dans l'onglet Mes sorties
- 14 nouvelles destinations (36 → 50) : écoles secondaires (Lycée
  Général-Leclerc, Collège Jean-Tabi, Collège François-Xavier-Vogt, Bitame
  Lucia International School), hôpitaux, aéroport de Nsimalen, Mosquée
  Centrale, Institut Français, Marché Mvog-Mbi, etc. Catégories `health`
  et `transport` ajoutées à `PlaceCategories`

### Corrigé
- **Localisation d'ICT University** : le lieu était enregistré à Mendong ;
  corrigé vers Zoatoupsi/Messassi (coordonnées vérifiées), conforme à
  l'adresse réelle
- **Bouton de langue injoignable au doigt sur mobile** (fonctionnait à la
  souris) : le geste de glisser (`GestureDetector.onPan*`) perdait
  systématiquement l'arène de gestes face au `SingleChildScrollView` en
  arrière-plan sur écran tactile — remplacé par un `Listener` (événements
  de pointeur bruts, hors arène de gestes), zone de contact invisible
  agrandie (52px → ~76px) et `HitTestBehavior.opaque`
- **Bulle IA flottante recouvrant le contenu en fin de liste** : marge
  basse ajoutée sur les listes des 4 onglets, et la bulle se masque
  désormais automatiquement pendant un défilement actif vers le bas
  (réapparaît au défilement vers le haut ou à l'arrêt)
- **Connexion Google bloquée sur le Web** ("Getting ready" indéfiniment,
  quel que soit le port/l'origine testés) : `google_sign_in_web` lève une
  assertion si `serverClientId` est fourni sur le Web (paramètre réservé à
  Android/iOS) — notre code le passait sur toutes les plateformes sans
  distinction, faisant échouer `initialize()` à chaque tentative. Corrigé
  (`serverClientId: kIsWeb ? null : ...`) ; bouton Web désormais construit
  via un `FutureBuilder` qui attend la fin réelle de l'initialisation
  avant d'appeler `renderButton()`, pour éliminer aussi une course
  possible entre les deux

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

> **Note (v2.8.0)** : `flutter_map` a depuis été entièrement retiré du
> projet (voir Corrigé, v2.8.0) — la carte s'appuie désormais uniquement
> sur `maplibre_gl` (rendu 3D), y compris sur la fiche d'un lieu.

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
| **Phase 2 — Microservices** | ✅ Complétée et déployée en production | 5 services (user, itinerary, recommendation, ai, api-gateway), Docker Compose, connexion Google, assistant IA, carte 3D, météo, avis, favoris, localisation, réseau social (suivi, messagerie, commentaires/likes), navigation guidée, liens de partage profonds |
| Phase 3 — Déploiement cloud | À venir | Conteneurisation avancée, load balancing, auto-scaling |
| Phase 4 — Résilience | À venir | Cache, files de messages, circuit breakers |

---

## Infrastructure actuelle (production)

| Composant | Emplacement | Détails |
|---|---|---|
| API Gateway | VPS Ubuntu, Docker Compose | `api-gateway`, port interne 4200 (inchangé depuis la Phase 1 pour compatibilité Nginx). En local, `docker compose up --build` publie désormais aussi sur 4200 (aligné avec la prod depuis v2.8.0) |
| Microservices | Docker Compose (même hôte) | `user-service` (8001), `itinerary-service` (8002), `recommendation-service` (8003), `ai-service` (8004) |
| Assistant IA | `ai-service` | Gemini 2.5 Flash (gratuit), repli automatique vers OpenRouter (`openrouter/free`) |
| Reverse proxy | Nginx | HTTPS (Let's Encrypt), routage API + site statique, règles étendues aux routes Phase 2 |
| Domaine | `fahglobe.duckdns.org` | DNS dynamique DuckDNS |
| Site + téléchargements | `/var/www/GLOBE` | Vitrine, hub de téléchargement, app Flutter Web (dépôt Git séparé `TUHEU/GLOBE`), déployé via son propre `update.sh` (v2.8.0) |
| Sauvegardes backend | `~/BACKEND-GLOBE-V2/backups/` | Automatiques à chaque `update.sh`, 10 dernières conservées |
| Sauvegardes site | `/var/www/GLOBE_backups/` | Automatiques à chaque `update.sh` du site, 10 dernières conservées |
| Dépôt de code (backend) | GitHub (`TUHEU/BACKEND-GLOBE`) | Historique nettoyé (`git filter-repo`) ; `.gitignore` + `.env.example` (v2.8.0) ; `git pull` automatique via `update.sh` |
| Dépôt de code (site) | GitHub (`TUHEU/GLOBE`) | Build Flutter Web + APK + zip Windows, mis à jour via son propre `update.sh` |
| Vérification de conteneurs | VPS | `docker compose ps -a` (inclut les conteneurs ARRÊTÉS) recommandé plutôt que `docker compose ps` seul, qui masque un service tombé silencieusement (voir v2.11.0) |