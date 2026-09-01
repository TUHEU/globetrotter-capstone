class AppNotification {
  final String id, type, title, body, createdAt;
  final String? actorId, actorName;
  final bool read;

  const AppNotification({
    required this.id, required this.type, required this.title, required this.body,
    required this.createdAt, required this.read, this.actorId, this.actorName,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id']?.toString() ?? '',
    type: j['type']?.toString() ?? 'system',
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString() ?? '',
    createdAt: j['created_at']?.toString() ?? '',
    read: j['read'] == true,
    actorId: j['actor_id']?.toString(),
    actorName: j['actor_name']?.toString(),
  );
}
