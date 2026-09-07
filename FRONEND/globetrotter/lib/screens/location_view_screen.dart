import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../services/directions_service.dart';
import '../services/location_service.dart';
import '../widgets/map3d_view.dart';

/// Opens a shared chat location directly inside the app's own map instead
/// of handing off to an external Google Maps link - and, since knowing
/// WHERE something is only helps if you also know how to get there, also
/// fetches and draws the route from the viewer's own position to it, the
/// same way tapping a destination or "get directions" does elsewhere.
class LocationViewScreen extends StatefulWidget {
  final double lat;
  final double lng;
  final String label;

  const LocationViewScreen({
    super.key,
    required this.lat,
    required this.lng,
    this.label = 'Position',
  });

  @override
  State<LocationViewScreen> createState() => _LocationViewScreenState();
}

class _LocationViewScreenState extends State<LocationViewScreen> {
  LatLng? _myPosition;
  RouteResult? _route;
  TransportMode _mode = TransportMode.car;
  bool _loadingRoute = false;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() { _loadingRoute = true; _routeError = null; });
    final pos = await LocationService.getCurrentPosition();
    if (pos == null) {
      if (mounted) {
        setState(() {
          _loadingRoute = false;
          _routeError = 'Position actuelle indisponible - activez la localisation.';
        });
      }
      return;
    }
    final me = LatLng(pos.latitude, pos.longitude);
    final destination = LatLng(widget.lat, widget.lng);
    final route = await DirectionsService.fetchRoute([me, destination], mode: _mode);
    if (!mounted) return;
    setState(() {
      _myPosition = me;
      _route = route;
      _loadingRoute = false;
      if (route == null) _routeError = 'Itinéraire indisponible pour le moment.';
    });
  }

  Future<void> _changeMode(TransportMode mode) async {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    await _loadRoute();
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.lat, widget.lng);
    return Scaffold(
      appBar: AppBar(title: Text(widget.label)),
      body: Stack(
        children: [
          Map3DView(
            stops: [Map3DStop(point: point, label: widget.label, color: Colors.redAccent)],
            myPosition: _myPosition,
            routePolyline: _route?.polyline,
          ),
          if (_loadingRoute)
            const Positioned(
              top: 12, left: 0, right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: TransportMode.values.map((m) {
                        final selected = m == _mode;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ChoiceChip(
                              label: Text(m.label, style: const TextStyle(fontSize: 12)),
                              avatar: Icon(m.icon, size: 16),
                              selected: selected,
                              onSelected: (_) => _changeMode(m),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    if (_route != null)
                      Text(
                        '${_route!.distanceLabel} · ${_route!.durationLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      )
                    else if (_routeError != null)
                      Text(_routeError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
