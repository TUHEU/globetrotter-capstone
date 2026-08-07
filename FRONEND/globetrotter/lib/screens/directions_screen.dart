import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'package:geolocator/geolocator.dart' as geo;

import '../models/destination.dart';
import '../services/directions_service.dart';
import '../services/location_service.dart';
import '../widgets/map3d_view.dart';

/// "Get Directions" pour UNE destination : carte 3D avec le trajet à pied
/// depuis la position actuelle, et les instructions pas-à-pas.
/// Contrairement à ItineraryMapScreen (plusieurs arrêts d'une sortie
/// planifiée), cet écran répond au besoin immédiat "je veux y aller
/// maintenant, montre-moi le chemin".
class DirectionsScreen extends StatefulWidget {
  final Destination destination;
  const DirectionsScreen({super.key, required this.destination});

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  geo.Position? _myPosition;
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

    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (pos == null) {
      setState(() {
        _loading = false;
        _error = "Impossible d'obtenir votre position actuelle.\n"
            "Vérifiez que la localisation est activée et autorisée pour l'application.";
      });
      return;
    }

    final route = await DirectionsService.fetchRoute([
      LatLng(pos.latitude, pos.longitude),
      LatLng(widget.destination.lat, widget.destination.lng),
    ]);

    if (!mounted) return;
    setState(() {
      _myPosition = pos;
      _route = route;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = widget.destination;

    return Scaffold(
      appBar: AppBar(title: Text('Itinéraire vers ${d.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Map3DView(
                        stops: [
                          Map3DStop(
                            point: LatLng(d.lat, d.lng),
                            label: '📍',
                            color: scheme.primary,
                          ),
                        ],
                        routePolyline: _route?.polyline,
                        myPosition: _myPosition != null
                            ? LatLng(_myPosition!.latitude, _myPosition!.longitude)
                            : null,
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
                              style: TextStyle(
                                  color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    else if (_myPosition != null)
                      Container(
                        width: double.infinity,
                        color: scheme.errorContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          'Trajet indisponible pour le moment (serveur de calcul d\'itinéraire '
                          'injoignable). Distance à vol d\'oiseau : '
                          '${LocationService.formatKm(LocationService.haversineKm(_myPosition!.latitude, _myPosition!.longitude, d.lat, d.lng))}.',
                          style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
                        ),
                      ),
                    if (_route != null && _route!.steps.isNotEmpty)
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _route!.steps.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final step = _route!.steps[i];
                            return ListTile(
                              leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                              title: Text(step.instruction),
                              trailing: Text(step.distanceLabel,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            );
                          },
                        ),
                      ),
                  ],
                ),
    );
  }
}
