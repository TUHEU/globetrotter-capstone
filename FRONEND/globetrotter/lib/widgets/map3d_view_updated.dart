import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Stops à afficher sur la carte
class Map3DStop {
  final LatLng point;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  Map3DStop({
    required this.point,
    required this.label,
    required this.color,
    this.onTap,
  });
}

class Map3DView extends StatefulWidget {
  final List<Map3DStop> stops;
  final bool initialTilt;

  const Map3DView({
    Key? key,
    required this.stops,
    this.initialTilt = true,
  }) : super(key: key);

  @override
  State<Map3DView> createState() => _Map3DViewState();
}

class _Map3DViewState extends State<Map3DView> {
  late MapLibreMapController mapController;
  String _mapStyle = 'streets'; // 'streets', 'satellite', '3d'
  bool _is3DEnabled = false;
  
  // Coordonnées par défaut pour Yaoundé
  static const double _initialLat = 3.8667;
  static const double _initialLng = 11.5167;
  static const double _initialZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _mapStyle = widget.initialTilt ? '3d' : 'streets';
    _is3DEnabled = widget.initialTilt;
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
    _updateMapStyle();
  }

  void _updateMapStyle() {
    switch (_mapStyle) {
      case 'streets':
        mapController.setStyle(
          'https://api.mapbox.com/styles/v1/mapbox/streets-v12?access_token=YOUR_MAPBOX_TOKEN',
        );
        break;
      case 'satellite':
        mapController.setStyle(
          'https://api.mapbox.com/styles/v1/mapbox/satellite-v9?access_token=YOUR_MAPBOX_TOKEN',
        );
        break;
      case '3d':
        mapController.setStyle(
          'https://api.mapbox.com/styles/v1/mapbox/streets-v12?access_token=YOUR_MAPBOX_TOKEN',
        );
        // Enable 3D pitch
        mapController.setPitch(45.0);
        break;
    }
  }

  void _switchToStreets() {
    setState(() {
      _mapStyle = 'streets';
      _is3DEnabled = false;
    });
    _updateMapStyle();
  }

  void _switchToSatellite() {
    setState(() {
      _mapStyle = 'satellite';
      _is3DEnabled = false;
    });
    _updateMapStyle();
  }

  void _switchTo3D() {
    setState(() {
      _mapStyle = '3d';
      _is3DEnabled = true;
    });
    _updateMapStyle();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map widget
        MapLibreMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: const CameraPosition(
            target: LatLng(_initialLat, _initialLng),
            zoom: _initialZoom,
          ),
          styleString:
              'https://api.mapbox.com/styles/v1/mapbox/streets-v12?access_token=YOUR_MAPBOX_TOKEN',
          onStyleLoadedCallback: () {
            // Ajouter les marqueurs après le chargement du style
            for (final stop in widget.stops) {
              mapController.addSymbol(
                SymbolOptions(
                  geometry: stop.point,
                  textField: stop.label,
                  textSize: 12,
                  iconImage: 'marker',
                  iconColor: '#${stop.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
                ),
              );
            }
          },
          myLocationRenderingMode: MyLocationRenderingMode.normal,
          myLocationTrackingMode: MyLocationTrackingMode.none,
          minMaxZoomPreference: const MinMaxZoomPreference(2, 21),
        ),
        
        // 3D/Satellite/Streets toggle - positionnement TOP-RIGHT
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Streets view
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _switchToStreets,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(_mapStyle == 'streets' ? 12 : 0),
                        bottomLeft: Radius.circular(_mapStyle == 'streets' ? 12 : 0),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _mapStyle == 'streets'
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                        child: Icon(
                          Icons.map,
                          color: _mapStyle == 'streets'
                              ? const Color(0xFF4CAF50)
                              : Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 1),
                  // Satellite view
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _switchToSatellite,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _mapStyle == 'satellite'
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          Icons.satellite,
                          color: _mapStyle == 'satellite'
                              ? const Color(0xFF4CAF50)
                              : Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 1),
                  // 3D view
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _switchTo3D,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(_mapStyle == '3d' ? 12 : 0),
                        bottomRight: Radius.circular(_mapStyle == '3d' ? 12 : 0),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _mapStyle == '3d'
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Icon(
                          Icons.view_in_ar,
                          color: _mapStyle == '3d'
                              ? const Color(0xFF4CAF50)
                              : Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Current view indicator
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              _mapStyle == 'streets'
                  ? 'Vue Routes'
                  : _mapStyle == 'satellite'
                      ? 'Satellite'
                      : 'Vue 3D',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F2418),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
