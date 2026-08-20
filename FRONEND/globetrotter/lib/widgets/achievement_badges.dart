import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/itinerary.dart';
import '../providers/favorites_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/settings_provider.dart';

class _Badge {
  final IconData icon;
  final String Function(bool isFr) label;
  final bool unlocked;
  const _Badge(this.icon, this.label, this.unlocked);
}

/// Badges de progression, calculés à partir de données déjà chargées par
/// d'autres providers (aucun nouvel appel réseau) : nombre de sorties
/// créées, de favoris, et de personnes suivies. Purement dérivé/cosmétique
/// - ne persiste rien côté serveur, se recalcule à chaque affichage.
class AchievementBadges extends StatelessWidget {
  const AchievementBadges({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final isFr = s.isFr;
    final theme = Theme.of(context);

    final itineraryCount = context.watch<ItineraryProvider>().itineraries.length;
    final favoriteCount = context.watch<FavoritesProvider>().count;
    final followingCount = context.watch<FriendsProvider>().following.length;

    // Lieux uniques découverts à travers TOUTES les sorties de
    // l'utilisateur (pas juste la dernière) - même logique que
    // TravelStatsCard sur l'écran Profil, dérivée des sorties déjà
    // chargées plutôt que d'un nouveau suivi côté serveur.
    final visitedPlaceIds = <String>{};
    for (final it in context.watch<ItineraryProvider>().itineraries) {
      for (final ItineraryStop stop in it.stops) {
        visitedPlaceIds.add(stop.destinationId);
      }
    }

    final badges = <_Badge>[
      _Badge(
        Icons.explore_outlined,
        (fr) => fr ? 'Premier pas' : 'First step',
        itineraryCount >= 1,
      ),
      _Badge(
        Icons.map_outlined,
        (fr) => fr ? 'Planificateur' : 'Planner',
        itineraryCount >= 5,
      ),
      _Badge(
        Icons.favorite_outline,
        (fr) => fr ? 'Collectionneur' : 'Collector',
        favoriteCount >= 10,
      ),
      _Badge(
        Icons.people_outline,
        (fr) => fr ? 'Social' : 'Social',
        followingCount >= 3,
      ),
      _Badge(
        Icons.travel_explore_outlined,
        (fr) => fr ? 'Explorateur' : 'Explorer',
        visitedPlaceIds.length >= 15,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFr ? 'Badges' : 'Badges',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        // SingleChildScrollView horizontal : avec 5 badges (4 avant +
        // "Explorateur"), un simple Row à largeur fixe risquait un
        // débordement visuel sur les téléphones étroits (~320-360px) -
        // aussi plus robuste si d'autres badges s'ajoutent plus tard.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: badges.map((b) {
              final color = b.unlocked ? theme.colorScheme.primary : theme.disabledColor;
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(b.unlocked ? 0.15 : 0.08),
                        border: Border.all(color: color.withOpacity(b.unlocked ? 0.6 : 0.25)),
                      ),
                      child: Icon(b.icon, color: color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 68,
                      child: Text(
                        b.label(isFr),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: b.unlocked ? null : theme.disabledColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
