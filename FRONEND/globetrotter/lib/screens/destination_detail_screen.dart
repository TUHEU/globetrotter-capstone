import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../models/destination.dart';
import '../services/weather_service.dart';
import 'create_itinerary_screen.dart';

class DestinationDetailScreen extends StatefulWidget {
  final Destination destination;
  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  WeatherInfo? _weather;
  bool _weatherLoading = true;

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
                      height: 180,
                      child: IgnorePointer(
                        // Aperçu non-interactif (pas de scroll/zoom au doigt) —
                        // juste une carte de localisation, pas un explorateur.
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(destination.lat, destination.lng),
                            initialZoom: 14.5,
                            interactionOptions:
                                const InteractionOptions(flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.globetrotter',
                            ),
                            MarkerLayer(markers: [
                              Marker(
                                point: LatLng(destination.lat, destination.lng),
                                width: 36,
                                height: 36,
                                child: Icon(Icons.location_pin,
                                    color: theme.colorScheme.error, size: 36),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
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
          Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
