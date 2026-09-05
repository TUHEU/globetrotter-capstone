import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../widgets/map3d_view.dart';

/// Opens a shared chat location directly inside the app's own map instead
/// of handing off to an external Google Maps link.
class LocationViewScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Map3DView(
        stops: [Map3DStop(point: point, label: label, color: Colors.redAccent)],
      ),
    );
  }
}
