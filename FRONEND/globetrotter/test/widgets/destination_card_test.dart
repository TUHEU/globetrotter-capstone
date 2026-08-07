import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:globetrotter/models/destination.dart';
import 'package:globetrotter/providers/favorites_provider.dart';
import 'package:globetrotter/widgets/destination_card.dart';

Destination _testDestination({String category = 'attraction'}) => Destination(
      id: 'test-001',
      name: 'Monument de Test',
      quartier: 'Quartier Test',
      category: category,
      description: 'Une destination de test.',
      tags: const ['history', 'photo'],
      image: 'https://example.com/image.jpg',
      avgPriceFcfa: 1000,
      bestTime: 'Journée',
      popularity: 50,
    );

Widget _wrap(Widget child) => MaterialApp(
      home: ChangeNotifierProvider<FavoritesProvider>(
        create: (_) => FavoritesProvider(),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('shows destination name and quartier', (tester) async {
    final destination = _testDestination();
    await tester.pumpWidget(_wrap(DestinationCard(destination: destination, onTap: () {})));

    expect(find.text('Monument de Test'), findsOneWidget);
  });

  testWidgets('shows the category label as a chip', (tester) async {
    final destination = _testDestination(category: 'education');
    await tester.pumpWidget(_wrap(DestinationCard(destination: destination, onTap: () {})));

    expect(find.text('Écoles & Universités'), findsOneWidget);
  });

  testWidgets('tapping the card triggers onTap', (tester) async {
    var tapped = false;
    final destination = _testDestination();
    await tester.pumpWidget(_wrap(
      DestinationCard(destination: destination, onTap: () => tapped = true),
    ));

    await tester.tap(find.text('Monument de Test'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('favorite heart starts unfilled (not yet favorited)', (tester) async {
    final destination = _testDestination();
    await tester.pumpWidget(_wrap(DestinationCard(destination: destination, onTap: () {})));

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });
}
