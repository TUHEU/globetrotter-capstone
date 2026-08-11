import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/app_strings.dart';
import '../core/constants.dart';
import '../models/user.dart';
// Import conditionnel : sur le Web (dart.library.html disponible), utilise
// la vraie implémentation avec google_sign_in_web ; sur TOUTE autre
// plateforme (Android, Windows, iOS), utilise le stub à la place. Sans ça,
// Android/Windows ne compilent plus du tout - c'était le bug qui a cassé
// `flutter build apk` et `flutter build windows`.
import '../services/google_web_button_stub.dart'
    if (dart.library.html) '../services/google_web_button_web.dart' as google_web;

class AuthProvider extends ChangeNotifier {
  User? user;
  bool loading = false;

  /// Exception brute de la dernière tentative échouée (login/register).
  /// On ne mémorise PAS de message texte à l'avance : le message est
  /// recalculé à l'affichage via [errorMessage], pour toujours refléter
  /// la langue actuellement sélectionnée (même si l'utilisateur change
  /// de langue après l'échec).
  Object? _lastException;

  bool get isLoggedIn => user != null;
  bool get hasError => _lastException != null;

  /// Message d'erreur localisé pour la dernière tentative échouée.
  /// Appeler avec `context.watch<SettingsProvider>().s` au moment de l'affichage.
  String? errorMessage(AppStrings s) {
    if (_lastException == null) return null;
    return ApiClient.errorMessage(_lastException!, s);
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('token') == null) return false;
    try {
      final res = await ApiClient.instance.dio.get('/me');
      user = User.fromJson(res.data);
      notifyListeners();
      return true;
    } catch (_) {
      await prefs.remove('token');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    return _authCall('/login', {'email': email, 'password': password});
  }

  Future<bool> register(String fullName, String email, String password, List<String> preferences) async {
    return _authCall('/register', {
      'full_name': fullName,
      'email': email,
      'password': password,
      'preferences': preferences,
    });
  }

  bool _googleInitialized = false;
  Future<void>? _googleInitFuture;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEventsSub;

  /// true sur Android/iOS/desktop (bouton "maison" + authenticate() marche) ;
  /// false sur Flutter Web, où Google EXIGE que le bouton soit dessiné par
  /// son propre SDK (contrainte anti-popup-blocker des navigateurs) - dans
  /// ce cas l'UI doit afficher [buildWebGoogleButton] à la place d'un bouton
  /// personnalisé, et le résultat arrive via authenticationEvents plutôt
  /// qu'en valeur de retour.
  ///
  /// IMPORTANT : sur Windows, il n'existe AUCUNE implémentation de
  /// google_sign_in du tout (contrairement au Web, qui a une implémentation
  /// qui répond juste "non supporté") - appeler supportsAuthenticate() ou
  /// initialize() y lève une exception plutôt que de renvoyer false. On
  /// protège donc cet accès pour ne jamais planter l'écran de connexion.
  bool get supportsGoogleButtonTap {
    try {
      return GoogleSignIn.instance.supportsAuthenticate();
    } catch (_) {
      return false;
    }
  }

  /// true uniquement sur les plateformes où une forme de Google Sign-In est
  /// réellement disponible (Web ou Android/iOS) - false sur Windows/Linux/
  /// macOS desktop, où le paquet n'a aucune implémentation native. Sert à
  /// masquer complètement le bloc Google Sign-In sur ces plateformes plutôt
  /// que d'afficher un bouton qui plantera au clic.
  bool get isGoogleSignInAvailable {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Point d'entrée PUBLIC pour initialiser le SDK Google Sign-In tôt, dès
  /// le démarrage de l'app (voir main.dart::_BootstrapState._init) plutôt
  /// que d'attendre qu'un widget en ait besoin.
  ///
  /// Pourquoi c'est nécessaire précisément sur le Web : [loginWithGoogle]
  /// (utilisé sur Android/iOS) appelle déjà _ensureGoogleInitialized() lui-
  /// même avant de s'authentifier - mais le bouton Web ([buildWebGoogleButton])
  /// ne "clique" jamais vers notre code : c'est le SDK Google qui dessine et
  /// gère lui-même tout le bouton via `renderButton()`. Sans appeler
  /// initialize() AVANT ce rendu, le SDK n'a jamais reçu notre Client ID et
  /// le bouton reste bloqué indéfiniment sur son texte de chargement interne
  /// ("Getting ready") - quel que soit le port/origine utilisé, puisque le
  /// blocage se produit avant même la vérification d'origine par Google.
  Future<void> ensureGoogleReady() => _ensureGoogleInitialized();

  /// v7 de google_sign_in impose un singleton (`GoogleSignIn.instance`) qui
  /// DOIT être initialisé une seule fois avant tout appel — contrairement à
  /// v6 où on créait une instance à chaque connexion.
  Future<void> _ensureGoogleInitialized() async {
    // Idempotent ET sûr en cas d'appels concurrents (ex: l'appel fait au
    // démarrage de l'app dans main.dart et un tap utilisateur très rapide
    // sur loginWithGoogle() qui arriveraient tous les deux avant la fin du
    // premier appel) : le deuxième appelant attend simplement le MÊME
    // Future au lieu de relancer une seconde initialisation en parallèle.
    if (_googleInitialized) return;
    if (_googleInitFuture != null) return _googleInitFuture;
    final future = _doInitializeGoogle();
    _googleInitFuture = future;
    return future;
  }

  Future<void> _doInitializeGoogle() async {
    await GoogleSignIn.instance.initialize(
      // Web : identifie l'app auprès de Google (Client ID "Web").
      clientId: ApiConstants.googleWebClientId.isNotEmpty
          ? ApiConstants.googleWebClientId
          : null,
      // serverClientId : Android/iOS UNIQUEMENT - google_sign_in_web lève une
      // assertion ("serverClientId is not supported on Web") si on le passe
      // sur Web, ce qui faisait échouer initialize() à CHAQUE appel et
      // laissait le bouton bloqué indéfiniment sur "Getting ready", peu
      // importe l'origine/le port ou l'ordre d'appel (voir les correctifs
      // précédents - aucun n'avait de chance de marcher tant que cette
      // assertion faisait échouer l'initialisation elle-même). Sur mobile,
      // ce paramètre sert à obtenir un idToken audiencé pour NOTRE Client ID
      // Web plutôt que pour le Client ID Android/iOS, pour que le backend
      // n'ait besoin de faire confiance qu'à une seule audience.
      serverClientId: kIsWeb
          ? null
          : (ApiConstants.googleWebClientId.isNotEmpty
              ? ApiConstants.googleWebClientId
              : null),
    );
    _googleInitialized = true;

    // Sur le Web, le bouton est dessiné par le SDK Google lui-même (pas par
    // notre code) - on ne reçoit donc JAMAIS de valeur de retour d'un appel
    // direct. Le résultat de la connexion arrive uniquement via ce flux
    // d'événements, qu'on écoute une seule fois ici, dès l'initialisation.
    _googleEventsSub?.cancel();
    _googleEventsSub = GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _completeGoogleLogin(event.user);
        }
      },
      onError: (Object e) {
        _lastException = e;
        loading = false;
        notifyListeners();
      },
    );
  }

  /// Widget du bouton Google officiel, à utiliser UNIQUEMENT quand
  /// [supportsGoogleButtonTap] est false (Web). Le résultat du clic sur ce
  /// bouton remonte via authenticationEvents, pas via une valeur de retour -
  /// voir _ensureGoogleInitialized ci-dessus. API confirmée depuis la doc
  /// officielle du paquet (pub.dev/documentation/google_sign_in_web).
  ///
  /// CORRECTION : ce widget attend maintenant explicitement la fin de
  /// _ensureGoogleInitialized() via FutureBuilder avant d'appeler
  /// renderGoogleWebButton(). Avant ce correctif, le bouton était rendu
  /// IMMÉDIATEMENT, sans attendre - et comme l'appel d'initialisation
  /// lancé au démarrage (main.dart) est volontairement non-bloquant (pour
  /// ne pas retarder l'affichage de l'écran de connexion), rien ne
  /// garantissait qu'il ait fini avant que ce widget soit construit. Le
  /// SDK Google (`google.accounts.id.renderButton`, au niveau JS) semble
  /// exiger que l'initialisation soit déjà terminée AU MOMENT de l'appel
  /// de rendu - appelé trop tôt, le bouton reste bloqué indéfiniment sur
  /// son texte de chargement interne ("Getting ready"), sans jamais se
  /// corriger tout seul même une fois l'initialisation terminée derrière.
  Widget buildWebGoogleButton() {
    if (!kIsWeb) return const SizedBox.shrink();
    return FutureBuilder<void>(
      // ensureGoogleReady() est mis en cache (_googleInitFuture) - donc si
      // l'appel de démarrage dans main.dart a déjà fini, ce FutureBuilder
      // se résout quasi instantanément ; sinon, il attend la même requête
      // déjà en cours plutôt que d'en relancer une deuxième.
      future: ensureGoogleReady(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          // Erreur réseau/config - pas de crash, juste pas de bouton Google.
          // L'utilisateur garde le formulaire email/mot de passe.
          return const SizedBox.shrink();
        }
        return google_web.renderGoogleWebButton();
      },
    );
  }

  Future<void> _completeGoogleLogin(GoogleSignInAccount account) async {
    loading = true;
    _lastException = null;
    notifyListeners();
    try {
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('Google n\'a renvoyé aucun jeton d\'identité.');
      }
      final res = await ApiClient.instance.dio.post('/auth/google', data: {
        'id_token': idToken,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', res.data['access_token']);
      user = User.fromJson(res.data['user']);
    } catch (e) {
      _lastException = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Connexion via Google Sign-In sur les plateformes où un bouton "maison"
  /// + authenticate() fonctionne (Android, iOS). Sur Web, utiliser
  /// [buildWebGoogleButton] à la place - voir supportsGoogleButtonTap.
  Future<bool> loginWithGoogle() async {
    loading = true;
    _lastException = null;
    notifyListeners();
    try {
      await _ensureGoogleInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      await _completeGoogleLogin(account);
      return _lastException == null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // L'utilisateur a fermé la fenêtre Google sans choisir de compte —
        // ce n'est pas une erreur à afficher, juste une annulation silencieuse.
        return false;
      }
      // Journalisé explicitement : sans ça, l'UI affiche seulement le
      // message générique "Something went wrong" (ApiClient.errorMessage
      // ne sait rien faire d'un GoogleSignInException, qui n'est pas un
      // DioException) - impossible de savoir QUEL code d'erreur Google a
      // réellement renvoyé (config Android incorrecte ? empreinte SHA-1 ?
      // Play Services indisponible ?) sans regarder ici.
      debugPrint('[GoogleSignIn] ${e.code} — ${e.description}');
      _lastException = e;
      return false;
    } catch (e) {
      debugPrint('[GoogleSignIn] Unexpected error: $e');
      _lastException = e;
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> _authCall(String path, Map<String, dynamic> body) async {
    loading = true;
    _lastException = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.post(path, data: body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', res.data['access_token']);
      user = User.fromJson(res.data['user']);
      return true;
    } catch (e) {
      _lastException = e;
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _googleEventsSub?.cancel();
    super.dispose();
  }
}
