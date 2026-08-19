import '../models/destination.dart';
import '../models/itinerary.dart';
import 'location_service.dart';

/// Réordonne les arrêts d'une sortie pour réduire la distance totale à
/// parcourir chaque jour - correspond à "Trip Optimization" dans le
/// document de vision du projet, adapté à ce qu'on peut réellement
/// calculer avec les données déjà en main (coordonnées des destinations),
/// sans dépendance externe (pas d'API de trafic/horaires d'ouverture).
///
/// Heuristique du plus proche voisin (nearest neighbor) - PAS une
/// solution optimale du voyageur de commerce (NP-difficile en général),
/// mais largement suffisante pour quelques arrêts dans une même journée,
/// et rapide à calculer côté client sans aller-retour réseau.
class RouteOptimizer {
  RouteOptimizer._();

  /// Réordonne [stops] jour par jour. Le PREMIER arrêt de chaque jour
  /// reste fixe (le point de départ que l'utilisateur a choisi n'est
  /// jamais remis en question) ; seuls les arrêts suivants du même jour
  /// sont réordonnés par proximité.
  static List<ItineraryStop> optimize(
    List<ItineraryStop> stops,
    Destination? Function(String id) destinationOf,
  ) {
    final byDay = <int, List<ItineraryStop>>{};
    final dayOrder = <int>[];
    for (final s in stops) {
      if (!byDay.containsKey(s.day)) dayOrder.add(s.day);
      byDay.putIfAbsent(s.day, () => []).add(s);
    }

    final result = <ItineraryStop>[];
    for (final day in dayOrder) {
      result.addAll(_optimizeDay(byDay[day]!, destinationOf));
    }
    return result;
  }

  static List<ItineraryStop> _optimizeDay(
    List<ItineraryStop> dayStops,
    Destination? Function(String id) destinationOf,
  ) {
    if (dayStops.length <= 2) return dayStops; // rien à gagner en dessous de 3 arrêts

    final remaining = List<ItineraryStop>.from(dayStops);
    final ordered = <ItineraryStop>[remaining.removeAt(0)];

    while (remaining.isNotEmpty) {
      final current = destinationOf(ordered.last.destinationId);
      if (current == null) {
        // Coordonnées inconnues pour comparer - on garde le reste dans
        // son ordre d'origine plutôt que de deviner un ordre arbitraire.
        ordered.addAll(remaining);
        break;
      }
      ItineraryStop? nearest;
      double? nearestDist;
      for (final s in remaining) {
        final d = destinationOf(s.destinationId);
        if (d == null) continue;
        final dist = LocationService.haversineKm(current.lat, current.lng, d.lat, d.lng);
        if (nearestDist == null || dist < nearestDist) {
          nearestDist = dist;
          nearest = s;
        }
      }
      if (nearest == null) {
        ordered.addAll(remaining);
        break;
      }
      ordered.add(nearest);
      remaining.remove(nearest);
    }
    return ordered;
  }

  /// Distance totale (km) parcourue chaque jour, dans l'ordre DONNÉ -
  /// calculée jour par jour (un saut entre le dernier arrêt d'un jour et
  /// le premier du suivant ne compte pas comme "trajet", puisque ce sont
  /// deux journées séparées, probablement avec un point de départ
  /// différent). Utile pour afficher "avant / après" à l'utilisateur.
  static double totalDistanceKm(
    List<ItineraryStop> stops,
    Destination? Function(String id) destinationOf,
  ) {
    final byDay = <int, List<ItineraryStop>>{};
    for (final s in stops) {
      byDay.putIfAbsent(s.day, () => []).add(s);
    }
    var total = 0.0;
    for (final dayStops in byDay.values) {
      Destination? prev;
      for (final s in dayStops) {
        final d = destinationOf(s.destinationId);
        if (d == null) continue;
        if (prev != null) {
          total += LocationService.haversineKm(prev.lat, prev.lng, d.lat, d.lng);
        }
        prev = d;
      }
    }
    return total;
  }
}
