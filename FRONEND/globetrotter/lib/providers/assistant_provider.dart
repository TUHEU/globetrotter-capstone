import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/app_strings.dart';
import '../models/chat_message.dart';

class AssistantProvider extends ChangeNotifier {
  final List<ChatMessage> messages = [];
  bool sending = false;
  Object? _lastException;

  bool get hasError => _lastException != null;
  String? errorMessage(AppStrings s) =>
      _lastException == null ? null : ApiClient.errorMessage(_lastException!, s);

  // On n'envoie que les ~10 derniers messages comme historique : suffisant
  // pour garder le fil de la conversation sans faire grossir chaque appel
  // indéfiniment (le service ne stocke rien de son côté, voir ai-service).
  List<ChatMessage> get _recentHistory =>
      messages.length > 10 ? messages.sublist(messages.length - 10) : messages;

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    final userMessage = ChatMessage(role: ChatRole.user, content: text.trim());
    messages.add(userMessage);
    sending = true;
    _lastException = null;
    notifyListeners();

    try {
      final res = await ApiClient.instance.dio.post('/assistant/chat', data: {
        'message': userMessage.content,
        'history': _recentHistory
            .where((m) => m != userMessage)
            .map((m) => m.toJson())
            .toList(),
      });
      messages.add(ChatMessage(role: ChatRole.assistant, content: res.data['reply']));
    } catch (e) {
      _lastException = e;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void reset() {
    messages.clear();
    _lastException = null;
    notifyListeners();
  }
}
