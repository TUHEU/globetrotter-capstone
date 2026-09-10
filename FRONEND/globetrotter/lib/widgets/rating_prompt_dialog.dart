import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';

/// Invite ponctuelle à noter l'app (1-5 étoiles + commentaire optionnel),
/// envoyée à POST /feedback (user-service). Se déclenche au maximum une
/// fois - voir [maybeShow] pour les règles ("assez utilisé l'app" plutôt
/// qu'au premier lancement).
class RatingPromptDialog {
  RatingPromptDialog._();

  static const _shownKey = 'rating_prompt_shown_v1';
  static const _actionCountKey = 'rating_prompt_action_count_v1';

  /// À appeler après une action significative (ex: création d'un
  /// itinéraire) - incrémente un compteur local et propose l'évaluation
  /// une seule fois, une fois un seuil de 3 atteint. Ne fait jamais deux
  /// fois la demande, même si l'utilisateur ferme la boîte de dialogue
  /// sans répondre.
  static Future<void> maybeShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) == true) return;

    final count = (prefs.getInt(_actionCountKey) ?? 0) + 1;
    await prefs.setInt(_actionCountKey, count);
    if (count < 3) return;

    await prefs.setBool(_shownKey, true);
    if (!context.mounted) return;
    await _show(context);
  }

  static Future<void> _show(BuildContext context) async {
    int rating = 0;
    final commentCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Votre avis compte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Comment trouvez-vous GlobeTrotter Yaoundé ?'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < rating;
                  return IconButton(
                    icon: Icon(filled ? Icons.star : Icons.star_border, color: Colors.amber),
                    iconSize: 32,
                    onPressed: () => setState(() => rating = i + 1),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Un commentaire (facultatif)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Plus tard'),
            ),
            FilledButton(
              onPressed: rating == 0
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      try {
                        await ApiClient.instance.dio.post('/feedback', data: {
                          'rating': rating,
                          'comment': commentCtrl.text.trim(),
                        });
                      } catch (_) {
                        // Best-effort : un échec d'envoi du feedback ne doit
                        // jamais perturber le reste de l'app.
                      }
                    },
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
    commentCtrl.dispose();
  }
}
