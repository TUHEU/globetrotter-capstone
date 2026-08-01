import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../services/directions_service.dart';
import '../services/weather_service.dart';

/// Affiche un itinéraire sur une carte OpenStreetMap (gratuite, sans clé API) :
/// - un marqueur par arrêt (dans l'ordre du jour puis de la liste)
/// - un tracé de trajet à pied entre les arrêts (OSRM, gratuit)
/// - la météo actuelle de chaque arrêt
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
  final MapController _mapController = MapController();
  List<_StopPoint> _points = [];
  RouteResult? _route;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

    // Météo actuelle de chaque arrêt, en parallèle.
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

    // Centre la carte pour englober tous les arrêts.
    if (_points.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(
        _points.map((p) => LatLng(p.destination.lat, p.destination.lng)).toList(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.itinerary.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _points.isNotEmpty
                              ? LatLng(_points.first.destination.lat, _points.first.destination.lng)
                              : const LatLng(3.8480, 11.5021),
                          initialZoom: 13,
                        ),
                        children: [
                          // OpenStreetMap : tuiles gratuites, aucune clé API requise.
                          // Merci de respecter la politique d'usage tuile OSM en prod
                          // (https://operations.osmfoundation.org/policies/tiles/).
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.globetrotter',
                          ),
                          if (_route != null)
                            PolylineLayer(polylines: [
                              Polyline(points: _route!.polyline, strokeWidth: 4, color: scheme.secondary),
                            ]),
                          MarkerLayer(
                            markers: [
                              for (int i = 0; i < _points.length; i++)
                                Marker(
                                  point: LatLng(_points[i].destination.lat, _points[i].destination.lng),
                                  width: 40,
                                  height: 40,
                                  child: _StopMarker(index: i + 1, color: scheme.primary),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_route != null)
                      Container(
                        width: double.infinity,
                        color: scheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.directions_walk, color: scheme.onPrimaryContainer, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Trajet à pied : ${_route!.distanceLabel} · ${_route!.durationLabel}',
                              style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _points.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                              subtitle: Text('${p.destination.quartier} · Jour ${p.stop.day}'),
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
                                  : const SizedBox(width: 24, height: 24, child: Icon(Icons.cloud_off, size: 18)),
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

class _StopMarker extends StatelessWidget {
  final int index;
  final Color color;
  const _StopMarker({required this.index, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: Text(
        '$index',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
