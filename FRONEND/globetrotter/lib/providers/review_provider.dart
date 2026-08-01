import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/app_strings.dart';
import '../models/review.dart';

class ReviewProvider extends ChangeNotifier {
  List<Review> reviews = [];
  double averageRating = 0.0;
  int count = 0;
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
      final results = await Future.wait([
        ApiClient.instance.dio.get('/reviews'),
        ApiClient.instance.dio.get('/reviews/summary'),
      ]);
      reviews = (results[0].data['results'] as List).map((j) => Review.fromJson(j)).toList();
      averageRating = (results[1].data['average_rating'] as num).toDouble();
      count = (results[1].data['count'] as num).toInt();
    } catch (e) {
      _lastException = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Object?> submit(int rating, String comment) async {
    try {
      await ApiClient.instance.dio.post('/reviews', data: {
        'rating': rating,
        'comment': comment,
      });
      await load();
      return null;
    } catch (e) {
      return e;
    }
  }
}
