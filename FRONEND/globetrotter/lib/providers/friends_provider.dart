import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/friend.dart';

class FriendsProvider extends ChangeNotifier {
  List<Friend> searchResults = [];
  List<Friend> following = [];
  List<Friend> followers = [];
  List<Friend> discover = [];
  bool searching = false;
  bool loadingLists = false;
  bool loadingDiscover = false;
  String? followListsError;

  Set<String> get followingIds => following.map((f) => f.id).toSet();
  bool isFollowing(String userId) => followingIds.contains(userId);

  /// Écran "Découvrir" : tout le monde ayant l'app, pas seulement les
  /// résultats d'une recherche tapée - pour parcourir plutôt que chercher.
  Future<void> loadDiscover() async {
    loadingDiscover = true;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/users/discover');
      discover = (res.data['results'] as List).map((j) => Friend.fromJson(j)).toList();
    } catch (_) {
      // Garde la liste précédente plutôt que de la vider brutalement.
    } finally {
      loadingDiscover = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      searchResults = [];
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/users/search', queryParameters: {'q': query});
      searchResults = (res.data['results'] as List).map((j) => Friend.fromJson(j)).toList();
    } catch (_) {
      searchResults = [];
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<void> loadFollowLists() async {
    loadingLists = true;
    followListsError = null;
    notifyListeners();

    // Do not use one Future.wait for both calls: if only /followers fails,
    // the old code discarded the successful /following response too and the
    // UI looked completely empty. Each list is refreshed independently.
    String? firstError;
    try {
      final res = await ApiClient.instance.dio.get('/follow/following');
      final raw = (res.data['results'] as List?) ?? const [];
      following = raw.map((j) => Friend.fromJson(j)).toList();
    } catch (e) {
      firstError = 'following: $e';
    }

    try {
      final res = await ApiClient.instance.dio.get('/follow/followers');
      final raw = (res.data['results'] as List?) ?? const [];
      followers = raw.map((j) => Friend.fromJson(j)).toList();
    } catch (e) {
      firstError ??= 'followers: $e';
    }

    followListsError = firstError;
    loadingLists = false;
    notifyListeners();
  }

  Future<void> follow(Friend user) async {
    // Mise à jour optimiste, comme FavoritesProvider.toggle().
    following = [...following, user];
    // Disparaît aussi de "Découvrir" - suivre quelqu'un depuis cet écran ne
    // doit pas le laisser affiché comme "à découvrir" juste après.
    discover = discover.where((f) => f.id != user.id).toList();
    notifyListeners();
    try {
      await ApiClient.instance.dio.post('/follow/${user.id}');
    } catch (_) {
      following = following.where((f) => f.id != user.id).toList();
      discover = [...discover, user];
      notifyListeners();
    }
  }

  Future<void> unfollow(String userId) async {
    final removed = following.where((f) => f.id == userId).toList();
    following = following.where((f) => f.id != userId).toList();
    notifyListeners();
    try {
      await ApiClient.instance.dio.delete('/follow/$userId');
    } catch (_) {
      following = [...following, ...removed];
      notifyListeners();
    }
  }

  void clear() {
    searchResults = [];
    following = [];
    followers = [];
    discover = [];
    followListsError = null;
    notifyListeners();
  }
}
