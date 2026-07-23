import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/destination.dart';
import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../providers/itinerary_provider.dart';

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
      final p = context.read<DestinationProvider>();
      if (p.destinations.isEmpty) p.search(q: '');
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one destination')));
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
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Itinerary created!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New itinerary')),
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
                  decoration: const InputDecoration(
                      labelText: 'Trip title', prefixIcon: Icon(Icons.title)),
                  validator: (v) =>
                      v != null && v.trim().length >= 2 ? null : 'Give it a title',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: Icon(Icons.notes)),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_start == null ? 'Start date' : _fmt(_start!)),
                      onPressed: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(_end == null ? 'End date' : _fmt(_end!)),
                      onPressed: () => _pickDate(false),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sharedWith,
                  decoration: const InputDecoration(
                    labelText: 'Share with (emails, comma separated)',
                    prefixIcon: Icon(Icons.group_outlined),
                    helperText: 'Friends & family will see this trip',
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Text('Stops', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                      onPressed: _addStop,
                      icon: const Icon(Icons.add),
                      label: const Text('Add stop')),
                ]),
                ..._stops.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        Row(children: [
                          CircleAvatar(radius: 14, child: Text('${i + 1}')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  '${s.destination.name} — ${s.destination.quartier}',
                                  style: Theme.of(context).textTheme.titleSmall)),
                          DropdownButton<int>(
                            value: s.day,
                            items: List.generate(30, (d) => d + 1)
                                .map((d) => DropdownMenuItem(
                                    value: d, child: Text('Day $d')))
                                .toList(),
                            onChanged: (v) => setState(() => s.day = v ?? 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => _stops.removeAt(i)),
                          ),
                        ]),
                        TextField(
                          controller: s.notes,
                          decoration: const InputDecoration(
                              hintText: 'Notes (optional)', isDense: true),
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
                      : const Text('Create itinerary'),
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
