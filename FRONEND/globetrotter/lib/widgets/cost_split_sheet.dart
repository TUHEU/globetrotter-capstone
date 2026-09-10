import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/friend.dart';
import '../providers/friends_provider.dart';
import '../services/share_service.dart';

/// Partage du coût d'une sortie entre amis : sélection de N amis parmi la
/// liste "following" (les gens qu'on suit déjà - même source que le reste
/// de l'app pour "mes amis"), calcul d'une répartition égale, puis
/// partage du résumé via ShareService (WhatsApp, SMS, etc. selon ce que
/// le téléphone propose).
///
/// Volontairement simple : pas de répartition inégale, pas de suivi "qui
/// a payé/remboursé" côté serveur - juste le calcul et le partage du
/// montant par personne.
Future<void> showCostSplitSheet(
  BuildContext context, {
  required String tripTitle,
  required int totalFcfa,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CostSplitSheet(tripTitle: tripTitle, totalFcfa: totalFcfa),
  );
}

class _CostSplitSheet extends StatefulWidget {
  final String tripTitle;
  final int totalFcfa;
  const _CostSplitSheet({required this.tripTitle, required this.totalFcfa});

  @override
  State<_CostSplitSheet> createState() => _CostSplitSheetState();
}

class _CostSplitSheetState extends State<_CostSplitSheet> {
  final Set<String> _selectedIds = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final friends = context.read<FriendsProvider>();
    if (friends.following.isEmpty) {
      friends.loadFollowLists().then((_) {
        if (mounted) setState(() => _loaded = true);
      });
    } else {
      _loaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = context.watch<FriendsProvider>().following;
    final peopleCount = _selectedIds.length + 1; // +1 = moi-même
    final perPerson = (widget.totalFcfa / peopleCount).ceil();

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Partager le coût', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Budget estimé : ${widget.totalFcfa} FCFA',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          Text('Avec qui ?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (!_loaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (following.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Vous ne suivez encore personne - ajoutez des amis pour partager un coût avec eux.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: following.length,
                itemBuilder: (_, i) {
                  final Friend f = following[i];
                  final selected = _selectedIds.contains(f.id);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected,
                    title: Text(f.fullName),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedIds.add(f.id);
                      } else {
                        _selectedIds.remove(f.id);
                      }
                    }),
                  );
                },
              ),
            ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$peopleCount personne${peopleCount > 1 ? 's' : ''}'),
                Text(
                  '$perPerson FCFA / personne',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Partager la répartition'),
            onPressed: () {
              final names = _selectedIds
                  .map((id) => following.firstWhere((f) => f.id == id).fullName)
                  .join(', ');
              final text = _selectedIds.isEmpty
                  ? '${widget.tripTitle} : ${widget.totalFcfa} FCFA au total.'
                  : '${widget.tripTitle} : ${widget.totalFcfa} FCFA au total, '
                      'partagé entre $peopleCount personnes ($names + moi) '
                      '= $perPerson FCFA chacun.';
              ShareService.shareText(text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
