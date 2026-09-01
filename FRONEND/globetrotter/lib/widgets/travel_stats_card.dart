import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/settings_provider.dart';

class TravelStatsCard extends StatelessWidget {
  const TravelStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final theme = Theme.of(context);
    final itineraries = context.watch<ItineraryProvider>().itineraries;
    final destProvider = context.watch<DestinationProvider>();

    final visited = <String>{};
    final quarters = <String>{};
    for (final it in itineraries) {
      for (final ItineraryStop stop in it.stops) {
        visited.add(stop.destinationId);
        final d = destProvider.byId(stop.destinationId);
        if (d != null && d.quartier.isNotEmpty) quarters.add(d.quartier);
      }
    }

    // Real data points: each bar represents an itinerary and its number of stops.
    final counts = itineraries.take(7).toList().reversed
        .map((it) => it.stops.length.toDouble()).toList();
    final max = counts.isEmpty ? 1.0 : counts.reduce((a,b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16,16,16,14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(s.travelStatsTitle,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            Text('${itineraries.length} ${s.statTrips}',
              style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            height: 130,
            child: counts.isEmpty
              ? Center(child: Text(s.isFr ? 'Créez un itinéraire pour voir votre graphique.' : 'Create a trip to see your chart.'))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i=0; i<counts.length; i++)
                      Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text('${counts[i].round()}',
                            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: counts[i] / max),
                            duration: const Duration(milliseconds: 500),
                            builder: (_, v, __) => Container(
                              height: 78 * v.clamp(.08, 1.0),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ]),
                      )),
                  ],
                ),
          ),
          const Divider(height: 24),
          Row(children: [
            _StatColumn(value: '${visited.length}', label: s.placesDiscovered),
            _StatColumn(value: '${quarters.length}', label: s.quartiersExplored),
          ]),
        ]),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value, label;
  const _StatColumn({required this.value, required this.label});
  @override Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 2), Text(label, textAlign: TextAlign.center),
    ]),
  );
}
