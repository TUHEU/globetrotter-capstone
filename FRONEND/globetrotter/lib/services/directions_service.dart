import 'package:dio/dio.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

// NOTE: this used to import latlong2's LatLng instead of maplibre_gl's.
// Both packages define a class literally named `LatLng`, with the same
// .latitude/.longitude shape - but they are NOT the same Dart type, so a
// List<LatLng> built here couldn't be passed to Map3DView (which needs
// maplibre_gl's LatLng) without every caller manually converting each
// point, and vice-versa for fetchRoute()'s input. That mismatch is exactly
// what caused the "argument_type_not_assignable" / "list_element_type_not_
// assignable" errors in itinerary_map_screen.dart and directions_screen.dart.
// Standardizing on maplibre_gl's LatLng here (the type every screen and
// Map3DView already use) removes the conversion entirely at both ends.

/// Une instruction de navigation ("Tournez à droite sur Avenue Kennedy").
class RouteStep {
  final String instruction;
  final double distanceMeters;
  final LatLng location; // point de départ de cette instruction

  RouteStep({required this.instruction, required this.distanceMeters, required this.location});

  String get distanceLabel => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
      : '${distanceMeters.round()} m';
}

/// Résultat d'un itinéraire routier entre plusieurs points.
class RouteResult {
  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    this.steps = const [],
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
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
        },
      );
      final routes = res.data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first;
      final coordinates = route['geometry']['coordinates'] as List;
      final polyline = coordinates
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      final steps = <RouteStep>[];
      for (final leg in (route['legs'] as List? ?? [])) {
        for (final step in (leg['steps'] as List? ?? [])) {
          final geometry = step['geometry']?['coordinates'] as List?;
          if (geometry == null || geometry.isEmpty) continue;
          final start = geometry.first;
          steps.add(RouteStep(
            instruction: _formatInstruction(step),
            distanceMeters: ((step['distance'] as num?) ?? 0).toDouble(),
            location: LatLng((start[1] as num).toDouble(), (start[0] as num).toDouble()),
          ));
        }
      }

      return RouteResult(
        polyline: polyline,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
        steps: steps,
      );
    } catch (_) {
      // Serveur de démo OSRM parfois surchargé/indisponible — on retombe
      // sur une simple ligne droite entre les points côté écran appelant.
      return null;
    }
  }

  /// Traduit le "maneuver" brut d'OSRM (type + modifier + nom de rue) en une
  /// instruction lisible. OSRM ne fournit pas de texte tout fait - seulement
  /// des champs structurés (spec : https://project-osrm.org/docs/v5.24.0/api/#stepmaneuver-object).
  static String _formatInstruction(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] as Map<String, dynamic>? ?? {};
    final type = maneuver['type'] as String? ?? 'continue';
    final modifier = maneuver['modifier'] as String?;
    final name = (step['name'] as String?)?.trim();
    final road = (name == null || name.isEmpty) ? 'la route' : name;

    String modifierFr(String m) => switch (m) {
          'left' => 'à gauche',
          'right' => 'à droite',
          'sharp left' => 'fortement à gauche',
          'sharp right' => 'fortement à droite',
          'slight left' => 'légèrement à gauche',
          'slight right' => 'légèrement à droite',
          'straight' => 'tout droit',
          'uturn' => 'demi-tour',
          _ => m,
        };

    switch (type) {
      case 'depart':
        return 'Départ sur $road';
      case 'arrive':
        return 'Arrivée à destination';
      case 'roundabout':
      case 'rotary':
        return 'Prenez le rond-point vers $road';
      case 'turn':
        return modifier != null ? 'Tournez ${modifierFr(modifier)} sur $road' : 'Continuez sur $road';
      case 'merge':
        return 'Rejoignez $road';
      case 'fork':
        return modifier != null ? 'Au embranchement, restez ${modifierFr(modifier)} vers $road' : 'Restez sur $road';
      case 'end of road':
        return modifier != null ? 'En fin de route, tournez ${modifierFr(modifier)} sur $road' : 'Continuez sur $road';
      default:
        return 'Continuez sur $road';
    }
  }
}
