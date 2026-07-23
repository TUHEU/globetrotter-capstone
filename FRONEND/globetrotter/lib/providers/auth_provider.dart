import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  User? user;
  bool loading = false;
  String? error;

  bool get isLoggedIn => user != null;

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
    error = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.post(path, data: body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', res.data['access_token']);
      user = User.fromJson(res.data['user']);
      return true;
    } catch (e) {
      error = ApiClient.errorMessage(e);
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
