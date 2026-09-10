import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  double? maxDistanceKm;
  double? _userLat;
  double? _userLng;

  /// Mode hors-ligne : dernière liste complète (non filtrée) réussie,
  /// mise en cache localement. Quand une recherche échoue (pas de
  /// réseau), on retombe sur cette liste et on réapplique les filtres
  /// nous-mêmes côté client, plutôt que de simplement afficher une page
  /// d'erreur - voir _searchOffline ci-dessous.
  static const _cacheKey = 'offline_destinations_cache_v1';
  static const _cacheDateKey = 'offline_destinations_cache_date_v1';
  bool isOffline = false;
  DateTime? offlineCacheDate;

  /// "Ouvert maintenant" - filtre appliqué côté client sur [destinations]
  /// via [visibleDestinations] (voir search_filters_sheet.dart pour
  /// pourquoi ce n'est pas un paramètre backend).
  bool clientOpenNowFilter = false;

  /// Liste réellement affichée par les écrans : [destinations] après le
  /// filtre client "ouvert maintenant" éventuel.
  List<Destination> get visibleDestinations => clientOpenNowFilter
      ? destinations.where((d) => d.isLikelyOpenNow(DateTime.now())).toList()
      : destinations;

  bool get hasError => _lastException != null;
  String? errorMessage(AppStrings s) =>
      _lastException == null ? null : ApiClient.errorMessage(_lastException!, s);

  /// Position utilisée pour le filtre/tri "distance" - fournie par
  /// l'écran (via location_service.dart) plutôt que récupérée ici, pour
  /// ne pas déclencher une demande de permission GPS depuis un provider.
  void setUserLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
  }

  Future<void> search({
    String? q,
    String? tag,
    String? category,
    int? minPrice,
    int? maxPrice,
    bool resetPriceFilter = false,
    double? maxDistanceKm,
    bool resetDistanceFilter = false,
  }) async {
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
    if (resetDistanceFilter) {
      this.maxDistanceKm = null;
    } else {
      this.maxDistanceKm = maxDistanceKm ?? this.maxDistanceKm;
    }
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/destinations', queryParameters: {
        if (query.isNotEmpty) 'q': query,
        'tag': ?tag,
        'category': ?category,
        'min_price': ?this.minPrice,
        'max_price': ?this.maxPrice,
        if (this.maxDistanceKm != null && _userLat != null && _userLng != null) ...{
          'user_lat': _userLat,
          'user_lng': _userLng,
          'max_distance_km': this.maxDistanceKm,
        },
      });
      destinations = (res.data['results'] as List).map((j) => Destination.fromJson(j)).toList();
      isOffline = false;
      // On ne met en cache que le catalogue complet non filtré : c'est la
      // seule liste assez générale pour resservir de base à n'importe
      // quel filtre appliqué plus tard hors-ligne (voir _searchOffline).
      if (query.isEmpty && tag == null && category == null && this.minPrice == null && this.maxPrice == null) {
        unawaited(_writeCache(destinations));
      }
    } catch (e) {
      final fellBackOffline = await _searchOffline();
      if (!fellBackOffline) {
        _lastException = e;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Retombe sur le dernier catalogue mis en cache et réapplique les
  /// filtres actuels nous-mêmes (mêmes règles que le backend :
  /// nom/quartier/description/tags, catégorie, prix). Renvoie false si
  /// aucun cache n'existe (dans ce cas l'appelant garde l'erreur réseau
  /// d'origine plutôt que d'afficher une liste vide sans explication).
  Future<bool> _searchOffline() async {
    final cached = await _readCache();
    if (cached == null) return false;

    var results = cached;
    if (query.isNotEmpty) {
      final ql = query.toLowerCase();
      results = results
          .where((d) =>
              d.name.toLowerCase().contains(ql) ||
              d.quartier.toLowerCase().contains(ql) ||
              d.description.toLowerCase().contains(ql) ||
              d.tags.any((t) => t.toLowerCase().contains(ql)))
          .toList();
    }
    if (activeTag != null) {
      results = results.where((d) => d.tags.contains(activeTag!.toLowerCase())).toList();
    }
    if (activeCategory != null) {
      results = results.where((d) => d.category == activeCategory).toList();
    }
    if (minPrice != null) {
      results = results.where((d) => d.avgPriceFcfa >= minPrice!).toList();
    }
    if (maxPrice != null) {
      results = results.where((d) => d.avgPriceFcfa <= maxPrice!).toList();
    }
    destinations = results;
    isOffline = true;
    return true;
  }

  Future<void> _writeCache(List<Destination> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(list.map((d) => {
            'id': d.id, 'name': d.name, 'quartier': d.quartier, 'category': d.category,
            'description': d.description, 'tags': d.tags, 'image': d.image, 'images': d.images,
            'avg_price_fcfa': d.avgPriceFcfa, 'best_time': d.bestTime, 'popularity': d.popularity,
            'lat': d.lat, 'lng': d.lng, 'founded_year': d.foundedYear, 'history': d.history,
            'maps_url': d.mapsUrl,
          }).toList());
      await prefs.setString(_cacheKey, raw);
      await prefs.setString(_cacheDateKey, DateTime.now().toIso8601String());
    } catch (_) {
      // Le cache est une commodité, pas une garantie - une écriture ratée
      // (quota storage plein, etc.) ne doit jamais faire planter la recherche.
    }
  }

  Future<List<Destination>?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final dateRaw = prefs.getString(_cacheDateKey);
      offlineCacheDate = dateRaw != null ? DateTime.tryParse(dateRaw) : null;
      final list = jsonDecode(raw) as List;
      return list.map((j) => Destination.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
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
