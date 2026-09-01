import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/notification.dart';

class NotificationsProvider extends ChangeNotifier {
  List<AppNotification> items = [];
  bool loading = false;
  Object? error;

  int get unreadCount => items.where((n) => !n.read).length;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/notifications');
      items = (res.data['results'] as List)
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final i = items.indexWhere((n) => n.id == id);
    if (i >= 0 && !items[i].read) {
      final n = items[i];
      items[i] = AppNotification(id:n.id,type:n.type,title:n.title,body:n.body,
        createdAt:n.createdAt,read:true,actorId:n.actorId,actorName:n.actorName);
      notifyListeners();
    }
    try { await ApiClient.instance.dio.post('/notifications/$id/read'); } catch (_) {}
  }

  Future<void> markAllRead() async {
    items = items.map((n) => AppNotification(id:n.id,type:n.type,title:n.title,body:n.body,
      createdAt:n.createdAt,read:true,actorId:n.actorId,actorName:n.actorName)).toList();
    notifyListeners();
    try { await ApiClient.instance.dio.post('/notifications/read-all'); } catch (_) {}
  }

  void clear() { items = []; notifyListeners(); }
}
