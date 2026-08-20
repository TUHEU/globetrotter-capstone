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
  int? minPrice;
  int? maxPrice;

  bool get hasError => _lastException != null;
  String? errorMessage(AppStrings s) =>
      _lastException == null ? null : ApiClient.errorMessage(_lastException!, s);

  Future<void> search({String? q, String? tag, String? category, int? minPrice, int? maxPrice, bool resetPriceFilter = false}) async {
    loading = true;
    _lastException = null;
    query = q ?? query;
    activeTag = tag;
    activeCategory = category;
    // resetPriceFilter distingue "aucun filtre passé, garder l'actuel"
    // (appels existants qui ne connaissent pas ce paramètre, ex: taper
    // dans la barre de recherche) de "l'utilisateur a explicitement
    // effacé le filtre de prix" - sans cette distinction, un simple appel
    // à search(q: '...') aurait sinon réinitialisé silencieusement un
    // filtre de prix déjà actif à chaque frappe.
    if (resetPriceFilter) {
      this.minPrice = null;
      this.maxPrice = null;
    } else {
      this.minPrice = minPrice ?? this.minPrice;
      this.maxPrice = maxPrice ?? this.maxPrice;
    }
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/destinations', queryParameters: {
        if (query.isNotEmpty) 'q': query,
        'tag': ?tag,
        'category': ?category,
        'min_price': ?this.minPrice,
        'max_price': ?this.maxPrice,
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
