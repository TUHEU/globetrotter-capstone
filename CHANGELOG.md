# Changelog — GlobeTrotter Yaoundé

Projet capstone CS 4122 (Distributed Systems) — The ICT University

Superviseur : Eng. Mughe Godlove · Équipe : Fahdil, Nsangou Hamed Mochtar Ben Bilal

Ce changelog couvre tout le travail réalisé depuis le lancement du projet, de la Phase 1 (Monolithe) jusqu'à la Phase 2 (Microservices) en production.

---

## [2.20.0] — Communauté en temps réel, notifications & contribution des utilisateurs

### Ajouté

* **💬 Chat communautaire mondial en temps réel** (`chat-service`) : ajout d'un nouveau microservice dédié permettant aux utilisateurs connectés de communiquer dans un espace de discussion public commun.

  * Communication en temps réel via **WebSocket**
  * Historique des messages accessible aux utilisateurs
  * Compteur des utilisateurs actuellement connectés
  * Messages système lorsqu'un utilisateur rejoint ou quitte la discussion
  * Authentification des connexions utilisateur

* **📷 Partage de médias dans le chat communautaire** :

  * Messages texte
  * Partage d'images
  * Messages audio
  * Partage de vidéos
  * Partage de localisation
  * Téléversement de fichiers médias
  * Service des fichiers partagés via le backend

* **😀 Réactions aux messages** : possibilité pour les utilisateurs de réagir aux messages avec des emojis, avec synchronisation des réactions entre les participants connectés.

* **🗑️ Suppression de messages** : les utilisateurs peuvent supprimer leurs propres messages dans le chat communautaire.

* **🔌 Gestion des connexions WebSocket** : ajout d'un gestionnaire de connexions permettant de suivre les utilisateurs actifs et de diffuser les nouveaux événements à tous les participants du chat.

---

### 🗺️ Carte générale d'exploration

* **Nouvel écran "Explorer la carte"** (`ExploreMapScreen`) permettant de visualiser les destinations disponibles dans GlobeTrotter Yaoundé directement sur une carte interactive.

* Les utilisateurs peuvent désormais :

  * Voir plusieurs destinations simultanément sur la carte
  * Filtrer les lieux selon leurs catégories
  * Sélectionner un marqueur pour consulter un lieu
  * Accéder à la fiche détaillée d'une destination
  * Explorer Yaoundé visuellement sans dépendre uniquement des listes et de la recherche

* Réutilisation de l'infrastructure **MapLibre** déjà présente dans l'application afin de conserver une architecture cartographique cohérente.

---

### 📍 Contribution communautaire — Proposer un nouveau lieu

* **Nouvel écran "Proposer un lieu"** (`SubmitPlaceScreen`) permettant aux utilisateurs de contribuer directement au catalogue de destinations de GlobeTrotter Yaoundé.

* Les utilisateurs peuvent fournir :

  * Le nom du lieu
  * Une description
  * Une catégorie
  * Le quartier
  * Les coordonnées géographiques
  * Une photo du lieu

* Deux méthodes sont disponibles pour définir la position :

  * Utiliser la position GPS actuelle
  * Sélectionner directement une position sur la carte

* Ajout du téléversement d'images lors de la proposition d'une destination.

* Nouveau mécanisme backend pour recevoir et traiter les propositions de nouveaux lieux.

* Les destinations peuvent être rechargées dans l'Explorateur afin d'intégrer les nouvelles contributions sans nécessiter un redémarrage complet de l'application.

---

### 🔔 Système de notifications

* Ajout d'un nouveau système de notifications utilisateur dans l'architecture de GlobeTrotter.

* Nouvelles fonctionnalités :

  * Consultation des notifications personnelles
  * Compteur des notifications non lues
  * Marquage individuel d'une notification comme lue
  * Marquage de toutes les notifications comme lues

* Ajout d'un `NotificationsProvider` côté Flutter pour centraliser la gestion de l'état des notifications.

* Nouvel écran dédié à la consultation des notifications.

---

### 🏗️ Architecture

* Ajout du nouveau microservice :

  **`chat-service`**

* Ce service est spécialisé dans les communications communautaires en temps réel et permet de séparer la responsabilité du chat des autres services existants.

* Extension de l'architecture Gateway pour prendre en charge les communications liées au chat et aux connexions WebSocket.

---

### 📱 Améliorations Frontend

* Ajout de `GlobalChatScreen` pour le chat communautaire.
* Ajout de `ExploreMapScreen` pour l'exploration des destinations sur carte.
* Ajout de `SubmitPlaceScreen` pour les contributions communautaires.
* Ajout de `NotificationsScreen`.
* Intégration de WebSocket pour la réception instantanée des messages.
* Ajout de la gestion des médias dans les conversations.
* Ajout de réactions emoji.
* Ajout de fonctionnalités de partage de localisation.

---

### Infrastructure à finaliser pour la production

* Le nouveau système de chat nécessite une configuration correcte de l'infrastructure Docker et du reverse proxy afin de prendre en charge :

  * Le `chat-service`
  * Les connexions WebSocket
  * Les routes HTTP du chat
  * Le service des fichiers médias

* La configuration de production doit permettre aux connexions persistantes WebSocket de fonctionner correctement derrière Nginx et HTTPS.

---

## [2.19.0] — Graphiques d'activité sur le site vitrine

### Ajouté

* **3 graphiques en direct** sur le site vitrine (Chart.js, CDN, aucune étape de build) :

  * Courbe de croissance hebdomadaire des comptes et sorties créées, à partir du vrai `created_at` de chaque enregistrement
  * Répartition des lieux par catégorie
  * Lieux les plus populaires

* Toutes les données affichées sont réelles : aucun chiffre inventé pour remplir un graphique.

* Chaque graphique affiche un état vide honnête plutôt qu'un graphique cassé si les données ne sont pas encore disponibles.

* Extension des endpoints publics existants :

  * `/users/stats/public`
  * `/itineraries/stats/public`
  * `/destinations/stats/public`

  avec `weekly_growth`, `by_category` et `top_popular`.

* Les statistiques restent composées uniquement de compteurs agrégés et anonymes, sans données individuelles.

---

## [2.18.0] — Cinq nouvelles fonctionnalités & écran de chargement

### Ajouté

* **Écran de chargement "cheval au galop"** (`GallopingHorseLoader`) :

  * Silhouette entièrement dessinée avec `CustomPainter`
  * Aucune image externe
  * Les quatre jambes sont animées à différentes phases pour créer un véritable mouvement de galop
  * Rebond vertical synchronisé du corps
  * Remplace le `CircularProgressIndicator` générique au démarrage

* **Statistiques de voyage sur le Profil** (`TravelStatsCard`) :

  * Nombre de lieux uniques découverts
  * Nombre de quartiers uniques visités
  * Calcul à partir des données déjà chargées côté client
  * Aucun changement backend nécessaire
  * Nouveau badge **"Explorateur"** pour 15+ lieux

* **Avertissement météo sur une sortie** :

  * Réutilisation des données météo déjà chargées
  * Bannière indiquant les lieux concernés par la pluie

* **Devise d'affichage FCFA/USD/EUR** :

  * Préférence persistée via `SettingsProvider.currency`
  * Sélecteur dans les paramètres
  * Taux fixes et approximatifs
  * Préfixe `≈` pour éviter de donner une impression de précision garantie
  * FCFA reste la devise native des données stockées

* **Filtre de prix sur l'Explorateur** :

  * `min_price`
  * `max_price`
  * Interface de filtre côté Flutter
  * Tests backend pour les plages et limites

### Corrigé

* Fuite de contrôleurs dans la feuille de filtre de prix : correction des `TextEditingController` non disposés.

* `AchievementBadges` : passage à un affichage défilable horizontalement afin d'éviter les débordements sur les petits écrans.

---

## [2.17.0] — Statistiques publiques du site vitrine & corrections critiques

### Ajouté

* **Chiffres en direct sur la page d'accueil du site vitrine** :

  * Nombre de lieux
  * Nombre de catégories
  * Nombre d'explorateurs inscrits
  * Nombre de sorties créées

* Remplacement des anciens chiffres codés en dur devenus obsolètes.

* Trois nouvelles routes API publiques :

  * `GET /destinations/stats/public`
  * `GET /users/stats/public`
  * `GET /itineraries/stats/public`

* Les routes retournent uniquement des statistiques agrégées.

### Corrigé

* **`MESSAGES_FILE` utilisé mais jamais importé dans `user-service/app/storage.py`** :

  * Les fonctionnalités de conversation et de messagerie pouvaient provoquer une `NameError`.
  * Correction de l'import manquant.
  * Suite de tests vérifiée après correction.

* **Liste blanche Nginx incomplète** :

  * Les routes `/users`, `/follow` et `/messages` n'étaient pas correctement transmises à la Gateway.
  * Les fonctionnalités Découvrir, Suivre et Messagerie pouvaient tomber sur la page 404 du site vitrine.
  * Configuration de production à corriger sur le VPS.

---

## [2.16.0] — Optimisation d'itinéraire

### Ajouté

* **Bouton "Optimiser le trajet"** sur l'écran de création d'une sortie.

* Visible à partir de trois arrêts.

* Réorganisation des arrêts **jour par jour**, sans mélanger les jours définis par l'utilisateur.

* Utilisation d'un algorithme glouton du **plus proche voisin**.

* Conservation du premier arrêt comme point de départ.

* Réutilisation de `LocationService.haversineKm()`.

* Fonctionnement entièrement côté client sans nouvelle dépendance.

### Corrigé

* `create_itinerary_screen.dart` ne disposait pas correctement ses contrôleurs.

* Ajout de `dispose()` pour éviter les fuites mémoire.

---

## [2.15.0] — Planificateur de budget

### Ajouté

* **Budget prévu sur une sortie** (`budget_fcfa`, optionnel).

* Champ de saisie lors de la création d'une sortie.

* Comparaison automatique entre :

  * Le budget prévu
  * Le coût estimé des destinations

* Nouvelle carte **Budget** avec différents états visuels :

  * 🟢 Dans le budget
  * 🟠 Proche du budget
  * 🔴 Dépassement du budget

* Validation backend empêchant les budgets négatifs.

* Nouveaux tests ajoutés au `itinerary-service`.

---

## [2.14.0] — Photos réelles pour les 51 destinations

### Ajouté

* **51e destination** : Stade d'Olembé (Stade Omnisports Paul Biya).

* Photos réelles utilisées pour la grande majorité des destinations.

* Images stockées et servies depuis :

  `recommendation-service/static/images/`

* Ajout du service `StaticFiles`.

* Route `/static` prise en charge par l'API Gateway.

* Vérification individuelle des destinations et de leurs images.

### Corrigé

* **Hôpital Central et Hôpital Général utilisaient la même photo**.

  * L'image incorrecte a été retirée.
  * Un placeholder honnête a été conservé lorsqu'une image fiable n'était pas disponible.

* **Chemins d'images relatifs non correctement résolus**.

  * Correction via `ApiConstants.resolveImageUrl()`.

* **Photo incorrecte pour le Monument de la Réunification**.

  * Remplacement par une image vérifiée.

* **`.gitignore` excluait `recommendation-service/data/*.json`**.

  * `destinations.json` est désormais correctement suivi comme donnée de référence du projet.

### Refusé

* Utilisation d'images TripAdvisor rejetée pour éviter une violation potentielle du droit d'auteur.

---

## [2.13.0] — Assistant IA : fiabilité et vitesse

### Corrigé

* **Assistant IA perçu comme trop lent ou ne répondant pas**.

* Le délai HTTP global de 15 secondes était insuffisant pour certaines requêtes IA.

* `AssistantProvider.send()` utilise désormais un délai dédié de 60 secondes.

### Modifié

* Les appels de récupération du contexte :

  * Destinations
  * Itinéraires utilisateur

  sont désormais exécutés en parallèle avec `ThreadPoolExecutor`.

* Ajout du message :

  **"Encore un instant…"**

  après plusieurs secondes d'attente afin d'améliorer l'expérience utilisateur.

---

## [2.12.0] — Données des lieux : liens Google Maps & fabrications rejetées

### Ajouté

* **`maps_url` sur les destinations**.

* Bouton **"Voir sur Google Maps"** sur la fiche des lieux.

* Ouverture via `url_launcher`.

### Corrigé

* Deux jeux de données d'images non vérifiés ont été rejetés après contrôle.

* Les URLs prétendument Wikimedia et Google Photos n'étaient pas suffisamment fiables.

* Restauration de la dernière version fiable du catalogue.

* Les destinations sans images vérifiables ont conservé des placeholders honnêtes.

---

## [2.11.0] — Fiabilité VPS & sécurité

### Corrigé

* **Panne complète de `api-gateway` sur le VPS**.

* Le conteneur était arrêté mais `docker compose ps` pouvait masquer certains services arrêtés.

* Recommandation d'utiliser :

  `docker compose ps -a`

* Redémarrage de l'infrastructure avec Docker Compose.

### Sécurité

* Recommandation de définir une vraie `SECRET_KEY` dans `.env`.

* Recommandation de faire tourner les clés API potentiellement exposées.

* Éviter d'afficher les secrets directement avec `cat .env`.

---

## [2.10.0] — Cartes 3D sur le Web

### Corrigé

* **Carte vide sur le Web**.

* Ajout des ressources nécessaires à MapLibre GL JS dans `web/index.html`.

* Correction de l'erreur :

  `Target of URI doesn't exist: 'dart:js_util'`

* Migration vers :

  * `dart:js_interop`
  * `package:web`

* Utilisation d'importations conditionnelles pour séparer les fonctionnalités spécifiques au Web.

### Modifié

* Suppression définitive des anciennes dépendances :

  * `flutter_map`
  * `latlong2`

* Ajout de :

  `web: ^1.1.0`

---

## [2.9.0] — Découverte, navigation vers un lieu & corrections d'affichage

### Ajouté

* **Écran "Découvrir"** :

  * Consultation des utilisateurs de GlobeTrotter
  * Exclusion de l'utilisateur actuel
  * Exclusion des utilisateurs déjà suivis

* **Navigation depuis la position actuelle vers une sortie**.

* Bouton :

  **"Itinéraire depuis ma position"**

* Réutilisation de :

  * `DirectionsScreen`
  * Flèche boussole
  * OSRM

* Ajout de diagrammes d'architecture :

  * SVG interactif
  * Sources PlantUML

### Corrigé

* Images Web lentes ou donnant l'impression de ne pas se charger.

* Placeholder visible pendant le chargement.

* Ajout d'un mécanisme de réessai.

* Correction du bouton de langue qui ne recevait pas les événements tactiles à cause de l'ordre des widgets dans le `Stack`.

### Recherché

* Recherche d'images réelles supplémentaires pour plusieurs lieux.

* Les lieux sans source fiable ont conservé leurs placeholders.

---

## [2.8.0] — Qualité, données & infrastructure

### Ajouté

* Ajout de :

  * `founded_year`
  * `history`

  pour plusieurs destinations.

* Cache mémoire des images avec `NetworkImageSafe`.

* Ajout de :

  * `.gitignore`
  * `.env.example`

* Nouveau `update.sh` pour le site vitrine.

### Corrigé

* Suppression du doublon de technologies cartographiques.

* Uniformisation complète sur `maplibre_gl`.

* Correction des conflits de type `LatLng`.

* Correction de nombreux avertissements `flutter analyze`.

* Alignement du port de développement local sur **4200**.

* Correction d'un minuteur non annulé dans `NetworkImageSafe`.

* Correction d'importations et paramètres dupliqués dans `home_screen.dart`.

### Sécurité

* Recommandation de rotation des clés API potentiellement exposées.

---

## [2.7.0] — Navigation guidée & partage

### Ajouté

* **Flèche directionnelle boussole** (`DirectionArrow`).

* Navigation utilisant :

  * GPS en direct
  * Orientation de l'appareil
  * Direction vers la destination

* Instructions textuelles :

  * Continuez tout droit
  * Tournez à droite
  * Tournez à gauche
  * Faites demi-tour

* **Liens de partage profonds** pour les lieux et itinéraires.

* Intégration de la navigation dans `DirectionsScreen`.

---

## [2.6.0] — Réseau social : suivre, partager, communiquer

### Ajouté

* **Messagerie directe** (`user-service`).

* Boîte de réception.

* Conversations entre utilisateurs autorisés.

* Badge de messages non lus.

* **Likes et commentaires sur les sorties**.

* 14 nouvelles destinations, faisant évoluer le catalogue de **36 à 50 destinations**.

* Nouvelles catégories :

  * `health`
  * `transport`

### Corrigé

* Localisation d'ICT University corrigée vers Zoatoupsi/Messassi.

* Bouton de langue mobile amélioré.

* Bulle IA empêchée de recouvrir le contenu des listes.

* Correction de la connexion Google sur le Web.

---

## [2.5.0] — Bulle de langue déplaçable & corrections diverses

### Ajouté

* Sélecteur de langue transformé en bulle flottante.

* Appui simple :

  * Changement de langue

* Glissement :

  * Repositionnement de la bulle

### Corrigé

* Correction du `base-href` pour Flutter Web servi dans `/app/`.

* Correction d'un en-tête HTTP contenant des caractères non ASCII.

---

## [2.4.0] — Fonctionnalités communautaires

### Ajouté

* **Avis publics sur les destinations**.

* Notes de 1 à 5.

* Commentaires sur les lieux.

* **Lieux à proximité** utilisant la formule de Haversine.

* **Localisation en direct** avec `geolocator`.

* Point indiquant la position de l'utilisateur.

* Distances affichées sur les destinations.

* Coordonnées géographiques ajoutées aux destinations.

---

## [2.3.0] — Assistant IA conversationnel

### Ajouté

* Nouveau microservice :

  `ai-service`

* Assistant utilisant Gemini.

* Injection du contexte réel de GlobeTrotter dans les requêtes.

* **Fallback automatique vers OpenRouter**.

* Écran de conversation :

  `AssistantScreen`

* Bulle flottante accessible depuis l'application.

* Suggestions de questions au premier lancement.

---

## [2.2.0] — Favoris

### Ajouté

* Gestion des favoris :

  * `GET /favorites`
  * `POST /favorites`
  * `DELETE /favorites`

* Icône cœur sur les destinations.

* Mise à jour optimiste.

* Écran **Favoris** dédié.

* Statistiques de profil enrichies.

---

## [2.1.0] — Carte, météo, itinéraires piétons, connexion Google, avis sur l'app

### Ajouté

* Carte interactive.

* Affichage des arrêts d'un itinéraire.

* Trajets piétons avec OSRM.

* Distance et durée estimée.

* **Météo en direct** avec Open-Meteo.

* **Connexion Google** sur Web et Android.

* Vérification du jeton côté backend.

* **Avis sur l'application** :

  * Étoiles
  * Commentaires

### Modifié

* Migration de `google_sign_in` v6 vers v7.

* Adaptation des images de destinations pour le Web.

> **Note :** `flutter_map` a ensuite été retiré et remplacé par MapLibre dans les versions suivantes.

---

## [2.0.0] — Phase 2 : Microservices

### Ajouté

* Décomposition du monolithe en **5 services indépendants** :

  * `user-service`
  * `itinerary-service`
  * `recommendation-service`
  * `ai-service`
  * `api-gateway`

* Chaque service dispose de son propre stockage.

* Conteneurisation avec Docker.

* Orchestration avec **Docker Compose**.

* Nouveau système `update.sh` adapté au déploiement Docker.

### Modifié

* Migration complète du VPS.

* Remplacement de l'ancien système systemd de la Phase 1.

* API Gateway publiée sur le port **4200**.

* Configuration Nginx étendue pour les nouvelles routes.

* Migration des données de production vers la nouvelle architecture.

### Corrigé

* Cycle de dépendances circulaire dans `docker-compose.yml`.

* Dépendance `requests` manquante dans `user-service`.

### Sécurité

* Nettoyage de l'historique Git afin de supprimer des données utilisateur accidentellement committées.

* Mise en place de règles `.gitignore` pour empêcher de nouveaux commits de données sensibles.

---

## [1.6.0] — Thème & Langue

### Ajouté

* Thème :

  * Clair
  * Sombre
  * Système

* Préférences persistées localement.

* Palette visuelle dédiée.

* Système de traduction :

  * Français
  * Anglais

* Écran **Paramètres**.

* Sélecteur de langue visible dès l'écran de connexion.

* Nouveau dashboard sur l'onglet Explorer.

### Modifié

* `main.dart` charge les préférences au démarrage.

* Écrans principaux traduits.

* Les données du backend restent principalement en français.

### Corrigé

* Classe `_Glow` manquante.

* Amélioration du contraste des centres d'intérêt.

* Correction des URLs et du port de production.

---

## [1.5.0] — Déploiement production (VPS)

### Ajouté

* Guide complet de déploiement sur VPS Ubuntu.

* Utilisation de :

  * systemd
  * Nginx
  * Let's Encrypt

* Service systemd `fahglobe`.

* Reverse proxy pour :

  * Le site vitrine
  * L'API FastAPI

* HTTPS activé.

* Script `update.sh`.

* Script `restore.sh`.

### Modifié

* Ajout de `prodUrl` dans Flutter.

* Les builds de production utilisent automatiquement le backend hébergé.

### Corrigé

* Correction du nom du fichier Nginx.

* Correction d'un problème 403 lié au contenu du site.

* Correction des routes `/docs/`.

---

## [1.4.0] — Site de téléchargement / vitrine web

### Ajouté

* Site vitrine complet.

* Landing page.

* Hub de téléchargement.

* Présentation des fonctionnalités.

* Détection automatique de l'appareil :

  * Android
  * Windows
  * Autres plateformes

* Mockup de téléphone en CSS.

* Section fonctionnalités.

* Section communauté.

* Structure :

  * `app/`
  * `downloads/`

* Animations au scroll.

* Responsive mobile.

* Support de `prefers-reduced-motion`.

* Documentation `README_DEPLOY.md`.

### Design

* Palette bleu nuit et orange.

* Typographies :

  * Unbounded
  * Outfit
  * JetBrains Mono

---

## [1.3.0] — Icônes de l'application

### Ajouté

* Première série de concepts d'icônes inspirés du Cameroun :

  * Boussole
  * Les 7 Collines
  * Monument
  * Globe Afrique
  * Y Route

* Deuxième série de concepts bleu/orange.

* Collages prêts pour les votes WhatsApp.

* Sources SVG éditables.

---

## [1.2.0] — Amélioration du design (GUI)

### Ajouté

* Refonte complète de l'écran de connexion.

* Fond dégradé inspiré du Cameroun.

* Silhouette des collines de Yaoundé avec `CustomPainter`.

* Effets lumineux.

* Glassmorphism.

* Layout adaptatif :

  * Mobile
  * Web
  * Desktop

* Composants réutilisables :

  * `glassInput()`
  * `GradientButton`

* Animations d'entrée.

* Thème global amélioré.

---

## [1.1.0] — Questionnaire beta-testeurs

### Ajouté

* Questionnaire Google Form.

* Maximum de 10 questions.

* Versions française et anglaise.

* Questions sur :

  * Profil utilisateur
  * Habitudes de découverte
  * Catégories préférées
  * Fonctionnalités utilisées
  * Fonctionnalités futures
  * Frustrations
  * Plateforme préférée
  * Score de recommandation
  * Commentaires libres

* Grille d'exploitation des résultats pour la défense académique.

---

## [1.0.0] — Phase 1 : Le Monolithe (version initiale)

### Contexte projet

* Recentrage du projet générique **GlobeTrotter** vers :

  **GlobeTrotter Yaoundé**

* Transformation du concept de voyage international en guide local dédié à Yaoundé, Cameroun.

### Backend — FastAPI / Python

* Architecture monolithique.

* Un seul serveur backend.

* Stockage JSON volontairement utilisé dans le cadre pédagogique.

* `app/storage.py` :

  * Repository pattern
  * Écriture atomique
  * Fichiers temporaires
  * `threading.Lock`

* `app/security.py` :

  * JWT
  * Hashage bcrypt des mots de passe

* Endpoints REST pour :

  * Inscription
  * Connexion
  * Profil
  * Destinations
  * Catégories
  * Recommandations
  * Itinéraires

* Système de recommandations pondéré utilisant :

  * Préférences utilisateur
  * Sorties passées
  * Popularité

* Jeu de données initial composé de **26 lieux réels de Yaoundé**.

### Frontend — Flutter

* Application multi-plateforme :

  * Web
  * Mobile
  * Desktop

* Architecture Provider.

* Client HTTP Dio.

* Persistance avec `shared_preferences`.

* Détection automatique de l'URL backend selon la plateforme.

* Écrans :

  * Connexion
  * Inscription
  * Explorer
  * Recommandations
  * Mes sorties
  * Création d'itinéraires
  * Détail d'un lieu
  * Profil

* Composant réutilisable :

  `DestinationCard`

* Un seul code source pour les plateformes cibles.

### Stockage — Phase 1

* Stockage 100 % JSON :

  * `destinations.json`
  * `users.json`
  * `itineraries.json`

* Utilisation volontaire du stockage par fichiers afin d'illustrer les limites du modèle monolithique et préparer la transition vers l'architecture distribuée.

### Documentation

* `README.md` pour le backend.

* `SETUP_GUIDE.md` pour le frontend.

---

# Notes de version — Phase du projet

| Phase                           | Statut                  | Contenu                                                                                                                             |
| ------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Phase 1 — Monolithe**         | ✅ Complétée             | API REST unique, stockage JSON, Flutter multi-plateforme                                                                            |
| **Phase 2 — Microservices**     | ✅ Complétée et déployée | Architecture distribuée, Docker Compose, IA, cartes, météo, réseau social, messagerie, navigation et fonctionnalités communautaires |
| **Phase 3 — Déploiement cloud** | À venir                 | Conteneurisation avancée, load balancing, auto-scaling                                                                              |
| **Phase 4 — Résilience**        | À venir                 | Cache, files de messages, circuit breakers                                                                                          |

---

# Infrastructure actuelle

| Composant           | Emplacement                 | Détails                                                                          |
| ------------------- | --------------------------- | -------------------------------------------------------------------------------- |
| API Gateway         | VPS Ubuntu / Docker Compose | Point d'entrée principal de l'API                                                |
| Microservices       | Docker Compose              | Services spécialisés pour utilisateurs, itinéraires, recommandations, IA et chat |
| Assistant IA        | `ai-service`                | Gemini avec fallback OpenRouter                                                  |
| Chat communautaire  | `chat-service`              | Communication en temps réel via WebSocket                                        |
| Reverse Proxy       | Nginx                       | HTTPS et routage des services                                                    |
| Domaine             | DuckDNS                     | Domaine public du projet                                                         |
| Site vitrine        | `/var/www/GLOBE`            | Site de présentation et application Flutter Web                                  |
| Sauvegardes Backend | VPS                         | Sauvegardes automatiques avant les mises à jour                                  |
| Dépôt Backend       | GitHub                      | Code source de l'architecture backend                                            |
| Dépôt Site          | GitHub                      | Site vitrine et builds publics                                                   |

---

## GlobeTrotter Yaoundé — Évolution du projet

**GlobeTrotter Yaoundé** a évolué progressivement :

🚀 **Phase 1** — Application monolithique avec API REST et stockage JSON

🏗️ **Phase 2** — Migration vers une architecture distribuée basée sur les microservices

🤖 **Intelligence artificielle** — Assistant conversationnel avec contexte réel

🗺️ **Navigation** — Cartes interactives, météo et itinéraires

👥 **Réseau social** — Suivi, likes, commentaires et messagerie

💬 **Temps réel** — Chat communautaire avec WebSocket et partage de médias

🔔 **Notifications** — Gestion centralisée des événements utilisateur

📍 **Communauté** — Contribution des utilisateurs avec proposition de nouveaux lieux

🌍 **Vision** — Transformer GlobeTrotter Yaoundé en une plateforme complète permettant de découvrir, planifier, partager et vivre l'expérience de Yaoundé avec une véritable communauté d'explorateurs.
