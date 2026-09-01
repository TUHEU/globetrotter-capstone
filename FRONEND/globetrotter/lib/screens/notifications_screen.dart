import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/settings_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<NotificationsProvider>().load());
  }

  IconData _icon(String type) {
    switch (type) {
      case 'follow': return Icons.person_add_alt_1_rounded;
      case 'message': return Icons.chat_bubble_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationsProvider>();
    final s = context.watch<SettingsProvider>().s;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.isFr ? 'Notifications' : 'Notifications'),
        actions: [
          if (p.unreadCount > 0)
            TextButton(
              onPressed: p.markAllRead,
              child: Text(s.isFr ? 'Tout lire' : 'Mark all read'),
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: p.load,
        child: p.loading && p.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : p.items.isEmpty
            ? ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.notifications_none_rounded, size: 64),
                SizedBox(height: 12),
                Center(child: Text('No notifications yet')),
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: p.items.length,
                separatorBuilder: (_,__) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = p.items[i];
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      onTap: () => p.markRead(n.id),
                      leading: CircleAvatar(
                        child: Icon(_icon(n.type)),
                      ),
                      title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                      subtitle: Text(n.body),
                      trailing: n.read ? null : Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
