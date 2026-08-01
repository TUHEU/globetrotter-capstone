import 'package:dio/dio.dart';

/// Petit résultat météo pour un point donné (lat/lng).
class WeatherInfo {
  final double temperatureC;
  final int weatherCode;
  final bool isDay;

  WeatherInfo({
    required this.temperatureC,
    required this.weatherCode,
    required this.isDay,
  });

  /// Description courte + emoji à partir du "WMO Weather interpretation code"
  /// renvoyé par Open-Meteo (https://open-meteo.com/en/docs — table des codes).
  /// On ne couvre que les codes plausibles à Yaoundé (tropical, pas de neige/glace).
  String get description {
    if (weatherCode == 0) return 'Ciel dégagé';
    if (weatherCode <= 2) return 'Partiellement nuageux';
    if (weatherCode == 3) return 'Couvert';
    if (weatherCode == 45 || weatherCode == 48) return 'Brume';
    if (weatherCode >= 51 && weatherCode <= 57) return 'Bruine';
    if (weatherCode >= 61 && weatherCode <= 67) return 'Pluie';
    if (weatherCode >= 80 && weatherCode <= 82) return 'Averses';
    if (weatherCode >= 95) return 'Orage';
    return 'Variable';
  }

  String get emoji {
    if (weatherCode == 0) return isDay ? '☀️' : '🌙';
    if (weatherCode <= 2) return '⛅';
    if (weatherCode == 3) return '☁️';
    if (weatherCode == 45 || weatherCode == 48) return '🌫️';
    if (weatherCode >= 51 && weatherCode <= 67) return '🌧️';
    if (weatherCode >= 80 && weatherCode <= 82) return '🌦️';
    if (weatherCode >= 95) return '⛈️';
    return '🌡️';
  }
}

class WeatherService {
  WeatherService._();

  // Client Dio séparé, sans baseUrl ni token d'auth : Open-Meteo est une API
  // publique, gratuite et sans clé — on ne veut surtout pas lui envoyer notre
  // JWT (qui est ajouté automatiquement par ApiClient.instance.dio).
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  static Future<WeatherInfo?> fetchCurrent(double lat, double lng) async {
    try {
      final res = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'current': 'temperature_2m,weather_code,is_day',
          'timezone': 'Africa/Douala',
        },
      );
      final current = res.data['current'];
      if (current == null) return null;
      return WeatherInfo(
        temperatureC: (current['temperature_2m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        isDay: (current['is_day'] as num).toInt() == 1,
      );
    } catch (_) {
      // Réseau indisponible ou API en panne : on affiche simplement pas de
      // météo plutôt que de faire planter l'écran — ce n'est jamais critique.
      return null;
    }
  }
}
