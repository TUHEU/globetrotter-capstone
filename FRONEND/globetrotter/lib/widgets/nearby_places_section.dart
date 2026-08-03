import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/destination.dart';
import '../screens/destination_detail_screen.dart';
import 'network_image_safe.dart';

/// "Lieux à proximité" — porté depuis GET /destinations/<id>/nearby du
/// monolithe Phase 1 (distance à vol d'oiseau, formule de haversine).
class NearbyPlacesSection extends StatefulWidget {
  final String destinationId;
  const NearbyPlacesSection({super.key, required this.destinationId});

  @override
  State<NearbyPlacesSection> createState() => _NearbyPlacesSectionState();
}

class _NearbyPlacesSectionState extends State<NearbyPlacesSection> {
  List<Destination> _places = [];
  Map<String, double> _distances = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.dio.get(
        '/destinations/${widget.destinationId}/nearby',
        queryParameters: {'limit': 6, 'max_km': 3.0},
      );
      final results = res.data['results'] as List;
      final places = <Destination>[];
      final distances = <String, double>{};
      for (final j in results) {
        final d = Destination.fromJson(j);
        places.add(d);
        distances[d.id] = (j['distance_km'] as num).toDouble();
      }
      if (!mounted) return;
      setState(() {
        _places = places;
        _distances = distances;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_places.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('À proximité', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _places.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final d = _places[i];
              return SizedBox(
                width: 140,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DestinationDetailScreen(destination: d))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 90,
                          width: 140,
                          child: NetworkImageSafe(
                            url: d.image,
                            placeholder: (_) => Container(color: theme.colorScheme.primaryContainer),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium),
                      Text('${LocationHelper.formatKm(_distances[d.id] ?? 0)} · ${d.quartier}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Petit alias local pour formater les distances (évite un import
/// circulaire avec LocationService dans ce fichier).
class LocationHelper {
  static String formatKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
