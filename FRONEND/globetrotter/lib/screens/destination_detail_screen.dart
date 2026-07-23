import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/destination.dart';
import 'create_itinerary_screen.dart';

class DestinationDetailScreen extends StatelessWidget {
  final Destination destination;
  const DestinationDetailScreen({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(destination.name,
                  style: const TextStyle(
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)])),
              background: Image.network(
                destination.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: theme.colorScheme.primaryContainer),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.place, size: 18, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(destination.quartier, style: theme.textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    _InfoTile(
                        icon: Icons.payments_outlined,
                        label: 'Budget moyen',
                        value: formatFcfa(destination.avgPriceFcfa)),
                    const SizedBox(width: 12),
                    _InfoTile(
                        icon: Icons.schedule,
                        label: 'Meilleur moment',
                        value: destination.bestTime),
                    const SizedBox(width: 12),
                    _InfoTile(
                        icon: Icons.trending_up,
                        label: 'Popularité',
                        value: '${destination.popularity}'),
                  ]),
                  const SizedBox(height: 20),
                  Text('About', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(destination.description, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: destination.tags
                        .map((t) => Chip(label: Text(t)))
                        .toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Ajouter à une sortie'),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              CreateItineraryScreen(preselected: destination))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
          Text(label, style: theme.textTheme.labelSmall),
        ]),
      ),
    );
  }
}
