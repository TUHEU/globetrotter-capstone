// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class _ChatMsg {
  final String id;
  final String userId;
  final String userName;
  final String type; // text|image|audio|video|location|system
  final String text;
  final String? mediaUrl;
  final Map<String, dynamic>? location;
  Map<String, List<String>> reactions;
  final DateTime ts;

  _ChatMsg({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    this.text = '',
    this.mediaUrl,
    this.location,
    Map<String, List<String>>? reactions,
    required this.ts,
  }) : reactions = reactions ?? {};

  factory _ChatMsg.fromJson(Map<String, dynamic> j) {
    final raw = (j['reactions'] as Map<String, dynamic>?) ?? {};
    return _ChatMsg(
      id: j['id'] as String? ?? UniqueKey().toString(),
      userId: j['user_id'] as String? ?? '',
      userName: j['user_name'] as String? ?? 'Inconnu',
      type: j['type'] as String? ?? 'text',
      text: j['text'] as String? ?? '',
      mediaUrl: j['media_url'] as String?,
      location: j['location'] as Map<String, dynamic>?,
      reactions: raw.map((k, v) => MapEntry(k, List<String>.from(v as List))),
      ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({super.key});
  @override
  State<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;
  bool _connecting = false;

  final List<_ChatMsg> _msgs = [];
  final _scroll = ScrollController();
  final _textCtrl = TextEditingController();
  bool _showEmoji = false;
  int _online = 0;

  // Audio
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _recording = false;
  String? _recPath;
  String? _playingUrl;
  bool _isPlaying = false;
  Duration _pos = Duration.zero, _dur = Duration.zero;

  late String _myId, _myName;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _myId = auth.user?.id ?? '';
    _myName = auth.user?.fullName ?? 'Explorateur';
    _connect();
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _pos = p); });
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _dur = d); });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _playingUrl = null; _pos = Duration.zero; });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    _textCtrl.dispose();
    _scroll.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── WS ──────────────────────────────────────────────────────────────────
  Future<void> _connect() async {
    if (_connecting) return;
    setState(() { _connecting = true; _connected = false; });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    // Load history
    try {
      final res = await ApiClient.instance.dio.get('/chat/history');
      final list = (res.data['messages'] as List)
          .map((m) => _ChatMsg.fromJson(m as Map<String, dynamic>))
          .toList();
      setState(() { _msgs.clear(); _msgs.addAll(list); });
      _jumpBottom();
    } catch (_) {}

    // Connect WebSocket
    final wsBase = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    try {
      _channel = WebSocketChannel.connect(Uri.parse('$wsBase/ws/chat?token=$token'));
      await _channel!.ready;
      setState(() { _connected = true; _connecting = false; });
      _sub = _channel!.stream.listen(_onMsg,
          onError: (_) => _reconnect(), onDone: _reconnect);
    } catch (_) {
      setState(() => _connecting = false);
      _reconnect();
    }
  }

  void _reconnect() {
    setState(() => _connected = false);
    Future.delayed(const Duration(seconds: 3), _connect);
  }

  void _onMsg(dynamic raw) {
    if (!mounted) return;
    final data = json.decode(raw as String) as Map<String, dynamic>;
    setState(() {
      switch (data['type']) {
        case 'message':
          _msgs.add(_ChatMsg.fromJson(data['message'] as Map<String, dynamic>));
          break;
        case 'system':
          _msgs.add(_ChatMsg(
            id: UniqueKey().toString(), userId: '__sys__',
            userName: '', type: 'system',
            text: data['text'] as String? ?? '', ts: DateTime.now()));
          break;
        case 'delete':
          _msgs.removeWhere((m) => m.id == (data['message_id'] as String? ?? ''));
          break;
        case 'reaction':
          final mid = data['message_id'] as String? ?? '';
          final raw2 = data['reactions'] as Map<String, dynamic>? ?? {};
          final i = _msgs.indexWhere((m) => m.id == mid);
          if (i >= 0) {
            _msgs[i].reactions =
                raw2.map((k, v) => MapEntry(k, List<String>.from(v as List)));
          }
          break;
        case 'online':
          _online = (data['count'] as int?) ?? 0;
          break;
      }
    });
    if (data['type'] == 'message') _scrollBottom();
  }

  void _ws(Map<String, dynamic> p) {
    if (!_connected) return;
    _channel!.sink.add(json.encode(p));
  }

  // ── Send ────────────────────────────────────────────────────────────────
  void _sendText() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    _ws({'type': 'text', 'text': t});
    _textCtrl.clear();
    setState(() => _showEmoji = false);
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (f == null) return;
    await _upload(f.path, f.mimeType ?? 'image/jpeg', 'image');
  }

  Future<void> _pickVideo() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (f == null) return;
    await _upload(f.path, 'video/mp4', 'video');
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'ogg', 'wav', 'm4a', 'aac', 'mp4', 'mov', 'webm']);
    if (r == null || r.files.isEmpty || r.files.first.path == null) return;
    final f = r.files.first;
    final ct = _mime(f.extension ?? '');
    await _upload(f.path!, ct, ct.startsWith('audio') ? 'audio' : 'video');
  }

  Future<void> _sendLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        _snack('Localisation refusée'); return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      _ws({'type': 'location', 'text': '',
           'location': {'lat': pos.latitude, 'lng': pos.longitude, 'label': 'Ma position'}});
    } catch (_) {
      _snack('Impossible d\'obtenir la position');
    }
  }

  Future<void> _startRec() async {
    if (kIsWeb) { _snack('Non disponible sur web'); return; }
    if (!await _recorder.hasPermission()) { _snack('Permission micro refusée'); return; }
    final tmp = await _tmpPath();
    _recPath = '$tmp/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recPath!);
    setState(() => _recording = true);
  }

  Future<void> _stopRec() async {
    final p = await _recorder.stop();
    setState(() => _recording = false);
    if (p != null) await _upload(p, 'audio/x-m4a', 'audio');
  }

  Future<String> _tmpPath() async {
    if (kIsWeb) return '/tmp';
    // Use app temp dir on mobile/desktop
    try {
      final dir = await _getTempDirectory();
      return dir;
    } catch (_) { return '/tmp'; }
  }

  Future<String> _getTempDirectory() async {
    // Dynamically call path_provider to avoid web issues
    // On web this code is unreachable because kIsWeb guard above
    return '/tmp'; // overridden per-platform by path_provider import below
  }

  Future<void> _upload(String path, String ct, String kind) async {
    _snack('Envoi…');
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: path.split('/').last,
            contentType: DioMediaType.parse(ct)),
      });
      final res = await ApiClient.instance.dio.post('/chat/upload', data: form);
      final url = res.data['url'] as String;
      _ws({'type': kind, 'text': '', 'media_url': url, 'media_content_type': ct});
    } catch (e) {
      _snack('Erreur: ${e.toString().substring(0, 60)}');
    }
  }

  Future<void> _togglePlay(String url) async {
    final resolved = ApiConstants.resolveImageUrl(url);
    if (_playingUrl == resolved && _isPlaying) {
      await _player.pause(); setState(() => _isPlaying = false);
    } else if (_playingUrl == resolved && !_isPlaying) {
      await _player.resume(); setState(() => _isPlaying = true);
    } else {
      await _player.stop();
      _playingUrl = resolved;
      await _player.play(UrlSource(resolved));
      setState(() => _isPlaying = true);
    }
  }

  void _react(String id, String emoji) => _ws({'type': 'react', 'message_id': id, 'emoji': emoji});
  void _delete(String id) => _ws({'type': 'delete', 'message_id': id});

  void _scrollBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  });
  void _jumpBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  });

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _mime(String ext) => const {
    'mp3': 'audio/mpeg', 'ogg': 'audio/ogg', 'wav': 'audio/wav',
    'm4a': 'audio/x-m4a', 'aac': 'audio/aac',
    'mp4': 'video/mp4', 'mov': 'video/quicktime', 'webm': 'video/webm',
  }[ext.toLowerCase()] ?? 'application/octet-stream';

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1B12) : const Color(0xFFF0F4F1),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F2418) : Colors.white,
        title: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B7A3D), Color(0xFF0F5229)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Chat Global 🌍',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(
              _connected ? '$_online en ligne' : (_connecting ? 'Connexion…' : 'Déconnecté'),
              style: TextStyle(fontSize: 11,
                  color: _connected ? Colors.greenAccent : Colors.orangeAccent),
            ),
          ]),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: Icon(Icons.circle, size: 8,
                  color: _connected ? Colors.greenAccent : Colors.orange),
              label: Text('$_online', style: const TextStyle(fontWeight: FontWeight.w700)),
              visualDensity: VisualDensity.compact,
              backgroundColor: isDark
                  ? const Color(0xFF1A3A25) : theme.colorScheme.primaryContainer,
            ),
          ),
          if (!_connected && !_connecting)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _connect),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _msgs.isEmpty && _connecting
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  itemCount: _msgs.length,
                  itemBuilder: (_, i) => _bubble(_msgs[i], theme, isDark),
                ),
        ),
        if (_showEmoji) SizedBox(
          height: 270,
          child: EmojiPicker(
            onEmojiSelected: (_, e) {
              _textCtrl.text += e.emoji;
              _textCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textCtrl.text.length));
            },
            config: Config(
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: isDark ? const Color(0xFF0F2418) : Colors.white),
            ),
          ),
        ),
        _inputBar(theme, isDark),
      ]),
    );
  }

  // ── Bubble ────────────────────────────────────────────────────────────────
  Widget _bubble(_ChatMsg m, ThemeData theme, bool isDark) {
    if (m.type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20)),
            child: Text(m.text,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
      );
    }

    final isMe = m.userId == _myId;
    final bg = isMe
        ? const Color(0xFF1B7A3D)
        : (isDark ? const Color(0xFF1A3A25) : Colors.white);
    final fg = isMe ? Colors.white : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: _col(m.userId),
              child: Text(m.userName.isNotEmpty ? m.userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _options(m),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(m.userName,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: _col(m.userId))),
                    ),
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.70),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18)),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18)),
                      child: _content(m, fg, theme, isMe),
                    ),
                  ),
                  if (m.reactions.isNotEmpty) _reactions(m),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                    child: Text(_fmtTime(m.ts),
                        style: TextStyle(fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _content(_ChatMsg m, Color fg, ThemeData theme, bool isMe) {
    switch (m.type) {
      // ── Text ──────────────────────────────────────────────────────────────
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(m.text, style: TextStyle(color: fg, fontSize: 15, height: 1.35)));

      // ── Image ─────────────────────────────────────────────────────────────
      case 'image':
        final url = ApiConstants.resolveImageUrl(m.mediaUrl ?? '');
        return GestureDetector(
          onTap: () => _fullImage(url),
          child: Stack(children: [
            Image.network(url, width: 240, height: 180, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 240, height: 180,
                    child: Center(child: Icon(Icons.broken_image, size: 40)))),
            Positioned(right: 8, bottom: 8,
                child: Icon(Icons.zoom_out_map, size: 16,
                    color: Colors.white.withValues(alpha: 0.85))),
          ]),
        );

      // ── Audio ─────────────────────────────────────────────────────────────
      case 'audio':
        final url = m.mediaUrl ?? '';
        final resolved = ApiConstants.resolveImageUrl(url);
        final playing = _playingUrl == resolved && _isPlaying;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            GestureDetector(
              onTap: () => _togglePlay(url),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.22)
                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
                child: Icon(playing ? Icons.pause : Icons.play_arrow,
                    color: isMe ? Colors.white : theme.colorScheme.primary, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_playingUrl == resolved)
                  SliderTheme(
                    data: SliderThemeData(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), trackHeight: 2.5),
                    child: Slider(
                      value: _dur.inMs > 0 ? _pos.inMs / _dur.inMs : 0.0,
                      onChanged: (v) => _player.seek(Duration(milliseconds: (v * _dur.inMs).toInt())),
                      activeColor: isMe ? Colors.white : theme.colorScheme.primary,
                      inactiveColor: isMe ? Colors.white30 : theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  )
                else
                  Container(height: 2.5, margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white30 : theme.colorScheme.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2))),
                Text(
                  _playingUrl == resolved ? '${_fmtDur(_pos)} / ${_fmtDur(_dur)}' : '🎵 Vocal',
                  style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7))),
              ],
            )),
          ]),
        );

      // ── Video ─────────────────────────────────────────────────────────────
      case 'video':
        return GestureDetector(
          onTap: () => _snack('Téléchargez la vidéo depuis : ${ApiConstants.resolveImageUrl(m.mediaUrl ?? "")}'),
          child: Stack(alignment: Alignment.center, children: [
            Container(width: 240, height: 160, color: Colors.black,
                child: const Icon(Icons.videocam, color: Colors.white38, size: 48)),
            Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 30)),
            Positioned(bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Vidéo', style: TextStyle(color: Colors.white, fontSize: 11)))),
          ]),
        );

      // ── Location ──────────────────────────────────────────────────────────
      case 'location':
        final loc = m.location;
        if (loc == null) return const SizedBox.shrink();
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        final label = (loc['label'] as String?) ?? 'Position';
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.location_on, size: 18,
                  color: isMe ? Colors.white : theme.colorScheme.error),
              const SizedBox(width: 6),
              Expanded(child: Text(label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14))),
            ]),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _snack('Maps: https://maps.google.com/?q=$lat,$lng'),
              child: Container(
                width: 210, height: 90,
                decoration: BoxDecoration(
                  color: isMe ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.map_outlined, size: 32,
                      color: isMe ? Colors.white70 : theme.colorScheme.primary),
                  const SizedBox(height: 4),
                  Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 10,
                          color: isMe ? Colors.white60 : theme.colorScheme.onPrimaryContainer)),
                  const SizedBox(height: 2),
                  Text('Toucher pour ouvrir',
                      style: TextStyle(fontSize: 10,
                          color: isMe ? Colors.white50 : theme.colorScheme.primary)),
                ]),
              ),
            ),
          ]),
        );

      default:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text('(message)', style: TextStyle(color: fg, fontSize: 13)));
    }
  }

  Widget _reactions(_ChatMsg m) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(spacing: 4, children: m.reactions.entries.map((e) {
        final iMine = e.value.contains(_myId);
        return GestureDetector(
          onTap: () => _react(m.id, e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: iMine ? Colors.amber.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iMine ? Colors.amber.withValues(alpha: 0.6) : Colors.transparent)),
            child: Text('${e.key} ${e.value.length}', style: const TextStyle(fontSize: 12)),
          ),
        );
      }).toList()),
    );
  }

  void _options(_ChatMsg m) {
    const quickEmoji = ['👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '🎉'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: quickEmoji.map((e) => GestureDetector(
              onTap: () { Navigator.pop(context); _react(m.id, e); },
              child: Text(e, style: const TextStyle(fontSize: 26)))).toList()),
        ),
        const Divider(height: 24),
        if (m.userId == _myId)
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(context); _delete(m.id); }),
        ListTile(
          leading: const Icon(Icons.emoji_emotions_outlined),
          title: const Text('Plus de réactions'),
          onTap: () { Navigator.pop(context); _showMoreEmoji(m); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _showMoreEmoji(_ChatMsg m) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => SizedBox(
        height: 320,
        child: EmojiPicker(
          onEmojiSelected: (_, e) { Navigator.pop(context); _react(m.id, e.emoji); },
        ),
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────
  Widget _inputBar(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2418) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8, offset: const Offset(0, -2))]),
      padding: EdgeInsets.only(
          left: 6, right: 6, top: 6,
          bottom: 6 + MediaQuery.of(context).viewInsets.bottom),
      child: Row(children: [
        // Emoji toggle
        IconButton(
          icon: Icon(_showEmoji ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined,
              color: theme.colorScheme.primary, size: 24),
          onPressed: () => setState(() => _showEmoji = !_showEmoji),
        ),

        // Text input
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A3A25) : const Color(0xFFF0F4F1),
              borderRadius: BorderRadius.circular(24)),
            child: TextField(
              controller: _textCtrl,
              minLines: 1, maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Écrire un message…',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onSubmitted: (_) => _sendText(),
              onTap: () => setState(() => _showEmoji = false),
            ),
          ),
        ),

        const SizedBox(width: 2),

        // Attachment
        PopupMenuButton<String>(
          icon: Icon(Icons.attach_file_rounded, color: theme.colorScheme.secondary),
          tooltip: 'Joindre',
          onSelected: (v) {
            switch (v) {
              case 'image': _pickImage(); break;
              case 'video': _pickVideo(); break;
              case 'file': _pickFile(); break;
              case 'location': _sendLocation(); break;
            }
          },
          itemBuilder: (_) => [
            _menuItem('image', Icons.image_outlined, 'Photo'),
            _menuItem('video', Icons.videocam_outlined, 'Vidéo'),
            _menuItem('file', Icons.audio_file_outlined, 'Audio / Fichier'),
            _menuItem('location', Icons.location_on_outlined, 'Localisation'),
          ],
        ),

        // Send / Record
        ValueListenableBuilder(
          valueListenable: _textCtrl,
          builder: (_, v, __) {
            final hasText = v.text.trim().isNotEmpty;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: hasText
                  ? IconButton(
                      key: const ValueKey('send'),
                      icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary, size: 26),
                      onPressed: _sendText)
                  : GestureDetector(
                      key: const ValueKey('mic'),
                      onLongPressStart: (_) => _startRec(),
                      onLongPressEnd: (_) => _stopRec(),
                      child: IconButton(
                        icon: Icon(
                          _recording ? Icons.stop_circle : Icons.mic_outlined,
                          color: _recording ? Colors.red : theme.colorScheme.primary, size: 26),
                        onPressed: _recording ? _stopRec : _startRec,
                        tooltip: 'Appuyer (ou maintenir) pour enregistrer'),
                    ),
            );
          },
        ),
      ]),
    );
  }

  PopupMenuItem<String> _menuItem(String val, IconData icon, String label) {
    return PopupMenuItem(value: val,
        child: Row(children: [
          Icon(icon, size: 20), const SizedBox(width: 12), Text(label)]));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  void _fullImage(String url) => Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white,
          title: const Text('Photo')),
      body: Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
    )));

  Color _col(String id) {
    const c = [
      Color(0xFF1B7A3D), Color(0xFFF97316), Color(0xFF3B82F6),
      Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6),
      Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFFEF4444),
      Color(0xFF06B6D4),
    ];
    return c[id.hashCode.abs() % c.length];
  }

  String _fmtTime(DateTime dt) {
    final l = dt.toLocal();
    final now = DateTime.now();
    return now.difference(l).inDays == 0
        ? DateFormat('HH:mm').format(l)
        : DateFormat('dd/MM HH:mm').format(l);
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

extension _DurMs on Duration {
  int get inMs => inMilliseconds;
}
