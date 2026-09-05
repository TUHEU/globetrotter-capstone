import 'package:flutter/material.dart';

import '../core/api_client.dart';

/// "Activité en ce moment" — combien de voyageurs (via leurs itinéraires
/// publics) prévoient de visiter ce lieu aujourd'hui, demain, ou dans la
/// semaine. Calculé côté serveur à partir des vraies dates d'itinéraires
/// (start_date + jour de l'étape), pas un chiffre inventé.
class DestinationActivitySection extends StatefulWidget {
  final String destinationId;
  const DestinationActivitySection({super.key, required this.destinationId});

  @override
  State<DestinationActivitySection> createState() => _DestinationActivitySectionState();
}

class _DestinationActivitySectionState extends State<DestinationActivitySection> {
  int? _today;
  int? _tomorrow;
  int? _thisWeek;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.dio
          .get('/itineraries/destination-activity/${widget.destinationId}');
      if (!mounted) return;
      setState(() {
        _today = res.data['today'] as int? ?? 0;
        _tomorrow = res.data['tomorrow'] as int? ?? 0;
        _thisWeek = res.data['this_week'] as int? ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 16, width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    // Nothing planned anywhere in the next week - no need for a whole
    // section just to say "0 for everything".
    if (_failed || ((_today ?? 0) == 0 && (_tomorrow ?? 0) == 0 && (_thisWeek ?? 0) == 0)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final chips = <Widget>[
      if ((_today ?? 0) > 0) _activityChip('${_today} aujourd\'hui', Colors.green),
      if ((_tomorrow ?? 0) > 0) _activityChip('${_tomorrow} demain', Colors.orange),
      if ((_thisWeek ?? 0) > 0) _activityChip('${_thisWeek} cette semaine', theme.colorScheme.primary),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.groups_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('Activité prévue', style: theme.textTheme.titleSmall),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  Widget _activityChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
