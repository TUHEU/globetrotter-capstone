import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../models/destination.dart';
import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/settings_provider.dart';
import '../services/location_service.dart';

class CreateItineraryScreen extends StatefulWidget {
  final Destination? preselected;
  const CreateItineraryScreen({super.key, this.preselected});

  @override
  State<CreateItineraryScreen> createState() => _CreateItineraryScreenState();
}

class _StopDraft {
  Destination destination;
  int day;
  final TextEditingController notes = TextEditingController();
  _StopDraft(this.destination, this.day);
}

class _CreateItineraryScreenState extends State<CreateItineraryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _sharedWith = TextEditingController();
  final _budget = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _isPublic = false;
  final List<_StopDraft> _stops = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselected != null) {
      _stops.add(_StopDraft(widget.preselected!, 1));
    }
    // make sure destinations are loaded for the picker
    Future.microtask(() {
      if (!mounted) return;
      final p = context.read<DestinationProvider>();
      if (p.destinations.isEmpty) p.search(q: '');
    });
  }

  @override
  void dispose() {
    // Aucun dispose() n'existait avant pour ces contrôleurs (fuite mineure
    // pré-existante) - corrigé au passage puisque ce fichier était déjà
    // ouvert pour ajouter le champ budget.
    _title.dispose();
    _description.dispose();
    _sharedWith.dispose();
    _budget.dispose();
    for (final stop in _stops) {
      stop.notes.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Réordonne les arrêts JOUR PAR JOUR (jamais entre jours différents -
  /// l'utilisateur a choisi ces regroupements volontairement, ce n'est pas
  /// à optimiser) selon un algorithme glouton du plus proche voisin :
  /// part du premier arrêt tel que saisi (respecte le point de départ
  /// choisi par l'utilisateur, ex: son hôtel), puis choisit à chaque étape
  /// l'arrêt restant le plus proche du précédent. Ce n'est pas la tournée
  /// mathématiquement optimale (le problème du voyageur de commerce est
  /// NP-difficile), mais un résultat glouton "raisonnable en pratique" -
  /// largement suffisant ici : réduire concrètement les allers-retours
  /// inutiles pour 2 à 6 arrêts par jour, pas calculer un itinéraire
  /// parfait sur 50 villes.
  void _optimizeStopOrder() {
    final byDay = <int, List<_StopDraft>>{};
    for (final s in _stops) {
      byDay.putIfAbsent(s.day, () => []).add(s);
    }

    final optimized = <_StopDraft>[];
    for (final day in byDay.keys.toList()..sort()) {
      final remaining = List<_StopDraft>.from(byDay[day]!);
      if (remaining.length <= 2) {
        // Rien à réordonner en dessous de 3 arrêts - toutes les tournées
        // possibles font la même distance totale (aller-retour A→B→A).
        optimized.addAll(remaining);
        continue;
      }
      var current = remaining.removeAt(0);
      final dayOrdered = [current];
      while (remaining.isNotEmpty) {
        remaining.sort((a, b) {
          final da = LocationService.haversineKm(
              current.destination.lat, current.destination.lng, a.destination.lat, a.destination.lng);
          final db = LocationService.haversineKm(
              current.destination.lat, current.destination.lng, b.destination.lat, b.destination.lng);
          return da.compareTo(db);
        });
        current = remaining.removeAt(0);
        dayOrdered.add(current);
      }
      optimized.addAll(dayOrdered);
    }

    setState(() {
      _stops
        ..clear()
        ..addAll(optimized);
    });

    if (mounted) {
      final s = context.read<SettingsProvider>().s;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.routeOptimized)));
    }
  }

  Future<void> _pickDate(bool isStart) async {
    // BUG CORRIGÉ : firstDate soustrayait 1 jour, autorisant hier (et
    // laissait même parfois sélectionner des dates plus anciennes selon
    // l'heure locale). On tronque "aujourd'hui" à minuit pour que la date
    // du jour reste sélectionnable tout en bloquant strictement le passé.
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _addStop() async {
    final destinations = context.read<DestinationProvider>().destinations;
    final chosen = await showModalBottomSheet<Destination>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: destinations
            .map((d) => ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(d.name),
                  subtitle: Text(d.quartier),
                  onTap: () => Navigator.pop(context, d),
                ))
            .toList(),
      ),
    );
    if (chosen != null) {
      setState(() => _stops.add(_StopDraft(chosen, _stops.length + 1)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final s0 = context.read<SettingsProvider>().s;
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s0.atLeastOneDestination)));
      return;
    }
    setState(() => _saving = true);
    final shared = _sharedWith.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final err = await context.read<ItineraryProvider>().create(
          title: _title.text.trim(),
          description:
              _description.text.trim().isEmpty ? null : _description.text.trim(),
          startDate: _start != null ? _fmt(_start!) : null,
          endDate: _end != null ? _fmt(_end!) : null,
          stops: _stops
              .map((s) => ItineraryStop(
                    destinationId: s.destination.id,
                    day: s.day,
                    notes: s.notes.text.trim().isEmpty ? null : s.notes.text.trim(),
                  ))
              .toList(),
          sharedWith: shared,
          isPublic: _isPublic,
          budgetFcfa: _budget.text.trim().isEmpty ? null : int.tryParse(_budget.text.trim()),
        );
    if (!mounted) return;
    final s = context.read<SettingsProvider>().s;
    setState(() => _saving = false);
    if (err == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.isFr ? 'Sortie créée !' : 'Trip created!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(err, s))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    return Scaffold(
      appBar: AppBar(title: Text(s.newItineraryTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(
                      labelText: s.tripTitleLabel, prefixIcon: const Icon(Icons.title)),
                  validator: (v) =>
                      v != null && v.trim().length >= 2 ? null : s.giveItATitle,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: InputDecoration(
                      labelText: s.descriptionOptional,
                      prefixIcon: const Icon(Icons.notes)),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_start == null ? s.startDate : _fmt(_start!)),
                      onPressed: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(_end == null ? s.endDate : _fmt(_end!)),
                      onPressed: () => _pickDate(false),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sharedWith,
                  decoration: InputDecoration(
                    labelText: s.shareWithLabel,
                    prefixIcon: const Icon(Icons.group_outlined),
                    helperText: s.shareWithHelper,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: s.budgetLabel,
                    prefixIcon: const Icon(Icons.savings_outlined),
                    suffixText: 'FCFA',
                    helperText: s.budgetHelper,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.public),
                  title: Text(s.makePublic),
                  subtitle: Text(s.makePublicHelper),
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Text(s.stopsLabel, style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (_stops.length >= 3)
                    TextButton.icon(
                        onPressed: _optimizeStopOrder,
                        icon: const Icon(Icons.route_outlined, size: 18),
                        label: Text(s.optimizeRoute)),
                  TextButton.icon(
                      onPressed: _addStop,
                      icon: const Icon(Icons.add),
                      label: Text(s.addStop)),
                ]),
                ..._stops.asMap().entries.map((entry) {
                  final i = entry.key;
                  final stop = entry.value;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        Row(children: [
                          CircleAvatar(radius: 14, child: Text('${i + 1}')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  '${stop.destination.name} — ${stop.destination.quartier}',
                                  style: Theme.of(context).textTheme.titleSmall)),
                          DropdownButton<int>(
                            value: stop.day,
                            items: List.generate(30, (d) => d + 1)
                                .map((d) => DropdownMenuItem(
                                    value: d, child: Text(s.dayLabel(d))))
                                .toList(),
                            onChanged: (v) => setState(() => stop.day = v ?? 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() {
                                  _stops[i].notes.dispose();
                                  _stops.removeAt(i);
                                }),
                          ),
                        ]),
                        TextField(
                          controller: stop.notes,
                          decoration: InputDecoration(
                              hintText: s.notesOptional, isDense: true),
                        ),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 28),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: _saving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(s.createItinerary),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
