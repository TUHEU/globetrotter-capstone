import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:provider/provider.dart';

import 'package:geolocator/geolocator.dart' as geo;

import '../models/destination.dart';
import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/itinerary_provider.dart';
import '../services/directions_service.dart';
import '../services/location_service.dart';
import '../services/pdf_export_service.dart';
import '../services/route_optimizer.dart';
import '../services/trip_reminder_service.dart';
import '../services/weather_service.dart';
import '../widgets/budget_summary_card.dart';
import '../widgets/cost_split_sheet.dart';
import '../widgets/map3d_view.dart';
import 'directions_screen.dart';

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

/// Avertissement météo pour la sortie complète - vérifie chaque arrêt (la
/// météo est déjà récupérée pour tous dans _load(), rien de nouveau à
/// aller chercher ici) et liste nommément les lieux concernés par de la
/// pluie plutôt qu'un message générique "il pleut quelque part".
class _RainWarningBanner extends StatelessWidget {
  final List<_StopPoint> points;
  const _RainWarningBanner({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rainy = points.where((p) => p.weather?.isRainy == true).toList();
    if (rainy.isEmpty) return const SizedBox.shrink();

    final names = rainy.map((p) => p.destination.name).join(', ');
    final s = context.watch<SettingsProvider>().s;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌧️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.rainWarning(names), style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ItineraryMapScreenState extends State<ItineraryMapScreen> {
  List<_StopPoint> _points = [];
  RouteResult? _route;
  bool _loading = true;
  bool _routeLoading = false;
  String? _error;
  geo.Position? _myPosition;
  bool _showDirections = false;
  TransportMode _mode = TransportMode.walk;

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
        mode: _mode,
      );
    }

    if (!mounted) return;
    setState(() {
      _points = resolved;
      _route = route;
      _loading = false;
    });
  }

  /// Change de mode de transport et recalcule uniquement le trajet entre
  /// les arrêts déjà connus - pas besoin de refaire tous les appels météo
  /// ni de recharger les destinations.
  Future<void> _onModeChanged(TransportMode mode) async {
    if (_points.length < 2) {
      setState(() => _mode = mode);
      return;
    }
    setState(() {
      _mode = mode;
      _routeLoading = true;
    });
    final route = await DirectionsService.fetchRoute(
      _points.map((p) => LatLng(p.destination.lat, p.destination.lng)).toList(),
      mode: mode,
    );
    if (!mounted) return;
    setState(() {
      _route = route;
      _routeLoading = false;
    });
  }

  Future<void> _optimizeRoute() async {
    final destProvider = context.read<DestinationProvider>();
    final currentStops = widget.itinerary.stops;
    final optimized = RouteOptimizer.optimize(currentStops, destProvider.byId);

    final beforeKm = RouteOptimizer.totalDistanceKm(currentStops, destProvider.byId);
    final afterKm = RouteOptimizer.totalDistanceKm(optimized, destProvider.byId);
    final sameOrder = optimized.map((s) => s.destinationId).join(',') ==
        currentStops.map((s) => s.destinationId).join(',');

    if (!mounted) return;

    if (sameOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet itinéraire est déjà optimal.')),
      );
      return;
    }

    // Confirmation avant d'appliquer - on ne réordonne jamais silencieusement
    // les arrêts d'une sortie déjà créée sans que l'utilisateur le valide.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Optimiser le trajet ?'),
        content: Text(
          beforeKm > 0
              ? 'Distance actuelle : ${beforeKm.toStringAsFixed(1)} km\n'
                  'Distance optimisée : ${afterKm.toStringAsFixed(1)} km\n'
                  '(soit ${(beforeKm - afterKm).toStringAsFixed(1)} km de moins)\n\n'
                  'Le premier arrêt de chaque jour reste inchangé ; seuls les '
                  'arrêts suivants sont réordonnés pour réduire les trajets.'
              : 'Les arrêts vont être réordonnés pour réduire les trajets entre eux.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Appliquer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final err = await context.read<ItineraryProvider>().updateStops(widget.itinerary.id, optimized);
    if (!mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Trajet optimisé !')));
      _load(); // recharge la carte/le trajet avec le nouvel ordre
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Échec de l'optimisation")));
    }
  }

  Future<void> _exportPdf() async {
    final stops = [
      for (final p in _points) MapEntry(p.stop, p.destination),
    ];
    try {
      await PdfExportService.exportAndShare(itinerary: widget.itinerary, stops: stops);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Échec de l'export PDF : $e")));
    }
  }

  Future<void> _scheduleReminder() async {
    final raw = widget.itinerary.startDate;
    final startDate = raw != null ? DateTime.tryParse(raw) : null;
    if (startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cette sortie n'a pas de date de début définie.")),
      );
      return;
    }
    try {
      final scheduled = await TripReminderService.instance.scheduleReminder(
        itineraryId: widget.itinerary.id,
        title: widget.itinerary.title,
        startDate: startDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(scheduled
            ? 'Rappel programmé pour la veille à 9h.'
            : "Trop tard pour programmer un rappel (la sortie commence dans moins de 24h)."),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Échec de la programmation du rappel : $e')));
    }
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
      appBar: AppBar(
        title: Text(widget.itinerary.title),
        actions: [
          // "Le chemin pour y aller" - CE QUE cet écran ne montrait pas
          // avant : le trajet entre les arrêts de la sortie (ci-dessous)
          // n'inclut PAS la position actuelle de l'utilisateur - seulement
          // les arrêts entre eux. Ce bouton ouvre le même DirectionsScreen
          // (flèche boussole live + itinéraire OSRM) que sur la fiche d'un
          // lieu, mais ciblant le PREMIER arrêt du jour - pour vraiment
          // "aller sur son voyage" depuis où on se trouve maintenant.
          if (_points.isNotEmpty)
            IconButton(
              tooltip: 'Itinéraire depuis ma position',
              icon: const Icon(Icons.directions_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DirectionsScreen(destination: _points.first.destination))),
            ),
          // Optimisation du trajet (plus proche voisin, jour par jour) -
          // désactivé sous 3 arrêts, où il n'y a de toute façon rien à
          // réordonner (voir RouteOptimizer._optimizeDay).
          if (widget.itinerary.stops.length >= 3)
            IconButton(
              tooltip: 'Optimiser le trajet',
              icon: const Icon(Icons.route_outlined),
              onPressed: _optimizeRoute,
            ),
          if (_points.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Plus d\'options',
              onSelected: (value) {
                switch (value) {
                  case 'pdf':
                    _exportPdf();
                    break;
                  case 'split':
                    showCostSplitSheet(
                      context,
                      tripTitle: widget.itinerary.title,
                      totalFcfa: _points.fold<int>(0, (sum, p) => sum + p.destination.avgPriceFcfa),
                    );
                    break;
                  case 'remind':
                    _scheduleReminder();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Exporter en PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'split',
                  child: ListTile(
                    leading: Icon(Icons.call_split),
                    title: Text('Partager le coût'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (widget.itinerary.startDate != null)
                  const PopupMenuItem(
                    value: 'remind',
                    child: ListTile(
                      leading: Icon(Icons.notifications_active_outlined),
                      title: Text('Me le rappeler'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : Column(
                  children: [
                    if (_points.any((p) => p.weather?.isRainy == true))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: _RainWarningBanner(points: _points),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: BudgetSummaryCard(itinerary: widget.itinerary),
                    ),
                    if (_points.length >= 2)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
                            stops: stops,
                            // Plus besoin de convertir point par point : RouteResult.polyline
                            // est maintenant déjà en LatLng maplibre_gl (voir directions_service.dart).
                            routePolyline: _route?.polyline,
                            myPosition: myLatLng,
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
                                Icon(_mode.icon, color: scheme.onPrimaryContainer, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Trajet ${_mode.label.toLowerCase()} : ${_route!.distanceLabel} · ${_route!.durationLabel}',
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
