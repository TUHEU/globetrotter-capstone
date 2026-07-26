import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/app_strings.dart';
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
