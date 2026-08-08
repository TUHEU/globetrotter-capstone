import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/itinerary_comment.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

/// Ouvert via showModalBottomSheet - se ferme en renvoyant le nouveau
/// nombre de commentaires (Navigator.pop(count)) pour que la carte
/// appelante (LikeCommentBar) puisse mettre à jour son compteur local
/// sans devoir recharger tout le fil.
class CommentsSheet extends StatefulWidget {
  final String itineraryId;
  const CommentsSheet({super.key, required this.itineraryId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  List<ItineraryComment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/itineraries/${widget.itineraryId}/comments');
      _comments = (res.data['results'] as List).map((j) => ItineraryComment.fromJson(j)).toList();
    } catch (_) {
      // Garde la liste vide plutôt que de planter la feuille.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await ApiClient.instance.dio
          .post('/itineraries/${widget.itineraryId}/comments', data: {'text': text});
      setState(() {
        _comments.add(ItineraryComment.fromJson(res.data));
        _controller.clear();
      });
    } catch (_) {
      if (mounted) {
        final s = context.read<SettingsProvider>().s;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.messageFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(ItineraryComment c) async {
    try {
      await ApiClient.instance.dio
          .delete('/itineraries/${widget.itineraryId}/comments/${c.id}');
      setState(() => _comments.removeWhere((x) => x.id == c.id));
    } catch (_) {
      // Silencieux : si la suppression échoue (ex: pas l'auteur), le
      // commentaire reste simplement affiché tel quel.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final myId = context.watch<AuthProvider>().user?.id;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(s.comments,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(_comments.length),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? Center(
                            child: Text(s.noComments,
                                style: const TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _comments.length,
                            itemBuilder: (_, i) {
                              final c = _comments[i];
                              final mine = c.userId == myId;
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  child: Text(c.userName.isNotEmpty
                                      ? c.userName[0].toUpperCase()
                                      : '?'),
                                ),
                                title: Text(c.userName,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(c.text),
                                trailing: mine
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        tooltip: s.deleteComment,
                                        onPressed: () => _delete(c),
                                      )
                                    : null,
                              );
                            },
                          ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: s.addComment,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
