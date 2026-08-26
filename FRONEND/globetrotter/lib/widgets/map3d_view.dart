import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Style vectoriel gratuit, sans clé API, avec bâtiments 3D déjà intégrés
/// (couche fill-extrusion "building" incluse nativement dans le style
/// "liberty") — fourni par OpenFreeMap (https://openfreemap.org), qui héberge
/// des tuiles vectorielles OSM en libre accès, usage illimité, sans compte.
const String kMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

/// Un point à afficher sur la carte 3D (arrêt d'itinéraire, destination...).
class Map3DStop {
  final LatLng point;
  final String label;
  final Color color;
  /// Optionnel : appelé quand l'utilisateur tape sur ce point précis (sur
  /// son cercle OU son étiquette). Laissé à null par les écrans qui
  /// n'affichent qu'un itinéraire fixe (directions_screen, itinerary_map_
  /// screen) - seule la carte générale (explore_map_screen) s'en sert pour
  /// naviguer vers la fiche du lieu tapé.
  final VoidCallback? onTap;
  Map3DStop({required this.point, required this.label, required this.color, this.onTap});
}

String _toHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

/// Carte 3D (immeubles en relief) avec position actuelle et tracé
/// d'itinéraire, basée sur MapLibre GL + OpenFreeMap. Remplace l'ancienne
/// carte 2D à tuiles plates (flutter_map) pour les écrans d'itinéraire.
class Map3DView extends StatefulWidget {
  final List<Map3DStop> stops;
  final List<LatLng>? routePolyline;
  final LatLng? myPosition;
  final bool initialTilt;

  const Map3DView({
    super.key,
    required this.stops,
    this.routePolyline,
    this.myPosition,
    this.initialTilt = true,
  });

  @override
  State<Map3DView> createState() => Map3DViewState();
}

class Map3DViewState extends State<Map3DView> {
  MapLibreMapController? _controller;
  late bool _tilted;

  @override
  void initState() {
    super.initState();
    _tilted = widget.initialTilt;
  }

  @override
  void didUpdateWidget(covariant Map3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null &&
        (oldWidget.stops != widget.stops ||
            oldWidget.routePolyline != widget.routePolyline ||
            oldWidget.myPosition != widget.myPosition)) {
      _drawAnnotations();
    }
  }

  void _onMapCreated(MapLibreMapController c) {
    _controller = c;
    // Enregistrés UNE SEULE FOIS ici (pas dans _drawAnnotations, qui elle
    // est rappelée à chaque changement de données) - sinon chaque redessin
    // ajouterait un nouveau listener en plus des précédents, et un seul
    // tap finirait par déclencher le callback plusieurs fois.
    c.onSymbolTapped.add(_handleAnnotationTap);
    c.onCircleTapped.add(_handleAnnotationTap);
  }

  void _handleAnnotationTap(dynamic annotation) {
    final index = annotation.data?['stopIndex'] as int?;
    if (index == null || index < 0 || index >= widget.stops.length) return;
    widget.stops[index].onTap?.call();
  }

  Future<void> _onStyleLoaded() async {
    await _drawAnnotations();
    _fitToContent();
  }

  Future<void> _drawAnnotations() async {
    final controller = _controller;
    if (controller == null) return;
    // On efface et redessine tout à chaque changement plutôt que de suivre
    // les identifiants un par un - la carte affiche au maximum quelques
    // dizaines de points (arrêts d'un itinéraire), donc le coût est
    // négligeable et le code reste simple et sans état à synchroniser.
    await controller.clearCircles();
    await controller.clearSymbols();
    await controller.clearLines();

    final route = widget.routePolyline;
    if (route != null && route.length >= 2) {
      await controller.addLine(LineOptions(
        geometry: route,
        lineColor: '#2563eb',
        lineWidth: 4.0,
        lineOpacity: 0.85,
      ));
    }

    for (var i = 0; i < widget.stops.length; i++) {
      final stop = widget.stops[i];
      await controller.addCircle(CircleOptions(
        geometry: stop.point,
        circleRadius: 14,
        circleColor: _toHex(stop.color),
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 2,
      ), {'stopIndex': i});
      await controller.addSymbol(SymbolOptions(
        geometry: stop.point,
        textField: stop.label,
        textColor: '#ffffff',
        textSize: 13,
      ), {'stopIndex': i});
    }

    final me = widget.myPosition;
    if (me != null) {
      await controller.addCircle(CircleOptions(
        geometry: me,
        circleRadius: 9,
        circleColor: '#2563eb',
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 3,
      ));
    }
  }

  void _fitToContent() {
    final controller = _controller;
    if (controller == null) return;
    final points = [
      ...widget.stops.map((s) => s.point),
      if (widget.myPosition != null) widget.myPosition!,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: points.first, zoom: 16, tilt: _tilted ? 55 : 0),
      ));
      return;
    }
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, left: 56, top: 56, right: 56, bottom: 56),
    );
  }

  /// Bascule entre vue à plat (0°) et vue inclinée façon "3D" (55°) — les
  /// bâtiments ne prennent du relief visuel qu'avec une caméra inclinée,
  /// exactement comme sur Google Maps / Apple Plans.
  void toggleTilt() {
    final controller = _controller;
    if (controller == null) return;
    final current = controller.cameraPosition;
    setState(() => _tilted = !_tilted);
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: current?.target ??
          (widget.stops.isNotEmpty ? widget.stops.first.point : widget.myPosition!),
      zoom: current?.zoom ?? 16,
      bearing: current?.bearing ?? 0,
      tilt: _tilted ? 55 : 0,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.stops.isNotEmpty
        ? widget.stops.first.point
        : (widget.myPosition ?? const LatLng(3.8480, 11.5021));
    return Stack(
      children: [
        MapLibreMap(
          styleString: kMapStyleUrl,
          // On dessine nous-mêmes le point "vous êtes ici" via _drawAnnotations
          // (cohérent avec les marqueurs des arrêts, et fonctionne pareil sur
          // Web où le point bleu natif de MapLibre n'est pas disponible).
          myLocationEnabled: false,
          initialCameraPosition:
              CameraPosition(target: initial, zoom: 15, tilt: _tilted ? 55 : 0),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          compassEnabled: true,
          trackCameraPosition: true,
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: _tilted ? '2D' : '3D',
            onPressed: toggleTilt,
            child: Icon(_tilted ? Icons.map_outlined : Icons.view_in_ar_outlined),
          ),
        ),
      ],
    );
  }
}
