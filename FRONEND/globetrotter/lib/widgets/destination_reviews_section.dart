import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/avatars.dart';
import '../models/destination_review.dart';
import '../models/friend.dart';
import '../providers/settings_provider.dart';

/// Avis publics sur UNE destination — indépendant des avis sur
/// l'application (voir ReviewsScreen). Porté depuis le pattern
/// "GET/POST /destinations/`<id>`/reviews" du monolithe Phase 1.
class DestinationReviewsSection extends StatefulWidget {
  final String destinationId;
  const DestinationReviewsSection({super.key, required this.destinationId});

  @override
  State<DestinationReviewsSection> createState() => _DestinationReviewsSectionState();
}

class _DestinationReviewsSectionState extends State<DestinationReviewsSection> {
  List<DestinationReview> _reviews = [];
  double _averageRating = 0;
  int _count = 0;
  bool _loading = true;
  int _myRating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  // État du fil de réponses : quel avis est en train de recevoir une
  // réponse (null = aucun), et le texte en cours de saisie pour celui-là.
  String? _replyingToId;
  final _replyController = TextEditingController();
  bool _submittingReply = false;

  // @-mention (partagé entre le champ "avis" et le champ "réponse") :
  // userId -> nom affiché, plus les résultats de recherche en cours et
  // pour quel champ ils s'appliquent.
  final Map<String, String> _commentMentions = {};
  final Map<String, String> _replyMentions = {};
  List<Friend> _mentionSuggestions = [];
  TextEditingController? _activeMentionController;
  Timer? _mentionDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _commentController.addListener(() => _checkMentionTrigger(_commentController));
    _replyController.addListener(() => _checkMentionTrigger(_replyController));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _mentionDebounce?.cancel();
    super.dispose();
  }

  /// Same trigger rule as the Global chat's mention picker: an unfinished
  /// "@query" right after a space (or at the very start) shows suggestions.
  void _checkMentionTrigger(TextEditingController ctrl) {
    final text = ctrl.text;
    final cursor = ctrl.selection.baseOffset;
    if (cursor < 0) {
      if (_activeMentionController == ctrl) setState(() => _mentionSuggestions = []);
      return;
    }
    final upToCursor = text.substring(0, cursor);
    final at = upToCursor.lastIndexOf('@');
    if (at == -1 || !(at == 0 || RegExp(r'\s').hasMatch(upToCursor[at - 1]))) {
      if (_activeMentionController == ctrl && _mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }
    final query = upToCursor.substring(at + 1);
    if (query.contains(' ') || query.contains('\n')) {
      if (_activeMentionController == ctrl && _mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }
    _activeMentionController = ctrl;
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final res = await ApiClient.instance.dio.get('/users/search', queryParameters: {'q': query});
        if (!mounted || _activeMentionController != ctrl) return;
        final results = (res.data['results'] as List? ?? [])
            .map((j) => Friend.fromJson(j as Map<String, dynamic>))
            .take(5)
            .toList();
        setState(() => _mentionSuggestions = results);
      } catch (_) {
        // Silent - mention autocomplete is a nice-to-have.
      }
    });
  }

  void _pickMention(Friend f) {
    final ctrl = _activeMentionController;
    if (ctrl == null) return;
    final text = ctrl.text;
    final cursor = ctrl.selection.baseOffset;
    final upToCursor = text.substring(0, cursor < 0 ? text.length : cursor);
    final at = upToCursor.lastIndexOf('@');
    if (at == -1) return;
    final before = text.substring(0, at);
    final after = text.substring(cursor < 0 ? text.length : cursor);
    final insertion = '@${f.fullName} ';
    ctrl.value = TextEditingValue(
      text: before + insertion + after,
      selection: TextSelection.collapsed(offset: (before + insertion).length),
    );
    (ctrl == _commentController ? _commentMentions : _replyMentions)[f.id] = f.fullName;
    setState(() => _mentionSuggestions = []);
  }

  /// Mentions whose "@Name" text is still actually present in the given
  /// text (in case the user backspaced over a tag after inserting it).
  List<String> _resolveMentions(Map<String, String> tagged, String text) =>
      tagged.entries.where((e) => text.contains('@${e.value}')).map((e) => e.key).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio
          .get('/destinations/${widget.destinationId}/reviews');
      final results = (res.data['results'] as List)
          .map((j) => DestinationReview.fromJson(j))
          .toList();
      final summary = res.data['summary'];
      if (!mounted) return;
      setState(() {
        _reviews = results;
        _averageRating = (summary['average_rating'] as num).toDouble();
        _count = (summary['count'] as num).toInt();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_myRating == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choisissez une note avant d\'envoyer.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final comment = _commentController.text.trim();
      await ApiClient.instance.dio.post(
        '/destinations/${widget.destinationId}/reviews',
        data: {
          'rating': _myRating,
          'comment': comment,
          'mentions': _resolveMentions(_commentMentions, comment),
        },
      );
      _commentController.clear();
      _commentMentions.clear();
      setState(() => _myRating = 0);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Merci pour votre avis !')));
      }
    } catch (e) {
      if (mounted) {
        final s = context.read<SettingsProvider>().s;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e, s))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitReply(String reviewId) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submittingReply = true);
    try {
      await ApiClient.instance.dio.post(
        '/destinations/${widget.destinationId}/reviews/$reviewId/replies',
        data: {'text': text, 'mentions': _resolveMentions(_replyMentions, text)},
      );
      _replyController.clear();
      _replyMentions.clear();
      setState(() => _replyingToId = null);
      await _load();
    } catch (e) {
      if (mounted) {
        final s = context.read<SettingsProvider>().s;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e, s))));
      }
    } finally {
      if (mounted) setState(() => _submittingReply = false);
    }
  }

  Widget _mentionSuggestionsList(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _mentionSuggestions.length,
        itemBuilder: (_, i) {
          final f = _mentionSuggestions[i];
          return ListTile(
            dense: true,
            leading: UserAvatar(name: f.fullName, avatar: f.avatar, color: theme.colorScheme.primary, radius: 14),
            title: Text(f.fullName, style: const TextStyle(fontSize: 13)),
            onTap: () => _pickMention(f),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Avis', style: theme.textTheme.titleMedium),
          const SizedBox(width: 10),
          if (_count > 0) ...[
            Icon(Icons.star_rounded, size: 18, color: theme.colorScheme.tertiary),
            const SizedBox(width: 2),
            Text('${_averageRating.toStringAsFixed(1)} ($_count)',
                style: theme.textTheme.bodyMedium),
          ],
        ]),
        const SizedBox(height: 10),
        // Formulaire d'ajout
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(5, (i) {
            final star = i + 1;
            return IconButton(
              iconSize: 26,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                star <= _myRating ? Icons.star_rounded : Icons.star_border_rounded,
                color: theme.colorScheme.tertiary,
              ),
              onPressed: () => setState(() => _myRating = star),
            );
          }),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _commentController,
          maxLines: 2,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Votre avis sur ce lieu (optionnel)'),
        ),
        if (_activeMentionController == _commentController && _mentionSuggestions.isNotEmpty)
          _mentionSuggestionsList(theme),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Publier'),
          ),
        ),
        const Divider(height: 28),
        if (_reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucun avis pour le moment — soyez le premier !',
                style: TextStyle(color: Colors.grey)),
          )
        else
          ..._reviews.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(r.reviewerName, style: theme.textTheme.titleSmall),
                      const SizedBox(width: 8),
                      ...List.generate(
                          5,
                          (i) => Icon(
                                i < r.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 14,
                                color: theme.colorScheme.tertiary,
                              )),
                    ]),
                    if (r.comment.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(r.comment, style: theme.textTheme.bodyMedium),
                    ],
                    // Réponses déjà postées par d'autres utilisateurs - en
                    // retrait, pour bien montrer que ce sont des réactions
                    // à CET avis précis, pas de nouveaux avis séparés.
                    if (r.replies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: r.replies
                              .map((rep) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: RichText(
                                      text: TextSpan(
                                        style: theme.textTheme.bodySmall,
                                        children: [
                                          TextSpan(
                                            text: '${rep.authorName} : ',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          TextSpan(text: rep.text),
                                        ],
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 2),
                      child: _replyingToId == r.id
                          ? Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: _replyController,
                                        autofocus: true,
                                        maxLength: 300,
                                        style: theme.textTheme.bodySmall,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          hintText: 'Votre réponse…',
                                          counterText: '',
                                        ),
                                        onSubmitted: (_) => _submitReply(r.id),
                                      ),
                                      if (_activeMentionController == _replyController &&
                                          _mentionSuggestions.isNotEmpty)
                                        _mentionSuggestionsList(theme),
                                    ],
                                  ),
                                ),
                                _submittingReply
                                    ? const SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : IconButton(
                                        icon: const Icon(Icons.send_rounded, size: 18),
                                        onPressed: () => _submitReply(r.id),
                                      ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(() => _replyingToId = null),
                                ),
                              ],
                            )
                          : TextButton.icon(
                              onPressed: () => setState(() => _replyingToId = r.id),
                              icon: const Icon(Icons.reply_rounded, size: 15),
                              label: const Text('Répondre', style: TextStyle(fontSize: 12.5)),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}
