import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/itinerary.dart';
import '../providers/settings_provider.dart';
import 'comments_sheet.dart';

/// Barre "like + commentaires" sous une sortie, dans le fil des amis. Gère
/// elle-même l'appel API du like (mise à jour optimiste) - le parent n'a
/// qu'à lui passer l'itinéraire et se faire notifier du nouvel état via
/// [onChanged] pour le refléter dans sa propre liste locale.
class LikeCommentBar extends StatefulWidget {
  final Itinerary itinerary;
  final ValueChanged<Itinerary> onChanged;

  const LikeCommentBar({super.key, required this.itinerary, required this.onChanged});

  @override
  State<LikeCommentBar> createState() => _LikeCommentBarState();
}

class _LikeCommentBarState extends State<LikeCommentBar> {
  bool _liking = false;

  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() => _liking = true);
    final it = widget.itinerary;
    // Mise à jour optimiste immédiate.
    final optimistic = it.copyWith(
      likedByMe: !it.likedByMe,
      likeCount: it.likedByMe ? it.likeCount - 1 : it.likeCount + 1,
    );
    widget.onChanged(optimistic);
    try {
      final res = await ApiClient.instance.dio.post('/itineraries/${it.id}/like');
      widget.onChanged(it.copyWith(
        likedByMe: res.data['liked'],
        likeCount: res.data['like_count'],
      ));
    } catch (_) {
      widget.onChanged(it); // revert
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final it = widget.itinerary;
    final theme = Theme.of(context);

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _toggleLike,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  it.likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: it.likedByMe ? Colors.redAccent : theme.colorScheme.onSurfaceVariant,
                ),
                if (it.likeCount > 0) ...[
                  const SizedBox(width: 6),
                  Text('${it.likeCount}', style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final updated = await showModalBottomSheet<int>(
              context: context,
              isScrollControlled: true,
              builder: (_) => CommentsSheet(itineraryId: it.id),
            );
            if (updated != null) {
              widget.onChanged(it.copyWith(commentCount: updated));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.mode_comment_outlined,
                    size: 19, color: theme.colorScheme.onSurfaceVariant),
                if (it.commentCount > 0) ...[
                  const SizedBox(width: 6),
                  Text('${it.commentCount}', style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        const Spacer(),
        Text(s.likesCount(it.likeCount),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}
