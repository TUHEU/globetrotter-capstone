class Message {
  final String id;
  final String fromId;
  final String toId;
  final String text;
  final String createdAt;
  final bool read;

  Message({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.text,
    required this.createdAt,
    required this.read,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'],
        fromId: j['from_id'],
        toId: j['to_id'],
        text: j['text'],
        createdAt: j['created_at'],
        read: j['read'] ?? false,
      );
}

/// Une ligne de la liste des discussions (écran "Boîte de réception").
class InboxEntry {
  final String partnerId;
  final String partnerName;
  final Message lastMessage;
  final int unreadCount;

  InboxEntry({
    required this.partnerId,
    required this.partnerName,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory InboxEntry.fromJson(Map<String, dynamic> j) => InboxEntry(
        partnerId: j['partner_id'],
        partnerName: j['partner_name'],
        lastMessage: Message.fromJson(j['last_message']),
        unreadCount: j['unread_count'] ?? 0,
      );
}
