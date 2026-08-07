import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../models/destination.dart';
import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/settings_provider.dart';

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

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
                            onPressed: () => setState(() => _stops.removeAt(i)),
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
