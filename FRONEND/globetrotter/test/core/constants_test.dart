import 'package:flutter_test/flutter_test.dart';
import 'package:globetrotter/core/constants.dart';

void main() {
  group('formatFcfa', () {
    test('zero is displayed as "Gratuit"', () {
      expect(formatFcfa(0), 'Gratuit');
    });

    test('small amounts have no separator', () {
      expect(formatFcfa(500), '500 FCFA');
    });

    test('thousands get a space separator', () {
      expect(formatFcfa(12000), '12 000 FCFA');
    });

    test('hundreds of thousands get multiple separators', () {
      expect(formatFcfa(1234567), '1 234 567 FCFA');
    });

    test('exactly one thousand', () {
      expect(formatFcfa(1000), '1 000 FCFA');
    });
  });

  group('PlaceCategories', () {
    test('every category has both an icon and a label', () {
      for (final key in PlaceCategories.all.keys) {
        expect(PlaceCategories.labels.containsKey(key), isTrue,
            reason: 'Category "$key" has an icon but no label');
      }
      for (final key in PlaceCategories.labels.keys) {
        expect(PlaceCategories.all.containsKey(key), isTrue,
            reason: 'Category "$key" has a label but no icon');
      }
    });

    test('includes the newly added categories', () {
      expect(PlaceCategories.all.containsKey('education'), isTrue);
      expect(PlaceCategories.all.containsKey('sports'), isTrue);
      expect(PlaceCategories.all.containsKey('supermarket'), isTrue);
      expect(PlaceCategories.all.containsKey('administrative'), isTrue);
    });
  });
}
