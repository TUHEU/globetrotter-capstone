import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../core/constants.dart';
import '../models/destination.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/destination_reviews_section.dart';
import '../widgets/map3d_view.dart';
import '../widgets/nearby_places_section.dart';
import '../widgets/network_image_safe.dart';
import 'create_itinerary_screen.dart';
import 'directions_screen.dart';

class DestinationDetailScreen extends StatefulWidget {
  final Destination destination;
  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  WeatherInfo? _weather;
  bool _weatherLoading = true;
  double? _distanceKm;
  LatLng? _myPosition;

  @override
  void initState() {
    super.initState();
    WeatherService.fetchCurrent(widget.destination.lat, widget.destination.lng).then((w) {
      if (!mounted) return;
      setState(() {
        _weather = w;
        _weatherLoading = false;
      });
    });
    // Distance calculée localement (haversine) une fois la position connue -
    // pas besoin d'attendre le serveur pour un simple calcul de distance.
    // On garde aussi la position elle-même (_myPosition) pour le point bleu
    // "vous êtes ici" affiché sur la carte 3D ci-dessous.
    LocationService.getCurrentPosition().then((pos) {
      if (!mounted || pos == null) return;
      setState(() {
        _distanceKm = LocationService.haversineKm(
            pos.latitude, pos.longitude, widget.destination.lat, widget.destination.lng);
        _myPosition = LatLng(pos.latitude, pos.longitude);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destination = widget.destination;

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
              background: NetworkImageSafe(
                url: destination.image,
                fit: BoxFit.cover,
                placeholder: (_) => Container(color: theme.colorScheme.primaryContainer),
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
                    if (_distanceKm != null) ...[
                      const SizedBox(width: 10),
                      Chip(
                        avatar: const Icon(Icons.near_me, size: 14),
                        label: Text('à ${LocationService.formatKm(_distanceKm!)} de vous'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
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
                    _weatherLoading
                        ? const _InfoTile(
                            icon: Icons.cloud_outlined, label: 'Météo', value: '…')
                        : _InfoTile(
                            icon: Icons.thermostat,
                            label: _weather?.description ?? 'Indisponible',
                            value: _weather != null
                                ? '${_weather!.emoji} ${_weather!.temperatureC.round()}°C'
                                : '—',
                          ),
                  ]),
                  const SizedBox(height: 20),
                  Text('About', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(destination.description, style: theme.textTheme.bodyLarge),
                  if (destination.foundedYear != null || destination.history != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.history_edu_outlined,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (destination.foundedYear != null)
                                  Text(
                                    'Fondé en ${destination.foundedYear}',
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                if (destination.history != null) ...[
                                  if (destination.foundedYear != null) const SizedBox(height: 4),
                                  Text(destination.history!, style: theme.textTheme.bodyMedium),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: destination.tags
                        .map((t) => Chip(label: Text(t)))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Text('Localisation', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 220,
                      // Contrairement à l'ancien aperçu flutter_map (plat,
                      // figé, tuiles OpenStreetMap 2D), c'est maintenant la
                      // MÊME carte 3D (immeubles en relief, style MapLibre/
                      // OpenFreeMap) que celle des itinéraires - avec le
                      // point "vous êtes ici" dès que la position est connue,
                      // et interactive (zoom/rotation/tilt) au lieu d'être
                      // juste une image de fond.
                      child: Map3DView(
                        stops: [
                          Map3DStop(
                            point: LatLng(destination.lat, destination.lng),
                            label: destination.name,
                            color: theme.colorScheme.error,
                          ),
                        ],
                        myPosition: _myPosition,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.directions_outlined),
                      label: const Text('Itinéraire (voir sur la carte 3D)'),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DirectionsScreen(destination: destination))),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 28),
                  NearbyPlacesSection(destinationId: destination.id),
                  const SizedBox(height: 28),
                  DestinationReviewsSection(destinationId: destination.id),
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
          Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
