import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:provider/provider.dart';

import 'package:geolocator/geolocator.dart' as geo;

import '../models/destination.dart';
import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../services/directions_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/map3d_view.dart';

/// Affiche un itinéraire sur une carte 3D (immeubles en relief, façon Google
/// Maps/Plans) — MapLibre GL + OpenFreeMap, gratuit, sans clé API :
/// - un marqueur numéroté par arrêt (dans l'ordre du jour puis de la liste)
/// - le tracé du trajet à pied entre les arrêts (OSRM, gratuit)
/// - les instructions de navigation pas-à-pas ("tournez à droite sur...")
/// - la position actuelle et la météo de chaque arrêt
class ItineraryMapScreen extends StatefulWidget {
  final Itinerary itinerary;
  const ItineraryMapScreen({super.key, required this.itinerary});

  @override
  State<ItineraryMapScreen> createState() => _ItineraryMapScreenState();
}

class _StopPoint {
  final ItineraryStop stop;
  final Destination destination;
  WeatherInfo? weather;
  _StopPoint(this.stop, this.destination);
}

class _ItineraryMapScreenState extends State<ItineraryMapScreen> {
  List<_StopPoint> _points = [];
  RouteResult? _route;
  bool _loading = true;
  String? _error;
  geo.Position? _myPosition;
  bool _showDirections = false;

  @override
  void initState() {
    super.initState();
    _load();
    LocationService.getCurrentPosition().then((pos) {
      if (!mounted || pos == null) return;
      setState(() => _myPosition = pos);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final destProvider = context.read<DestinationProvider>();
    final sortedStops = [...widget.itinerary.stops]..sort((a, b) => a.day.compareTo(b.day));

    final resolved = <_StopPoint>[];
    for (final stop in sortedStops) {
      final dest = await destProvider.fetchById(stop.destinationId);
      if (dest != null) resolved.add(_StopPoint(stop, dest));
    }

    if (resolved.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Impossible de charger les arrêts de cet itinéraire.";
      });
      return;
    }

    await Future.wait(resolved.map((p) async {
      p.weather = await WeatherService.fetchCurrent(p.destination.lat, p.destination.lng);
    }));

    RouteResult? route;
    if (resolved.length >= 2) {
      route = await DirectionsService.fetchRoute(
        resolved.map((p) => LatLng(p.destination.lat, p.destination.lng)).toList(),
      );
    }

    if (!mounted) return;
    setState(() {
      _points = resolved;
      _route = route;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final stops = [
      for (int i = 0; i < _points.length; i++)
        Map3DStop(
          point: LatLng(_points[i].destination.lat, _points[i].destination.lng),
          label: '${i + 1}',
          color: scheme.primary,
        ),
    ];
    final myLatLng =
        _myPosition != null ? LatLng(_myPosition!.latitude, _myPosition!.longitude) : null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.itinerary.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : Column(
                  children: [
                    Expanded(
                      child: Map3DView(
                        stops: stops,
                        // Plus besoin de convertir point par point : RouteResult.polyline
                        // est maintenant déjà en LatLng maplibre_gl (voir directions_service.dart).
                        routePolyline: _route?.polyline,
                        myPosition: myLatLng,
                      ),
                    ),
                    if (_route != null)
                      Material(
                        color: scheme.primaryContainer,
                        child: InkWell(
                          onTap: _route!.steps.isEmpty
                              ? null
                              : () => setState(() => _showDirections = !_showDirections),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.directions_walk, color: scheme.onPrimaryContainer, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Trajet à pied : ${_route!.distanceLabel} · ${_route!.durationLabel}',
                                    style: TextStyle(
                                        color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (_route!.steps.isNotEmpty)
                                  Icon(
                                    _showDirections ? Icons.expand_less : Icons.expand_more,
                                    color: scheme.onPrimaryContainer,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_showDirections && _route != null && _route!.steps.isNotEmpty)
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _route!.steps.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final step = _route!.steps[i];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                  radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 11))),
                              title: Text(step.instruction),
                              trailing: Text(step.distanceLabel,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            );
                          },
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _points.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final p = _points[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                                child: Text('${i + 1}'),
                              ),
                              title: Text(p.destination.name),
                              subtitle: Text(_myPosition != null
                                  ? '${p.destination.quartier} · Jour ${p.stop.day} · à ${LocationService.formatKm(LocationService.haversineKm(_myPosition!.latitude, _myPosition!.longitude, p.destination.lat, p.destination.lng))} de vous'
                                  : '${p.destination.quartier} · Jour ${p.stop.day}'),
                              trailing: p.weather != null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${p.weather!.emoji} ${p.weather!.temperatureC.round()}°C',
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text(p.weather!.description, style: const TextStyle(fontSize: 11)),
                                      ],
                                    )
                                  : const SizedBox(
                                      width: 24, height: 24, child: Icon(Icons.cloud_off, size: 18)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
