import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/friend.dart';

class FriendsProvider extends ChangeNotifier {
  List<Friend> searchResults = [];
  List<Friend> following = [];
  List<Friend> followers = [];
  bool searching = false;
  bool loadingLists = false;

  Set<String> get followingIds => following.map((f) => f.id).toSet();
  bool isFollowing(String userId) => followingIds.contains(userId);

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
    notifyListeners();
    try {
      final res = await Future.wait([
        ApiClient.instance.dio.get('/follow/following'),
        ApiClient.instance.dio.get('/follow/followers'),
      ]);
      following = (res[0].data['results'] as List).map((j) => Friend.fromJson(j)).toList();
      followers = (res[1].data['results'] as List).map((j) => Friend.fromJson(j)).toList();
    } catch (_) {
      // Pas connecté / erreur réseau : on garde les listes précédentes plutôt
      // que de les vider brutalement.
    } finally {
      loadingLists = false;
      notifyListeners();
    }
  }

  Future<void> follow(Friend user) async {
    // Mise à jour optimiste, comme FavoritesProvider.toggle().
    following = [...following, user];
    notifyListeners();
    try {
      await ApiClient.instance.dio.post('/follow/${user.id}');
    } catch (_) {
      following = following.where((f) => f.id != user.id).toList();
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
    notifyListeners();
  }
}
