# GlobeTrotter Yaoundé (Flutter) — Phase 1 Setup

## 1. Create the project (web + mobile + desktop in ONE codebase)
```bash
flutter create globetrotter --platforms=android,ios,web,windows
cd globetrotter
```
Then DELETE the generated `lib/` and replace it with the `lib/` from this zip.

## 2. Add dependencies to pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  dio: ^5.7.0
  shared_preferences: ^2.3.3
```
Then: `flutter pub get`

## 3. Run the backend first
```bash
cd globetrotter_backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## 4. Run each platform
```bash
flutter run -d chrome      # WEB
flutter run -d windows     # DESKTOP
flutter run                # MOBILE (emulator/device)
```

## Base URL logic (lib/core/constants.dart)
- Web & Desktop -> http://localhost:8000
- Android emulator -> http://10.0.2.2:8000 (automatic)
- Physical phone -> set `lanIp` in constants.dart to your PC's IP (ipconfig),
  and make sure phone + PC are on the same Wi-Fi.
