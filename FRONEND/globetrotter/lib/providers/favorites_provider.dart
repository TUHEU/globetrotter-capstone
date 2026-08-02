import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class FavoritesProvider extends ChangeNotifier {
  Set<String> _ids = {};
  bool loaded = false;

  bool isFavorite(String destinationId) => _ids.contains(destinationId);
  int get count => _ids.length;
  List<String> get ids => _ids.toList();

  Future<void> load() async {
    try {
      final res = await ApiClient.instance.dio.get('/favorites');
      _ids = Set<String>.from(res.data['destination_ids'] ?? []);
    } catch (_) {
      // Pas connecté ou erreur réseau : liste vide, pas bloquant.
      _ids = {};
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> toggle(String destinationId) async {
    final wasFavorite = _ids.contains(destinationId);
    // Mise à jour optimiste : l'UI réagit immédiatement, pas d'attente réseau.
    if (wasFavorite) {
      _ids.remove(destinationId);
    } else {
      _ids.add(destinationId);
    }
    notifyListeners();

    try {
      if (wasFavorite) {
        await ApiClient.instance.dio.delete('/favorites/$destinationId');
      } else {
        await ApiClient.instance.dio.post('/favorites/$destinationId');
      }
    } catch (_) {
      // Échec réseau : on annule le changement optimiste.
      if (wasFavorite) {
        _ids.add(destinationId);
      } else {
        _ids.remove(destinationId);
      }
      notifyListeners();
    }
  }

  void clear() {
    _ids = {};
    loaded = false;
    notifyListeners();
  }
}
