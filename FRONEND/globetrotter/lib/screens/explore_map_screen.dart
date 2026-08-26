import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/destination.dart';
import '../providers/destination_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/map3d_view.dart';
import 'destination_detail_screen.dart';

/// Carte générale de Yaoundé montrant TOUS les lieux de l'app en même
/// temps (81 marqueurs, un par destination) - taper sur un marqueur ouvre
/// directement la fiche du lieu, sans repasser par la recherche/liste.
/// Contrairement à directions_screen/itinerary_map_screen (qui affichent
/// un trajet précis), cet écran n'a pas de position GPS ni d'itinéraire :
/// c'est une vue d'ensemble pour explorer visuellement la ville.
class ExploreMapScreen extends StatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  String? _activeCategory;

  @override
  void initState() {
    super.initState();
    // La liste globale (sans filtre) est déjà chargée dès l'ouverture de
    // l'app par l'onglet Explorer - on ne relance un appel réseau que si,
    // par hasard, cet écran est ouvert avant que ce chargement initial
    // n'ait eu lieu (ex: lien profond, ou providers réinitialisés).
    final p = context.read<DestinationProvider>();
    if (p.destinations.isEmpty && !p.loading) {
      p.search();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DestinationProvider>();
    final s = context.watch<SettingsProvider>().s;
    final theme = Theme.of(context);

    final visible = _activeCategory == null
        ? p.destinations
        : p.destinations.where((d) => d.category == _activeCategory).toList();

    final stops = visible
        .map((d) => Map3DStop(
              point: LatLng(d.lat, d.lng),
              label: d.name.length > 14 ? '${d.name.substring(0, 13)}…' : d.name,
              color: PlaceCategories.colors[d.category] ?? theme.colorScheme.primary,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DestinationDetailScreen(destination: d))),
            ))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.exploreMapTitle)),
      body: p.loading && p.destinations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(s.all),
                          selected: _activeCategory == null,
                          onSelected: (_) => setState(() => _activeCategory = null),
                        ),
                      ),
                      ...PlaceCategories.all.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: Icon(e.value, size: 15),
                              label: Text(PlaceCategories.labels[e.key] ?? e.key),
                              selected: _activeCategory == e.key,
                              onSelected: (sel) =>
                                  setState(() => _activeCategory = sel ? e.key : null),
                            ),
                          )),
                    ],
                  ),
                ),
                Expanded(
                  child: stops.isEmpty
                      ? Center(child: Text(s.noResults))
                      : Map3DView(stops: stops, initialTilt: false),
                ),
              ],
            ),
    );
  }
}
