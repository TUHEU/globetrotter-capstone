import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/app_strings.dart';
import '../models/destination.dart';

class DestinationProvider extends ChangeNotifier {
  List<Destination> destinations = [];
  List<Destination> recommendations = [];
  bool loading = false;
  bool loadingRecos = false;
  Object? _lastException;
  String query = '';
  String? activeTag;
  String? activeCategory;

  bool get hasError => _lastException != null;
  String? errorMessage(AppStrings s) =>
      _lastException == null ? null : ApiClient.errorMessage(_lastException!, s);

  Future<void> search({String? q, String? tag, String? category}) async {
    loading = true;
    _lastException = null;
    query = q ?? query;
    activeTag = tag;
    activeCategory = category;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/destinations', queryParameters: {
        if (query.isNotEmpty) 'q': query,
        'tag': ?tag,
        'category': ?category,
      });
      destinations = (res.data['results'] as List).map((j) => Destination.fromJson(j)).toList();
    } catch (e) {
      _lastException = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecommendations() async {
    loadingRecos = true;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/recommendations', queryParameters: {'limit': 10});
      recommendations = (res.data['results'] as List).map((j) => Destination.fromJson(j)).toList();
    } catch (e) {
      _lastException = e;
    } finally {
      loadingRecos = false;
      notifyListeners();
    }
  }

  Destination? byId(String id) {
    try {
      return destinations.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Va chercher une destination précise par son id directement à l'API,
  /// utile quand on affiche un itinéraire sans être passé par l'écran de
  /// recherche (donc sans que `destinations` soit déjà rempli).
  Future<Destination?> fetchById(String id) async {
    final cached = byId(id);
    if (cached != null) return cached;
    try {
      final res = await ApiClient.instance.dio.get('/destinations/$id');
      return Destination.fromJson(res.data);
    } catch (_) {
      return null;
    }
  }
}
