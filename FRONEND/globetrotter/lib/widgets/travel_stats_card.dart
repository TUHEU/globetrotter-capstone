import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/settings_provider.dart';

/// Deux statistiques calculées côté client à partir des sorties déjà
/// chargées (aucun nouvel appel réseau, aucun changement backend) :
/// nombre de lieux UNIQUES et de quartiers UNIQUES apparus dans les
/// arrêts de toutes les sorties de l'utilisateur. Complète les stats déjà
/// affichées sur le Profil (Itinéraires, Favoris) sans les dupliquer -
/// "lieux découverts" est une notion différente du nombre de sorties
/// (une même sortie peut couvrir plusieurs lieux, plusieurs sorties
/// peuvent partager un lieu). POST /destinations/{id}/visit existant
/// côté backend n'est qu'un compteur GLOBAL de popularité, pas un suivi
/// par utilisateur - dériver la stat des sorties déjà possédées est
/// correct et ne nécessite aucun changement serveur.
class TravelStatsCard extends StatelessWidget {
  const TravelStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final theme = Theme.of(context);
    final itineraries = context.watch<ItineraryProvider>().itineraries;
    final destProvider = context.watch<DestinationProvider>();

    final visitedIds = <String>{};
    final quartiers = <String>{};
    for (final it in itineraries) {
      for (final ItineraryStop stop in it.stops) {
        visitedIds.add(stop.destinationId);
        final dest = destProvider.byId(stop.destinationId);
        if (dest != null && dest.quartier.isNotEmpty) quartiers.add(dest.quartier);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.travelStatsTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatColumn(value: '${visitedIds.length}', label: s.placesDiscovered),
                _StatColumn(value: '${quartiers.length}', label: s.quartiersExplored),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

