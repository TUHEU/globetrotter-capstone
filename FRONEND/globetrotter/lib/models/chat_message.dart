enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {
        'role': role == ChatRole.user ? 'user' : 'assistant',
        'content': content,
      };
}
