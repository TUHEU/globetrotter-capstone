import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/settings_provider.dart';
import 'call_screen.dart';

class ConversationScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;

  const ConversationScreen({super.key, required this.partnerId, required this.partnerName});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _startingCall = false;

  Future<void> _startCall({required bool video}) async {
    setState(() => _startingCall = true);
    try {
      final res = await ApiClient.instance.dio
          .post('/calls/dm-token', data: {'other_user_id': widget.partnerId});
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          url: res.data['url'],
          token: res.data['token'],
          roomName: res.data['room'],
          title: widget.partnerName,
          startWithVideo: video,
        ),
      ));
    } on DioException catch (e) {
      if (mounted) {
        final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(detail?.toString() ?? 'Impossible de démarrer l\'appel.')));
      }
    } finally {
      if (mounted) setState(() => _startingCall = false);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await context.read<MessagesProvider>().loadConversation(widget.partnerId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    final err = await context.read<MessagesProvider>().send(widget.partnerId, text);
    if (mounted) {
      setState(() => _sending = false);
      _scrollToBottom();
      if (err != null) {
        final s = context.read<SettingsProvider>().s;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.messageFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final p = context.watch<MessagesProvider>();
    final myId = context.watch<AuthProvider>().user?.id;
    final messages = p.conversationWith(widget.partnerId);
    final loading = p.isLoadingConversation(widget.partnerId) && messages.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.partnerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Appel audio',
            onPressed: _startingCall ? null : () => _startCall(video: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Appel vidéo',
            onPressed: _startingCall ? null : () => _startCall(video: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      // 'me' = id temporaire pour un message optimiste pas
                      // encore confirmé par le serveur - voir
                      // MessagesProvider.send().
                      final mine = m.fromId == 'me' || m.fromId == myId;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: mine
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(mine ? 16 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 16),
                            ),
                          ),
                          child: Text(
                            m.text,
                            style: TextStyle(
                              color: mine
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: s.typeMessage,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
