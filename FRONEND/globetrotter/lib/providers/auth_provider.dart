import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/app_strings.dart';
import '../core/constants.dart';
import '../models/user.dart';

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
  /// Appeler avec context.watch<SettingsProvider>().s au moment de l'affichage.
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

  /// v7 de google_sign_in impose un singleton (`GoogleSignIn.instance`) qui
  /// DOIT être initialisé une seule fois avant tout appel — contrairement à
  /// v6 où on créait une instance à chaque connexion.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      // Web : identifie l'app auprès de Google (Client ID "Web").
      clientId: ApiConstants.googleWebClientId.isNotEmpty
          ? ApiConstants.googleWebClientId
          : null,
      // serverClientId (Web + Android) : force l'idToken renvoyé à être
      // audiencé pour NOTRE Client ID Web, quelle que soit la plateforme —
      // notre backend n'a alors besoin de faire confiance qu'à UN seul
      // audience plutôt que de whitelister Web ET Android séparément.
      serverClientId: ApiConstants.googleWebClientId.isNotEmpty
          ? ApiConstants.googleWebClientId
          : null,
    );
    _googleInitialized = true;
  }

  /// Connexion via Google Sign-In. Ouvre le sélecteur de compte natif,
  /// récupère le idToken signé par Google, et l'envoie au backend
  /// (POST /auth/google) qui le vérifie et renvoie NOTRE propre JWT —
  /// exactement comme après un login classique. Le reste de l'app ne
  /// voit aucune différence entre un compte Google et un compte email/mdp.
  Future<bool> loginWithGoogle() async {
    loading = true;
    _lastException = null;
    notifyListeners();
    try {
      await _ensureGoogleInitialized();

      // NOTE plateforme : sur Flutter Web, Google exige que le flux de
      // connexion soit déclenché par un bouton dessiné par leur propre SDK
      // (contrainte anti-popup-blocker du navigateur), pas un bouton
      // "maison" comme le nôtre. authenticate() reste néanmoins l'API
      // correcte à appeler ; si jamais le popup ne s'ouvre pas sur Web,
      // ce sera le signe qu'il faut migrer vers leur bouton natif — à
      // surveiller lors des tests, pas bloquant pour Android.
      final account = await GoogleSignIn.instance.authenticate();

      // .authentication est maintenant une propriété SYNCHRONE (plus un
      // Future) depuis v7 — plus de `await` ici.
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
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // L'utilisateur a fermé la fenêtre Google sans choisir de compte —
        // ce n'est pas une erreur à afficher, juste une annulation silencieuse.
        return false;
      }
      _lastException = e;
      return false;
    } catch (e) {
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
}
