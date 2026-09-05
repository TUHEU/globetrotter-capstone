// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api_client.dart';
import '../core/avatars.dart';
import '../core/constants.dart';
import '../models/friend.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import 'chat_user_sheet.dart';
import 'call_screen.dart';
import 'location_view_screen.dart';
import 'video_view_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class _ChatMsg {
  final String id;
  final String userId;
  final String userName;
  final String? avatar;
  final String type; // text|image|audio|video|location|system
  String text;
  final String? mediaUrl;
  final Map<String, dynamic>? location;
  Map<String, List<String>> reactions;
  bool edited;
  final Map<String, dynamic>? replyTo; // {id, user_name, type, text} snapshot
  final DateTime ts;

  // Author can edit/delete their own text message for this long after
  // sending it. Mirrors EDIT_DELETE_WINDOW_SECONDS on the server.
  static const editWindow = Duration(minutes: 5);

  bool get isWithinEditWindow => DateTime.now().difference(ts) <= editWindow;

  _ChatMsg({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatar,
    required this.type,
    this.text = '',
    this.mediaUrl,
    this.location,
    Map<String, List<String>>? reactions,
    this.edited = false,
    this.replyTo,
    required this.ts,
  }) : reactions = reactions ?? {};

  factory _ChatMsg.fromJson(Map<String, dynamic> j) {
    final raw = (j['reactions'] as Map<String, dynamic>?) ?? {};
    return _ChatMsg(
      id: j['id'] as String? ?? UniqueKey().toString(),
      userId: j['user_id'] as String? ?? '',
      userName: j['user_name'] as String? ?? 'Inconnu',
      avatar: j['avatar'] as String?,
      type: j['type'] as String? ?? 'text',
      text: j['text'] as String? ?? '',
      mediaUrl: j['media_url'] as String?,
      location: j['location'] as Map<String, dynamic>?,
      reactions: raw.map((k, v) => MapEntry(k, List<String>.from(v as List))),
      edited: j['edited'] as bool? ?? false,
      replyTo: j['reply_to'] as Map<String, dynamic>?,
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
  Timer? _reconnectTimer;
  bool _connected = false;
  bool _connecting = false;

  final List<_ChatMsg> _msgs = [];
  final _scroll = ScrollController();
  final _textCtrl = TextEditingController();
  bool _showEmoji = false;
  int _online = 0;

  // Typing indicator: userId -> userName, each entry auto-expires a few
  // seconds after the last "typing" event from that user (no explicit
  // "stopped typing" event from the server, so a timeout is the signal).
  final Map<String, String> _typingUsers = {};
  final Map<String, Timer> _typingExpiry = {};
  DateTime? _lastTypingSent;

  // Message currently being replied to, shown as a preview above the
  // input bar until sent or cancelled.
  _ChatMsg? _replyTarget;

  // @-mention: userId -> displayName for everyone tagged in the message
  // currently being composed, plus the live search results shown while
  // typing "@something".
  final Map<String, String> _mentionedUsers = {};
  List<Friend> _mentionSuggestions = [];
  Timer? _mentionDebounce;

  // Global call: whether anyone (including us) is currently in the shared
  // call room, and whether we're mid-request fetching our own join token.
  bool _callActive = false;
  bool _startingCall = false;

  // Audio
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _recording = false;
  String? _recPath;
  StreamSubscription<Uint8List>? _recordStreamSub;
  BytesBuilder? _recordBytes;
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
    _textCtrl.addListener(_onTextChanged);
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _pos = p); });
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _dur = d); });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _playingUrl = null; _pos = Duration.zero; });
    });
  }

  void _onTextChanged() {
    _checkMentionTrigger();
    if (_textCtrl.text.trim().isEmpty) return;
    final now = DateTime.now();
    // Throttle to at most one "typing" event every 2.5s so a burst of
    // keystrokes doesn't spam the socket.
    if (_lastTypingSent != null && now.difference(_lastTypingSent!) < const Duration(milliseconds: 2500)) {
      return;
    }
    _lastTypingSent = now;
    _ws({'type': 'typing'});
  }

  /// Looks for an unfinished "@query" right before the cursor (e.g. typing
  /// "hey @jo" shows suggestions for "jo"; a space or the start of the
  /// message ends the query). Debounces the actual search call.
  void _checkMentionTrigger() {
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.baseOffset;
    if (cursor < 0) {
      setState(() => _mentionSuggestions = []);
      return;
    }
    final upToCursor = text.substring(0, cursor);
    final at = upToCursor.lastIndexOf('@');
    if (at == -1) {
      if (_mentionSuggestions.isNotEmpty) setState(() => _mentionSuggestions = []);
      return;
    }
    // Only a valid trigger if the "@" starts the message or follows
    // whitespace - "email@domain" shouldn't pop up suggestions.
    final validStart = at == 0 || RegExp(r'\s').hasMatch(upToCursor[at - 1]);
    if (!validStart) {
      if (_mentionSuggestions.isNotEmpty) setState(() => _mentionSuggestions = []);
      return;
    }
    final query = upToCursor.substring(at + 1);
    if (query.contains(' ') || query.contains('\n')) {
      if (_mentionSuggestions.isNotEmpty) setState(() => _mentionSuggestions = []);
      return;
    }
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final res = await ApiClient.instance.dio.get('/users/search', queryParameters: {'q': query});
        if (!mounted) return;
        final results = (res.data['results'] as List? ?? [])
            .map((j) => Friend.fromJson(j as Map<String, dynamic>))
            .where((f) => f.id != _myId)
            .take(5)
            .toList();
        setState(() => _mentionSuggestions = results);
      } catch (_) {
        // Silent: mention autocomplete is a nice-to-have, not worth a
        // snackbar every time a search hiccups.
      }
    });
  }

  void _pickMention(Friend f) {
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.baseOffset;
    final upToCursor = text.substring(0, cursor < 0 ? text.length : cursor);
    final at = upToCursor.lastIndexOf('@');
    if (at == -1) return;
    final before = text.substring(0, at);
    final after = text.substring(cursor < 0 ? text.length : cursor);
    final insertion = '@${f.fullName} ';
    _textCtrl.value = TextEditingValue(
      text: before + insertion + after,
      selection: TextSelection.collapsed(offset: (before + insertion).length),
    );
    _mentionedUsers[f.id] = f.fullName;
    setState(() => _mentionSuggestions = []);
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _recordStreamSub?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _mentionDebounce?.cancel();
    _scroll.dispose();
    _recorder.dispose();
    _player.dispose();
    for (final t in _typingExpiry.values) {
      t.cancel();
    }
    super.dispose();
  }

  // ── WS ──────────────────────────────────────────────────────────────────
  Future<void> _connect() async {
    if (_connecting || !mounted) return;
    _reconnectTimer?.cancel();
    setState(() { _connecting = true; _connected = false; });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) {
      if (mounted) {
        setState(() => _connecting = false);
        _snack('Session expirée. Reconnectez-vous.');
      }
      return;
    }

    // Load history first. If this fails in production it usually means the
    // Nginx /chat route is not forwarded to the API gateway. Do not swallow
    // the error silently: the user needs a useful status.
    try {
      final res = await ApiClient.instance.dio.get('/chat/history');
      final rawList = (res.data['messages'] as List?) ?? const [];
      final list = rawList
          .map((m) => _ChatMsg.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
      if (mounted) {
        setState(() { _msgs.clear(); _msgs.addAll(list); });
        _jumpBottom();
      }
    } on DioException catch (e) {
      if (mounted) {
        final status = e.response?.statusCode;
        _snack(status == 404
            ? 'Chat indisponible: route /chat non configurée sur le serveur.'
            : 'Impossible de charger le chat (${status ?? 'réseau'}).');
      }
    }

    final wsBase = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    try {
      await _sub?.cancel();
      await _channel?.sink.close();
      _channel = WebSocketChannel.connect(
          Uri.parse('$wsBase/ws/chat?token=${Uri.encodeQueryComponent(token)}'));
      await _channel!.ready.timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() { _connected = true; _connecting = false; });
      _sub = _channel!.stream.listen(
        _onMsg,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      if (mounted) setState(() => _connecting = false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    if (_connected || _connecting) {
      setState(() { _connected = false; _connecting = false; });
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }

  void _onMsg(dynamic raw) {
    if (!mounted) return;
    final data = json.decode(raw as String) as Map<String, dynamic>;
    setState(() {
      switch (data['type']) {
        case 'message':
          final msg = _ChatMsg.fromJson(data['message'] as Map<String, dynamic>);
          _msgs.add(msg);
          // They just sent a real message, so they're no longer "typing" -
          // don't wait for the timeout to clear it.
          _typingUsers.remove(msg.userId);
          _typingExpiry.remove(msg.userId)?.cancel();
          // Only alert for messages from other people, and only when this
          // chat isn't the screen currently on-screen (no point pinging
          // someone about a message they're already looking at).
          if (msg.userId != _myId && !(ModalRoute.of(context)?.isCurrent ?? true)) {
            final preview = switch (msg.type) {
              'image' => '📷 Photo',
              'audio' => '🎵 Message vocal',
              'video' => '🎬 Vidéo',
              'location' => '📍 Position partagée',
              _ => msg.text,
            };
            NotificationService.instance
                .showMessage(title: msg.userName, body: preview);
          }
          break;
        case 'typing':
          final uid = data['user_id'] as String? ?? '';
          final uname = data['user_name'] as String? ?? '';
          if (uid.isEmpty || uid == _myId) break;
          _typingUsers[uid] = uname;
          _typingExpiry.remove(uid)?.cancel();
          _typingExpiry[uid] = Timer(const Duration(seconds: 4), () {
            if (!mounted) return;
            setState(() => _typingUsers.remove(uid));
          });
          break;
        case 'call_start':
          _callActive = true;
          final starterName = data['user_name'] as String? ?? '';
          final starterId = data['user_id'] as String? ?? '';
          if (starterId != _myId) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _snack('$starterName a démarré un appel — appuyez sur 📹 pour rejoindre'));
          }
          break;
        case 'call_end':
          // Best-effort: we don't track a participant count, so treat any
          // call_end as "assume the call is now empty" - worst case
          // someone sees the icon go grey for a moment while others are
          // still on the call, which is harmless (tapping it still joins
          // the same room either way).
          _callActive = false;
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
        case 'edit':
          final updated = data['message'] as Map<String, dynamic>? ?? {};
          final mid = updated['id'] as String? ?? '';
          final i = _msgs.indexWhere((m) => m.id == mid);
          if (i >= 0) {
            _msgs[i].text = updated['text'] as String? ?? _msgs[i].text;
            _msgs[i].edited = true;
          }
          break;
        case 'online':
          _online = (data['count'] as int?) ?? 0;
          break;
        case 'error':
          final detail = data['detail'] as String? ?? 'Action refusée';
          WidgetsBinding.instance.addPostFrameCallback((_) => _snack(detail));
          break;
      }
    });
    if (data['type'] == 'message') _scrollBottom();
  }

  void _ws(Map<String, dynamic> p) {
    if (!_connected) return;
    _channel!.sink.add(json.encode(p));
  }

  String _previewFor(String type, String text) => switch (type) {
        'image' => '📷 Photo',
        'audio' => '🎵 Message vocal',
        'video' => '🎬 Vidéo',
        'location' => '📍 Position',
        _ => text,
      };

  Widget _replyPreviewBar(ThemeData theme) {
    final target = _replyTarget!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(children: [
        Container(width: 3, height: 32, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(target.userName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary)),
              Text(_previewFor(target.type, target.text),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => setState(() => _replyTarget = null),
        ),
      ]),
    );
  }

  // ── Call ────────────────────────────────────────────────────────────────
  Future<void> _joinGlobalCall() async {
    setState(() => _startingCall = true);
    try {
      final res = await ApiClient.instance.dio.post('/chat/call/token');
      if (!mounted) return;
      _ws({'type': 'call_start'});
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          url: res.data['url'],
          token: res.data['token'],
          roomName: res.data['room'],
          title: 'Appel du Chat Global',
        ),
      ));
      _ws({'type': 'call_end'});
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      _snack(detail?.toString() ?? 'Impossible de démarrer l\'appel.');
    } finally {
      if (mounted) setState(() => _startingCall = false);
    }
  }

  // ── Send ────────────────────────────────────────────────────────────────
  void _sendText() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    final payload = <String, dynamic>{'type': 'text', 'text': t};
    if (_replyTarget != null) payload['reply_to'] = _replyTarget!.id;
    // Only keep mentions whose "@Name" text is still actually present -
    // if the user backspaced over a tag after inserting it, don't notify
    // that person for a mention that no longer appears in the message.
    final mentions = _mentionedUsers.entries
        .where((e) => t.contains('@${e.value}'))
        .map((e) => e.key)
        .toList();
    if (mentions.isNotEmpty) payload['mentions'] = mentions;
    _ws(payload);
    _textCtrl.clear();
    _mentionedUsers.clear();
    setState(() { _showEmoji = false; _replyTarget = null; _mentionSuggestions = []; });
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (f == null) return;
    final ct = f.mimeType ?? _mime(f.name.split('.').last, fallback: 'image/jpeg');
    if (kIsWeb) {
      await _uploadBytes(await f.readAsBytes(), f.name, ct, 'image');
    } else {
      await _uploadPath(f.path, f.name, ct, 'image');
    }
  }

  Future<void> _pickVideo() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (f == null) return;
    final ct = f.mimeType ?? _mime(f.name.split('.').last, fallback: 'video/mp4');
    if (kIsWeb) {
      await _uploadBytes(await f.readAsBytes(), f.name, ct, 'video');
    } else {
      await _uploadPath(f.path, f.name, ct, 'video');
    }
  }

  Future<void> _pickFile() async {
    // file_picker v12 removed FilePickerResult/withData/PlatformFile.bytes.
    // pickFiles() now returns List<PlatformFile> directly, and file bytes are
    // loaded on demand via PlatformFile.readAsBytes() instead of a `bytes`
    // field populated by a `withData` flag.
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: ['mp3', 'ogg', 'wav', 'm4a', 'aac', 'mp4', 'mov', 'webm'],
    );
    if (files.isEmpty) return;
    final f = files.first;
    final ct = _mime(f.extension ?? '');
    final kind = ct.startsWith('audio') ? 'audio' : 'video';
    if (kIsWeb) {
      try {
        final bytes = await f.readAsBytes();
        await _uploadBytes(bytes, f.name, ct, kind);
      } catch (_) {
        _snack('Impossible de lire ce fichier sur le web.');
      }
    } else if (f.path != null) {
      await _uploadPath(f.path!, f.name, ct, kind);
    }
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
    if (!await _recorder.hasPermission()) {
      _snack('Permission micro refusée');
      return;
    }
    try {
      if (kIsWeb) {
        _recordBytes = BytesBuilder(copy: false);
        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 44100,
            numChannels: 1,
          ),
        );
        _recordStreamSub = stream.listen((chunk) => _recordBytes?.add(chunk));
      } else {
        final dir = await getTemporaryDirectory();
        _recPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _recPath!,
        );
      }
      if (mounted) setState(() => _recording = true);
    } catch (e) {
      _snack('Impossible de démarrer le micro: $e');
    }
  }

  Future<void> _stopRec() async {
    try {
      final p = await _recorder.stop();
      if (mounted) setState(() => _recording = false);
      if (kIsWeb) {
        await _recordStreamSub?.cancel();
        _recordStreamSub = null;
        final bytes = _recordBytes?.takeBytes() ?? Uint8List(0);
        _recordBytes = null;
        if (bytes.isNotEmpty) {
          final wav = _pcm16ToWav(bytes, sampleRate: 44100, channels: 1);
          await _uploadBytes(
            wav,
            'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
            'audio/wav',
            'audio',
          );
        }
      } else if (p != null) {
        await _uploadPath(p, p.split(RegExp(r'[\\/]')).last, 'audio/x-m4a', 'audio');
      }
    } catch (e) {
      if (mounted) setState(() => _recording = false);
      _snack('Erreur enregistrement: $e');
    }
  }

  Uint8List _pcm16ToWav(Uint8List pcm, {required int sampleRate, required int channels}) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final out = BytesBuilder(copy: false);
    final header = ByteData(44);

    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        header.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);

    out.add(header.buffer.asUint8List());
    out.add(pcm);
    return out.takeBytes();
  }

  Future<void> _uploadPath(
      String path, String filename, String ct, String kind) async {
    final file = await MultipartFile.fromFile(
      path, filename: filename, contentType: DioMediaType.parse(ct));
    await _uploadMultipart(file, ct, kind);
  }

  Future<void> _uploadBytes(
      Uint8List bytes, String filename, String ct, String kind) async {
    final file = MultipartFile.fromBytes(
      bytes, filename: filename, contentType: DioMediaType.parse(ct));
    await _uploadMultipart(file, ct, kind);
  }

  Future<void> _uploadMultipart(
      MultipartFile file, String ct, String kind) async {
    if (!_connected) {
      _snack('Le chat est déconnecté. Reconnexion en cours…');
      _scheduleReconnect();
      return;
    }
    _snack('Envoi…');
    try {
      final form = FormData.fromMap({'file': file});
      final res = await ApiClient.instance.dio.post(
        '/chat/upload',
        data: form,
        options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
      );
      final url = res.data['url'] as String;
      _ws({'type': kind, 'text': '', 'media_url': url, 'media_content_type': ct});
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      _snack('Échec de l’envoi: ${detail ?? e.response?.statusCode ?? 'réseau'}');
    } catch (e) {
      _snack('Échec de l’envoi: $e');
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
  void _edit(String id, String newText) =>
      _ws({'type': 'edit', 'message_id': id, 'text': newText});

  void _scrollBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  });
  void _jumpBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  });

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _mime(String ext, {String fallback = 'application/octet-stream'}) => const {
    'mp3': 'audio/mpeg', 'ogg': 'audio/ogg', 'wav': 'audio/wav',
    'm4a': 'audio/x-m4a', 'aac': 'audio/aac',
    'mp4': 'video/mp4', 'mov': 'video/quicktime', 'webm': 'video/webm',
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
    'webp': 'image/webp', 'gif': 'image/gif',
  }[ext.toLowerCase()] ?? fallback;

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
          const Icon(Icons.public_rounded, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('Global Chat', overflow: TextOverflow.ellipsis)),
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
          IconButton(
            icon: Icon(_callActive ? Icons.videocam : Icons.videocam_outlined,
                color: _callActive ? Colors.greenAccent : null),
            tooltip: _callActive ? 'Rejoindre l\'appel en cours' : 'Démarrer un appel',
            onPressed: _startingCall ? null : _joinGlobalCall,
          ),
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
        if (_mentionSuggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F2418) : Colors.white,
              border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _mentionSuggestions.length,
              itemBuilder: (_, i) {
                final f = _mentionSuggestions[i];
                return ListTile(
                  dense: true,
                  leading: UserAvatar(name: f.fullName, avatar: f.avatar, color: theme.colorScheme.primary, radius: 16),
                  title: Text(f.fullName),
                  onTap: () => _pickMention(f),
                );
              },
            ),
          ),
        if (_typingUsers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _typingUsers.length == 1
                    ? '${_typingUsers.values.first} est en train d\'écrire…'
                    : '${_typingUsers.values.join(', ')} sont en train d\'écrire…',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
          ),
        if (_replyTarget != null) _replyPreviewBar(theme),
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
            GestureDetector(
              onTap: () => showChatUserSheet(context,
                  userId: m.userId, userName: m.userName, avatar: m.avatar, avatarColor: _col(m.userId)),
              child: UserAvatar(name: m.userName, avatar: m.avatar, color: _col(m.userId), radius: 15),
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
                    GestureDetector(
                      onTap: () => showChatUserSheet(context,
                          userId: m.userId, userName: m.userName, avatar: m.avatar, avatarColor: _col(m.userId)),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(m.userName,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: _col(m.userId))),
                      ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.replyTo != null) _replyQuote(m.replyTo!, fg, isMe),
                          _content(m, fg, theme, isMe),
                        ],
                      ),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              icon: const Icon(Icons.more_vert, size: 16),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              tooltip: 'Options',
              onPressed: () => _options(m),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyQuote(Map<String, dynamic> reply, Color fg, bool isMe) {
    final quotedName = reply['user_name'] as String? ?? '';
    final quotedType = reply['type'] as String? ?? 'text';
    final quotedText = reply['text'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (isMe ? Colors.white : Colors.black).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: fg.withValues(alpha: 0.6), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(quotedName,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.85))),
          Text(_previewFor(quotedType, quotedText),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7))),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m.text, style: TextStyle(color: fg, fontSize: 15, height: 1.35)),
              if (m.edited)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('modifié',
                      style: TextStyle(
                          color: fg.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        );

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
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  VideoViewScreen(url: ApiConstants.resolveImageUrl(m.mediaUrl ?? '')))),
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
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LocationViewScreen(lat: lat, lng: lng, label: label))),
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
                          color: isMe ? Colors.white54 : theme.colorScheme.primary)),
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
        if (m.type != 'system')
          ListTile(
            leading: const Icon(Icons.reply_outlined),
            title: const Text('Répondre'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _replyTarget = m);
            },
          ),
        if (m.type == 'text')
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Copier'),
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: m.text));
              _snack('Message copié');
            },
          ),
        if (m.userId == _myId) ...[
          if (m.type == 'text')
            ListTile(
              leading: Icon(Icons.edit_outlined,
                  color: m.isWithinEditWindow ? null : Colors.grey),
              title: Text('Modifier',
                  style: TextStyle(color: m.isWithinEditWindow ? null : Colors.grey)),
              subtitle: m.isWithinEditWindow
                  ? null
                  : const Text('Délai de 5 minutes dépassé'),
              onTap: () {
                Navigator.pop(context);
                if (m.isWithinEditWindow) {
                  _editDialog(m);
                } else {
                  _snack('Vous ne pouvez plus modifier ce message (délai de 5 min dépassé).');
                }
              },
            ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: m.isWithinEditWindow ? Colors.red : Colors.grey),
            title: Text('Supprimer',
                style: TextStyle(color: m.isWithinEditWindow ? Colors.red : Colors.grey)),
            subtitle: m.isWithinEditWindow
                ? null
                : const Text('Délai de 5 minutes dépassé'),
            onTap: () {
              Navigator.pop(context);
              if (m.isWithinEditWindow) {
                _delete(m.id);
              } else {
                _snack('Vous ne pouvez plus supprimer ce message (délai de 5 min dépassé).');
              }
            },
          ),
        ],
        ListTile(
          leading: const Icon(Icons.emoji_emotions_outlined),
          title: const Text('Plus de réactions'),
          onTap: () { Navigator.pop(context); _showMoreEmoji(m); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _editDialog(_ChatMsg m) {
    final ctrl = TextEditingController(text: m.text);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final t = ctrl.text.trim();
              Navigator.pop(dialogCtx);
              if (t.isNotEmpty && t != m.text) _edit(m.id, t);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
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
      // Le Scaffold rétrécit déjà automatiquement le body de la hauteur du
      // clavier (resizeToAvoidBottomInset, activé par défaut) - ajouter EN
      // PLUS `MediaQuery.viewInsets.bottom` ici comptait cette hauteur deux
      // fois, ce qui poussait toute la barre de saisie trop haut au-dessus
      // du clavier au lieu de rester juste au-dessus, laissant un grand
      // espace vide entre les deux.
      padding: const EdgeInsets.only(left: 6, right: 6, top: 6, bottom: 6),
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
