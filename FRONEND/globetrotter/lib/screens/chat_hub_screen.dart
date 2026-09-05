import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/avatars.dart';
import '../models/friend.dart';
import '../providers/friends_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/settings_provider.dart';
import 'conversation_screen.dart';
import 'global_chat_screen.dart';

/// Single entry point for everything chat-related: one list mixing the
/// public Global chat (pinned at the top, like a "channel") with every
/// private conversation below it — no tabs to switch between. Tapping the
/// Global row opens the live GlobalChatScreen; tapping a conversation opens
/// ConversationScreen. A "new message" FAB lets you search someone and
/// start a DM straight from here.
class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  int? _onlineCount;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<MessagesProvider>().loadInbox();
    });
    _loadOnlineCount();
  }

  Future<void> _loadOnlineCount() async {
    try {
      final res = await ApiClient.instance.dio.get('/chat/online');
      if (mounted) setState(() => _onlineCount = res.data['online'] as int?);
    } catch (_) {
      // Silent: this is just a light preview badge, the Global screen
      // itself reports connection status properly once opened.
    }
  }

  Future<void> _refresh() async {
    await context.read<MessagesProvider>().loadInbox();
    await _loadOnlineCount();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final p = context.watch<MessagesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88), // clear of the FAB
          children: [
            _GlobalChatTile(onlineCount: _onlineCount),
            const Divider(height: 1),
            if (p.loadingInbox && p.inbox.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (p.inbox.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
                child: Column(
                  children: [
                    const Icon(Icons.mail_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(s.inboxEmpty,
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else
              ...p.inbox.map((entry) => ListTile(
                    leading: UserAvatar(
                      name: entry.partnerName,
                      avatar: entry.partnerAvatar,
                      color: Theme.of(context).colorScheme.primary,
                      radius: 20,
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
                  )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewMessageSheet(context),
        icon: const Icon(Icons.edit_outlined),
        label: Text(s.startConversation),
      ),
    );
  }

  void _openNewMessageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _NewMessageSheet(),
    );
  }
}

class _GlobalChatTile extends StatelessWidget {
  final int? onlineCount;
  const _GlobalChatTile({required this.onlineCount});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B7A3D), Color(0xFF0F5229)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.public, color: Colors.white),
      ),
      title: Text(s.isFr ? 'Chat Global 🌍' : 'Global Chat 🌍',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        onlineCount != null
            ? (s.isFr ? '$onlineCount en ligne' : '$onlineCount online')
            : (s.isFr ? 'Discuter avec toute la communauté' : 'Chat with the whole community'),
        style: TextStyle(
          color: onlineCount != null ? Colors.green.shade600 : null,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const GlobalChatScreen())),
    );
  }
}

/// Bottom sheet: search anyone on GlobeTrotter and jump straight into a
/// conversation with them. Sending will still be rejected server-side
/// (403) if you don't follow each other, so that's called out up front
/// rather than after a failed send.
class _NewMessageSheet extends StatefulWidget {
  const _NewMessageSheet();

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<FriendsProvider>().search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final p = context.watch<FriendsProvider>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.startConversation,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(s.canOnlyMessageFriends,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: s.isFr ? 'Rechercher une personne…' : 'Search for someone…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: p.searching
                    ? const Center(child: CircularProgressIndicator())
                    : p.searchResults.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.trim().isEmpty
                                  ? (s.isFr ? 'Commencez à taper pour chercher.' : 'Start typing to search.')
                                  : (s.isFr ? 'Aucun résultat.' : 'No results.'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: p.searchResults.length,
                            itemBuilder: (_, i) {
                              final Friend u = p.searchResults[i];
                              return ListTile(
                                leading: UserAvatar(
                                  name: u.fullName,
                                  avatar: u.avatar,
                                  color: Theme.of(context).colorScheme.primary,
                                  radius: 20,
                                ),
                                title: Text(u.fullName),
                                subtitle: Text(u.email,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ConversationScreen(
                                        partnerId: u.id, partnerName: u.fullName),
                                  ));
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
