import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/itinerary.dart';

class ItineraryProvider extends ChangeNotifier {
  List<Itinerary> itineraries = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/itineraries');
      itineraries = (res.data['results'] as List).map((j) => Itinerary.fromJson(j)).toList();
    } catch (e) {
      error = ApiClient.errorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> create({
    required String title,
    String? description,
    String? startDate,
    String? endDate,
    required List<ItineraryStop> stops,
    List<String> sharedWith = const [],
  }) async {
    try {
      await ApiClient.instance.dio.post('/itineraries', data: {
        'title': title,
        'description': description,
        'start_date': startDate,
        'end_date': endDate,
        'stops': stops.map((s) => s.toJson()).toList(),
        'shared_with': sharedWith,
      });
      await load();
      return null;
    } catch (e) {
      return ApiClient.errorMessage(e);
    }
  }

  Future<String?> delete(String id) async {
    try {
      await ApiClient.instance.dio.delete('/itineraries/$id');
      itineraries.removeWhere((i) => i.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.errorMessage(e);
    }
  }
}
