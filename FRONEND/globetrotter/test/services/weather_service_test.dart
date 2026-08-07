import 'package:flutter_test/flutter_test.dart';
import 'package:globetrotter/services/weather_service.dart';

void main() {
  group('WeatherInfo.description', () {
    test('code 0 is "Ciel dégagé"', () {
      final w = WeatherInfo(temperatureC: 25, weatherCode: 0, isDay: true);
      expect(w.description, 'Ciel dégagé');
    });

    test('code 3 is "Couvert"', () {
      final w = WeatherInfo(temperatureC: 21, weatherCode: 3, isDay: true);
      expect(w.description, 'Couvert');
    });

    test('rain codes (61-67) map to "Pluie"', () {
      for (final code in [61, 63, 65, 67]) {
        final w = WeatherInfo(temperatureC: 22, weatherCode: code, isDay: true);
        expect(w.description, 'Pluie', reason: 'code $code should be Pluie');
      }
    });

    test('storm codes (95+) map to "Orage"', () {
      final w = WeatherInfo(temperatureC: 20, weatherCode: 95, isDay: true);
      expect(w.description, 'Orage');
    });
  });

  group('WeatherInfo.emoji', () {
    test('clear sky uses sun emoji during the day', () {
      final w = WeatherInfo(temperatureC: 25, weatherCode: 0, isDay: true);
      expect(w.emoji, '☀️');
    });

    test('clear sky uses moon emoji at night', () {
      final w = WeatherInfo(temperatureC: 25, weatherCode: 0, isDay: false);
      expect(w.emoji, '🌙');
    });

    test('storm uses lightning emoji regardless of time of day', () {
      final w = WeatherInfo(temperatureC: 20, weatherCode: 96, isDay: false);
      expect(w.emoji, '⛈️');
    });
  });
}
