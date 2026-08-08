import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'package:geolocator/geolocator.dart' as geo;

import '../models/destination.dart';
import '../services/directions_service.dart';
import '../services/location_service.dart';
import '../widgets/direction_arrow.dart';
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
  StreamSubscription<geo.Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
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

    // Une fois le premier point + trajet obtenus, on passe en écoute
    // continue - la flèche directionnelle (DirectionArrow) et le point
    // "vous êtes ici" sur la carte se mettent à jour en marchant, sans
    // avoir à quitter puis rouvrir cet écran.
    _positionSub = LocationService.watchPosition().listen((p) {
      if (mounted) setState(() => _myPosition = p);
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
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.directions_walk,
                                      color: scheme.onPrimaryContainer, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Trajet à pied : ${_route!.distanceLabel} · ${_route!.durationLabel}',
                                      style: TextStyle(
                                          color: scheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // La flèche vit ICI (pas seulement sur la carte) pour
                            // rester visible même quand on regarde la liste des
                            // instructions plus bas plutôt que la carte elle-même.
                            DirectionArrow(
                              myLat: _myPosition?.latitude,
                              myLng: _myPosition?.longitude,
                              targetLat: d.lat,
                              targetLng: d.lng,
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
                          separatorBuilder: (_, _) => const Divider(height: 1),
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
