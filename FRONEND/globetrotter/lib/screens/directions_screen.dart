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
  bool _routeLoading = false;
  String? _error;
  StreamSubscription<geo.Position>? _positionSub;
  TransportMode _mode = TransportMode.walk;

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

    final route = await DirectionsService.fetchRoute(
      [
        LatLng(pos.latitude, pos.longitude),
        LatLng(widget.destination.lat, widget.destination.lng),
      ],
      profile: _mode.osrmProfile,
    );

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

  /// Change de mode de transport (à pied / vélo / voiture) et recalcule
  /// UNIQUEMENT le trajet - pas besoin de redemander la position GPS,
  /// qu'on a déjà. Évite un aller-retour permission/GPS à chaque bascule.
  Future<void> _onModeChanged(TransportMode mode) async {
    if (mode == _mode || _myPosition == null) {
      setState(() => _mode = mode);
      return;
    }
    setState(() {
      _mode = mode;
      _routeLoading = true;
    });
    final route = await DirectionsService.fetchRoute(
      [
        LatLng(_myPosition!.latitude, _myPosition!.longitude),
        LatLng(widget.destination.lat, widget.destination.lng),
      ],
      profile: mode.osrmProfile,
    );
    if (!mounted) return;
    setState(() {
      _route = route;
      _routeLoading = false;
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: SegmentedButton<TransportMode>(
                        segments: TransportMode.values
                            .map((m) => ButtonSegment(
                                  value: m,
                                  icon: Icon(m.icon, size: 18),
                                  label: Text(m.label),
                                ))
                            .toList(),
                        selected: {_mode},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => _onModeChanged(s.first),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Map3DView(
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
                          if (_routeLoading)
                            const Positioned(
                              top: 12, right: 12,
                              child: SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
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
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(_mode.icon,
                                      color: scheme.onPrimaryContainer, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Trajet ${_mode.label.toLowerCase()} : ${_route!.distanceLabel} · ${_route!.durationLabel}',
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
