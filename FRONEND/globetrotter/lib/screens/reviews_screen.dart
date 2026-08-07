import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/review_provider.dart';
import '../providers/settings_provider.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<ReviewProvider>().load();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.read<SettingsProvider>().s;
    if (_rating == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choisissez une note avant d\'envoyer.')));
      return;
    }
    setState(() => _submitting = true);
    final err = await context.read<ReviewProvider>().submit(_rating, _commentController.text.trim());
    setState(() => _submitting = false);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(err, s))));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Merci pour votre avis !')));
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewProvider = context.watch<ReviewProvider>();
    final myUserId = context.watch<AuthProvider>().user?.id;
    final myReview = reviewProvider.reviews.where((r) => r.userId == myUserId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Avis sur l\'application')),
      body: RefreshIndicator(
        onRefresh: () => reviewProvider.load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Note moyenne', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(reviewProvider.averageRating.toStringAsFixed(1),
                            style: theme.textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StarRow(rating: reviewProvider.averageRating.round(), size: 18),
                            Text('${reviewProvider.count} avis',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(myReview.isEmpty ? 'Laissez votre avis' : 'Modifier votre avis',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return IconButton(
                    iconSize: 34,
                    icon: Icon(
                      starIndex <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: theme.colorScheme.tertiary,
                    ),
                    onPressed: () => setState(() => _rating = starIndex),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Qu\'est-ce que vous aimez ou souhaiteriez voir amélioré ?',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Envoyer'),
              ),
            ),
            const SizedBox(height: 28),
            Text('Avis des autres utilisateurs', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (reviewProvider.loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (reviewProvider.reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Aucun avis pour le moment — soyez le premier !'),
              )
            else
              ...reviewProvider.reviews.map((r) => Card(
                    child: ListTile(
                      title: Text(r.fullName.isEmpty ? 'Utilisateur' : r.fullName),
                      subtitle: Text(r.comment.isEmpty ? '(sans commentaire)' : r.comment),
                      trailing: _StarRow(rating: r.rating, size: 14),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  final double size;
  const _StarRow({required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          5,
          (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: size, color: color)),
    );
  }
}
