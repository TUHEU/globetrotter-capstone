import 'package:flutter_test/flutter_test.dart';
import 'package:globetrotter/services/location_service.dart';

void main() {
  group('LocationService.haversineKm', () {
    test('distance between identical points is ~0', () {
      final d = LocationService.haversineKm(3.8480, 11.5021, 3.8480, 11.5021);
      expect(d, closeTo(0, 0.0001));
    });

    test('distance between two known Yaoundé points is realistic', () {
      // Monument de la Réunification -> Mont Fébé, environ 4-5 km à vol
      // d'oiseau (valeur de référence approximative, pas un GPS exact).
      final d = LocationService.haversineKm(3.8525, 11.5134, 3.8930, 11.5237);
      expect(d, greaterThan(3));
      expect(d, lessThan(7));
    });

    test('distance is symmetric (A->B == B->A)', () {
      final d1 = LocationService.haversineKm(3.85, 11.50, 3.90, 11.55);
      final d2 = LocationService.haversineKm(3.90, 11.55, 3.85, 11.50);
      expect(d1, closeTo(d2, 0.0001));
    });
  });

  group('LocationService.formatKm', () {
    test('formats sub-kilometer distances in meters', () {
      expect(LocationService.formatKm(0.35), '350 m');
    });

    test('formats kilometer-plus distances with one decimal', () {
      expect(LocationService.formatKm(2.456), '2.5 km');
    });

    test('boundary at exactly 1 km uses km formatting', () {
      expect(LocationService.formatKm(1.0), '1.0 km');
    });
  });
}
