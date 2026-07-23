import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/destination.dart';

class DestinationProvider extends ChangeNotifier {
  List<Destination> destinations = [];
  List<Destination> recommendations = [];
  bool loading = false;
  bool loadingRecos = false;
  String? error;
  String query = '';
  String? activeTag;
  String? activeCategory;

  Future<void> search({String? q, String? tag, String? category}) async {
    loading = true;
    error = null;
    query = q ?? query;
    activeTag = tag;
    activeCategory = category;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/destinations', queryParameters: {
        if (query.isNotEmpty) 'q': query,
        if (tag != null) 'tag': tag,
        if (category != null) 'category': category,
      });
      destinations = (res.data['results'] as List).map((j) => Destination.fromJson(j)).toList();
    } catch (e) {
      error = ApiClient.errorMessage(e);
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
      error = ApiClient.errorMessage(e);
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
}
