import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Résultat d'un itinéraire routier entre plusieurs points.
class RouteResult {
  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;

  RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get distanceLabel => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
      : '${distanceMeters.round()} m';

  String get durationLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m > 0 ? m.toString().padLeft(2, '0') : ''}';
  }
}

/// Utilise le serveur de démonstration public d'OSRM (Open Source Routing
/// Machine) — gratuit, sans clé API, mais NON destiné à une charge de
/// production réelle (c'est une instance de démo partagée par tout le monde).
/// Largement suffisant pour un projet étudiant.
class DirectionsService {
  DirectionsService._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// [points] doit contenir au moins 2 arrêts, dans l'ordre de visite.
  /// [profile] : "foot" (marche) ou "driving".
  static Future<RouteResult?> fetchRoute(
    List<LatLng> points, {
    String profile = 'foot',
  }) async {
    if (points.length < 2) return null;
    final coords = points.map((p) => '${p.longitude},${p.latitude}').join(';');
    try {
      final res = await _dio.get(
        'https://router.project-osrm.org/route/v1/$profile/$coords',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final routes = res.data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first;
      final coordinates = route['geometry']['coordinates'] as List;
      final polyline = coordinates
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      return RouteResult(
        polyline: polyline,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (_) {
      // Serveur de démo OSRM parfois surchargé/indisponible — on retombe
      // sur une simple ligne droite entre les points côté écran appelant.
      return null;
    }
  }
}
