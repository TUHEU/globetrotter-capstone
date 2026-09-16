import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class Map3DView extends StatefulWidget {
  final List<LatLng>? waypoints;
  final LatLng? userLocation;
  final String? initialMapStyle;
  final bool showControls;
  final Function(MapLibreMapController)? onMapCreated;

  const Map3DView({
    Key? key,
    this.waypoints,
    this.userLocation,
    this.initialMapStyle,
    this.showControls = true,
    this.onMapCreated,
  }) : super(key: key);

  @override
  State<Map3DView> createState() => _Map3DViewState();
}

class _Map3DViewState extends State<Map3DView> {
  late MapLibreMapController mapController;
  String _mapStyle = 'streets';

  @override
  void initState() {
    super.initState();
    _mapStyle = widget.initialMapStyle ?? 'streets';
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  void _switchToStreets() {
    setState(() => _mapStyle = 'streets');
  }

  void _switchToSatellite() {
    setState(() => _mapStyle = 'satellite');
  }

  void _switchTo3D() {
    setState(() => _mapStyle = '3d');
  }

  @override
  Widget build(BuildContext context) {
    final defaultWaypoints = widget.waypoints ?? [LatLng(3.8480, 11.5021)];

    return Stack(
      children: [
        MapLibreMap(
          onMapCreated: (controller) {
            mapController = controller;
            widget.onMapCreated?.call(controller);

            if (defaultWaypoints.isNotEmpty) {
              _fitBounds(defaultWaypoints);
            }
          },
          initialCameraPosition: CameraPosition(
            target: defaultWaypoints.isNotEmpty
                ? defaultWaypoints.first
                : LatLng(3.8480, 11.5021),
            zoom: 12.0,
          ),
          styleString:
              'https://api.mapbox.com/styles/v1/mapbox/streets-v12?access_token=YOUR_MAPBOX_TOKEN',
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          zoomGesturesEnabled: true,
          compassEnabled: true,
          myLocationEnabled: false,
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
            ),
            child: Text(
              _mapStyle == 'streets'
                  ? '🛣️ Streets'
                  : _mapStyle == 'satellite'
                      ? '🛰️ Satellite'
                      : '🏢 3D',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        if (widget.showControls)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                _ModeButton(
                  icon: Icons.landscape,
                  label: 'Streets',
                  isActive: _mapStyle == 'streets',
                  onTap: _switchToStreets,
                ),
                _ModeButton(
                  icon: Icons.satellite_alt,
                  label: 'Satellite',
                  isActive: _mapStyle == 'satellite',
                  onTap: _switchToSatellite,
                ),
                _ModeButton(
                  icon: Icons.view_in_ar,
                  label: '3D',
                  isActive: _mapStyle == '3d',
                  onTap: _switchTo3D,
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _fitBounds(List<LatLng> waypoints) {
    if (waypoints.isEmpty) return;

    double minLat = waypoints.first.latitude;
    double maxLat = waypoints.first.latitude;
    double minLng = waypoints.first.longitude;
    double maxLng = waypoints.first.longitude;

    for (var point in waypoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    try {
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - 0.01, minLng - 0.01),
            northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
          ),
          left: 50,
          top: 150,
          right: 50,
          bottom: 150,
        ),
      );
    } catch (e) {
      debugPrint('Error fitting bounds: $e');
    }
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
          border: Border.all(
            color: isActive ? Colors.green : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.grey[700],
          size: 20,
        ),
      ),
    );
  }
}
