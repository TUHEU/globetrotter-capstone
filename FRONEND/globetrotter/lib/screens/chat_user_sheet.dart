import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/avatars.dart';
import '../models/friend.dart';
import '../providers/friends_provider.dart';
import '../providers/settings_provider.dart';
import 'conversation_screen.dart';

/// Tapping someone's avatar/name in the Global chat opens this: a quick
/// profile card to follow them (needed before you can DM them, per the
/// existing backend rule) and jump straight into a conversation.
Future<void> showChatUserSheet(
  BuildContext context, {
  required String userId,
  required String userName,
  String? avatar,
  required Color avatarColor,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ChatUserSheet(
        userId: userId, userName: userName, avatar: avatar, avatarColor: avatarColor),
  );
}

class _ChatUserSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final String? avatar;
  final Color avatarColor;
  const _ChatUserSheet(
      {required this.userId, required this.userName, this.avatar, required this.avatarColor});

  @override
  State<_ChatUserSheet> createState() => _ChatUserSheetState();
}

class _ChatUserSheetState extends State<_ChatUserSheet> {
  bool? _isFollowing; // null while loading
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final res =
          await ApiClient.instance.dio.get('/follow/status/${widget.userId}');
      if (mounted) setState(() => _isFollowing = res.data['is_following'] as bool? ?? false);
    } catch (_) {
      if (mounted) setState(() => _isFollowing = false);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _busy = true);
    final friends = context.read<FriendsProvider>();
    final friend = Friend(id: widget.userId, fullName: widget.userName, email: '', avatar: widget.avatar);
    if (_isFollowing == true) {
      await friends.unfollow(widget.userId);
    } else {
      await friends.follow(friend);
    }
    if (mounted) setState(() { _isFollowing = !(_isFollowing ?? false); _busy = false; });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
                name: widget.userName, avatar: widget.avatar, color: widget.avatarColor, radius: 32),
            const SizedBox(height: 10),
            Text(widget.userName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isFollowing == null || _busy ? null : _toggleFollow,
                    icon: Icon(_isFollowing == true ? Icons.person_remove_outlined : Icons.person_add_alt_1_outlined),
                    label: Text(
                      _isFollowing == null
                          ? '…'
                          : (_isFollowing! ? (s.isFr ? 'Ne plus suivre' : 'Unfollow') : (s.isFr ? 'Suivre' : 'Follow')),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ConversationScreen(
                            partnerId: widget.userId, partnerName: widget.userName),
                      ));
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(s.isFr ? 'Message' : 'Message'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
