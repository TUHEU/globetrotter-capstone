import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/message.dart';

class MessagesProvider extends ChangeNotifier {
  List<InboxEntry> inbox = [];
  bool loadingInbox = false;
  Object? inboxError;

  final Map<String, List<Message>> _conversations = {};
  final Set<String> _loadingConversations = {};

  int get totalUnread => inbox.fold(0, (sum, e) => sum + e.unreadCount);

  List<Message> conversationWith(String userId) => _conversations[userId] ?? [];
  bool isLoadingConversation(String userId) => _loadingConversations.contains(userId);

  Future<void> loadInbox() async {
    loadingInbox = true;
    inboxError = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/messages/inbox');
      inbox = (res.data['results'] as List).map((j) => InboxEntry.fromJson(j)).toList();
    } catch (e) {
      inboxError = e;
    } finally {
      loadingInbox = false;
      notifyListeners();
    }
  }

  Future<void> loadConversation(String userId) async {
    _loadingConversations.add(userId);
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.get('/messages/$userId');
      _conversations[userId] =
          (res.data['messages'] as List).map((j) => Message.fromJson(j)).toList();
      // Ouvrir la conversation la marque comme lue côté serveur - on reflète
      // ça immédiatement dans la boîte de réception locale sans attendre un
      // rechargement complet.
      final idx = inbox.indexWhere((e) => e.partnerId == userId);
      if (idx != -1 && inbox[idx].unreadCount > 0) {
        final e = inbox[idx];
        inbox[idx] = InboxEntry(
          partnerId: e.partnerId,
          partnerName: e.partnerName,
          lastMessage: e.lastMessage,
          unreadCount: 0,
        );
      }
    } catch (_) {
      // Garde la conversation précédemment chargée plutôt que de la vider.
    } finally {
      _loadingConversations.remove(userId);
      notifyListeners();
    }
  }

  Future<Object?> send(String toUserId, String text) async {
    // Mise à jour optimiste : affiche le message immédiatement, avec un id
    // temporaire remplacé une fois la vraie réponse serveur arrivée.
    final optimistic = Message(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      fromId: 'me',
      toId: toUserId,
      text: text,
      createdAt: DateTime.now().toIso8601String(),
      read: false,
    );
    _conversations.putIfAbsent(toUserId, () => []).add(optimistic);
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.post('/messages/$toUserId', data: {'text': text});
      final real = Message.fromJson(res.data);
      final list = _conversations[toUserId]!;
      final i = list.indexWhere((m) => m.id == optimistic.id);
      if (i != -1) list[i] = real;
      notifyListeners();
      return null;
    } catch (e) {
      _conversations[toUserId]?.removeWhere((m) => m.id == optimistic.id);
      notifyListeners();
      return e;
    }
  }

  void clear() {
    inbox = [];
    _conversations.clear();
    notifyListeners();
  }
}
