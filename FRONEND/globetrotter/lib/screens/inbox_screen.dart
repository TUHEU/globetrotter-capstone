import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/messages_provider.dart';
import '../providers/settings_provider.dart';
import 'conversation_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<MessagesProvider>().loadInbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final p = context.watch<MessagesProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(s.messages)),
      body: RefreshIndicator(
        onRefresh: () => p.loadInbox(),
        child: p.loadingInbox && p.inbox.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : p.inbox.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      const Icon(Icons.mail_outline, size: 56, color: Colors.grey),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(s.inboxEmpty,
                            textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: p.inbox.length,
                    itemBuilder: (_, i) {
                      final entry = p.inbox[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(entry.partnerName.isNotEmpty
                              ? entry.partnerName[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(entry.partnerName,
                            style: TextStyle(
                                fontWeight:
                                    entry.unreadCount > 0 ? FontWeight.w700 : FontWeight.normal)),
                        subtitle: Text(
                          entry.lastMessage.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight:
                                  entry.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal),
                        ),
                        trailing: entry.unreadCount > 0
                            ? CircleAvatar(
                                radius: 11,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Text(
                                  '${entry.unreadCount}',
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                              )
                            : null,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                                partnerId: entry.partnerId, partnerName: entry.partnerName))),
                      );
                    },
                  ),
      ),
    );
  }
}
