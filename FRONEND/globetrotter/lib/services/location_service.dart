import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

/// Gère la localisation de l'utilisateur (permissions + position),
/// utilisée pour afficher "à X km de vous" et le point bleu en direct
/// sur la carte — inspiré de la fonctionnalité "Show my location (live)"
/// du monolithe Phase 1, adaptée ici en Flutter/geolocator plutôt qu'en
/// JS `watchPosition` côté navigateur.
class LocationService {
  LocationService._();

  /// Demande la permission et renvoie la position actuelle, ou null si
  /// refusée / service de localisation désactivé. Ne lève jamais
  /// d'exception — l'app doit rester utilisable sans localisation.
  static Future<Position?> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      // GPS indisponible, timeout, permission système bloquée, etc. —
      // on traite ça comme "pas de localisation", jamais comme un crash.
      return null;
    }
  }

  /// Flux de positions en direct (point bleu qui se déplace sur la carte),
  /// équivalent de watchPosition() côté web. S'arrête tout seul si
  /// l'utilisateur retire la permission en cours de route.
  static Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // ne notifie que si déplacement > 10m
      ),
    );
  }

  /// Distance à vol d'oiseau en km entre deux points (formule de
  /// haversine) — même formule que côté backend (recommendation-service),
  /// dupliquée ici pour un affichage instantané côté client sans
  /// aller-retour réseau à chaque fois.
  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dphi = (lat2 - lat1) * math.pi / 180;
    final dlambda = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dphi / 2) * math.sin(dphi / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) * math.sin(dlambda / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static String formatKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
