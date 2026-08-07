import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/app_strings.dart';
import '../models/itinerary.dart';

class ItineraryProvider extends ChangeNotifier {
  List<Itinerary> itineraries = [];
  bool loading = false;
  Object? _lastException;

  bool get hasError => _lastException != null;
  String? errorMessage(AppStrings s) =>
      _lastException == null ? null : ApiClient.errorMessage(_lastException!, s);

  Future<void> load() async {
    loading = true;
    _lastException = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/itineraries');
      itineraries = (res.data['results'] as List).map((j) => Itinerary.fromJson(j)).toList();
    } catch (e) {
      _lastException = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Retourne l'exception brute en cas d'échec (null si succès).
  /// L'appelant la convertit en message localisé via ApiClient.errorMessage(e, s).
  Future<Object?> create({
    required String title,
    String? description,
    String? startDate,
    String? endDate,
    required List<ItineraryStop> stops,
    List<String> sharedWith = const [],
    bool isPublic = false,
  }) async {
    try {
      await ApiClient.instance.dio.post('/itineraries', data: {
        'title': title,
        'description': description,
        'start_date': startDate,
        'end_date': endDate,
        'stops': stops.map((s) => s.toJson()).toList(),
        'shared_with': sharedWith,
        'is_public': isPublic,
      });
      await load();
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<Object?> setVisibility(String id, bool isPublic) async {
    try {
      await ApiClient.instance.dio.patch('/itineraries/$id/visibility', data: {
        'is_public': isPublic,
      });
      await load();
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<Object?> delete(String id) async {
    try {
      await ApiClient.instance.dio.delete('/itineraries/$id');
      itineraries.removeWhere((i) => i.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return e;
    }
  }
}
