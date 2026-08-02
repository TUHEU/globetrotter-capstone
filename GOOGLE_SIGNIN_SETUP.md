# Configurer Google Sign-In — Guide étape par étape

Le code est prêt (backend + frontend), mais Google Sign-In a besoin d'un
**Client ID OAuth** que toi seul peux créer (il est lié à ton propre projet
Google Cloud, personne d'autre ne peut le générer à ta place).

## 1. Créer le projet Google Cloud (5 min)

1. Va sur https://console.cloud.google.com
2. Crée un nouveau projet, ex: "GlobeTrotter Yaounde"
3. Menu → **APIs & Services** → **Écran de consentement OAuth**
   - Type : Externe
   - Nom de l'app : GlobeTrotter Yaoundé
   - Email de support + logo (utilise `assets/icon/app_icon.png`)
   - Champs d'application : `email`, `profile` (déjà ceux qu'on demande dans le code)

## 2. Créer le Client ID "Web" (nécessaire pour la version Web ET comme clé de vérification côté backend)

**APIs & Services → Identifiants → + Créer des identifiants → ID client OAuth**
- Type d'application : **Application Web**
- Nom : GlobeTrotter Web
- Origines JavaScript autorisées :
  ```
  https://fahglobe.duckdns.org
  http://localhost:8080
  ```
- Aucune URI de redirection nécessaire (le SDK gère ça en popup)
- Clique Créer → **copie le Client ID** (`xxxxx.apps.googleusercontent.com`)

## 3. Créer le Client ID "Android" (pour l'APK)

Il faut d'abord ton empreinte SHA-1. Sur ton PC, dans le dossier du projet Flutter :

```bash
cd android
./gradlew signingReport
```

Cherche la ligne `SHA1:` sous `Variant: debug` (pour tester) et `Variant: release` (pour l'APK final que tu distribues — il te faudra une vraie clé de signature pour ça, pas la clé debug).

**Identifiants → + Créer des identifiants → ID client OAuth**
- Type : **Android**
- Nom du package : celui de ton `android/app/build.gradle` (`applicationId`, ex: `com.example.globetrotter`)
- Empreinte SHA-1 : celle obtenue ci-dessus

Pas besoin de copier ce Client ID dans le code Flutter — Google Play Services le retrouve automatiquement via le nom de package + SHA-1.

## 4. Mettre les Client IDs dans le projet

### Backend — sur le VPS, dans le `.env` à côté de `docker-compose.yml` :
```
GOOGLE_CLIENT_IDS=WEB_CLIENT_ID.apps.googleusercontent.com,ANDROID_CLIENT_ID.apps.googleusercontent.com
```
(les deux séparés par une virgule, sans espace)

### Frontend — `lib/core/constants.dart` :
```dart
static const String googleWebClientId = 'WEB_CLIENT_ID.apps.googleusercontent.com';
```
(uniquement le Client ID **Web**, même pour builder l'APK Android — c'est normal, le SDK s'en sert différemment selon la plateforme)

### Web — `web/index.html` (le fichier généré par `flutter create`, pas dans ce zip)
Ajoute dans le `<head>` :
```html
<meta name="google-signin-client_id" content="WEB_CLIENT_ID.apps.googleusercontent.com">
```

## 5. Rebuild et redéploie

```bash
flutter clean && flutter pub get
flutter build web --release --base-href /app/
flutter build apk --release
```
Puis renvoie ces builds vers `/var/www/GLOBE/` comme d'habitude, et redémarre le backend avec le nouveau `.env` (`docker compose up -d --build`).

## ⚠️ Windows Desktop — non couvert dans cette passe

Le package `google_sign_in` ne supporte pas nativement Windows Desktop (seulement Android, iOS, Web). Sur la version Windows de l'app, seul le formulaire email/mot de passe fonctionnera pour l'instant. Une solution existe (flux OAuth via navigateur + petit serveur local pour récupérer le callback) mais c'est un chantier à part — dis-le-moi si tu veux qu'on s'y attaque.

## Test rapide une fois configuré

```bash
curl -I https://fahglobe.duckdns.org/auth/google
```
Doit répondre (même en erreur 405 "Method Not Allowed" pour un GET, c'est normal — ça prouve juste que la route existe). Le vrai test se fait depuis l'app : bouton "Continuer avec Google" → sélecteur de compte Google → retour dans l'app connecté.
