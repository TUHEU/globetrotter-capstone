import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';
import 'constants.dart';

/// Single Dio client for the whole app. Attaches the JWT automatically.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));

  /// Convertit une exception réseau en message localisé (FR/EN).
  /// [s] vient de context.read<SettingsProvider>().s au moment de l'affichage,
  /// jamais mémorisé à l'avance, pour toujours refléter la langue actuelle.
  static String errorMessage(Object e, AppStrings s) {
    if (e is DioException) {
      final data = e.response?.data;
      final detail = (data is Map ? data['detail']?.toString() : null);
      if (detail != null) {
        // Traduit les messages backend connus ; sinon les affiche tels quels.
        switch (detail) {
          case 'Invalid email or password':
            return s.invalidCredentials;
          case 'Email already registered':
            return s.emailAlreadyRegistered;
          default:
            return detail;
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return s.cannotReachServer;
      }
    }
    return s.somethingWrong;
  }
}
