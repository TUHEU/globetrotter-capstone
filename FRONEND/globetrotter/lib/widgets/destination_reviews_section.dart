import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/destination_review.dart';
import '../providers/settings_provider.dart';

/// Avis publics sur UNE destination — indépendant des avis sur
/// l'application (voir ReviewsScreen). Porté depuis le pattern
/// "GET/POST /destinations/<id>/reviews" du monolithe Phase 1.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

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
      await ApiClient.instance.dio.post(
        '/destinations/${widget.destinationId}/reviews',
        data: {'rating': _myRating, 'comment': _commentController.text.trim()},
      );
      _commentController.clear();
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
                  ],
                ),
              )),
      ],
    );
  }
}
