import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/destination.dart';
import '../providers/favorites_provider.dart';
import 'network_image_safe.dart';

class DestinationCard extends StatelessWidget {
  final Destination destination;
  final VoidCallback? onTap;
  final bool showReasons;

  const DestinationCard({
    super.key,
    required this.destination,
    this.onTap,
    this.showReasons = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favorites = context.watch<FavoritesProvider>();
    final isFav = favorites.isFavorite(destination.id);
    final catIcon =
        PlaceCategories.all[destination.category] ?? Icons.place_outlined;
    final catLabel =
        PlaceCategories.labels[destination.category] ?? destination.category;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              AspectRatio(
                aspectRatio: 16 / 8,
                child: NetworkImageSafe(
                  url: destination.image,
                  fit: BoxFit.cover,
                  placeholder: (_) => Container(
                    color: theme.colorScheme.primaryContainer,
                    child: Center(child: Icon(catIcon, size: 48)),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Chip(
                  avatar: Icon(catIcon, size: 16),
                  label: Text(catLabel),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      theme.colorScheme.surface.withValues(alpha: 0.9),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => favorites.toggle(destination.id),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isFav ? Colors.redAccent : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(destination.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Text(formatFcfa(destination.avgPriceFcfa),
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: theme.colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.place, size: 14, color: theme.colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text(destination.quartier, style: theme.textTheme.bodySmall),
                    const Spacer(),
                    Icon(Icons.schedule, size: 14, color: theme.colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text(destination.bestTime, style: theme.textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 8),
                  Text(destination.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: destination.tags
                        .map((t) => Chip(
                              label: Text(t),
                              visualDensity: VisualDensity.compact,
                              labelStyle: theme.textTheme.labelSmall,
                            ))
                        .toList(),
                  ),
                  if (showReasons && destination.reasons.isNotEmpty) ...[
                    const Divider(height: 20),
                    ...destination.reasons.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            Icon(Icons.auto_awesome,
                                size: 14, color: theme.colorScheme.tertiary),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(r, style: theme.textTheme.bodySmall)),
                          ]),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
