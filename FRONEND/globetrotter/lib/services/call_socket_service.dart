import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/api_client.dart';

class CallSocketEvent {
  const CallSocketEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;

  factory CallSocketEvent.fromJson(Map<String, dynamic> json) => CallSocketEvent(
        (json['type'] ?? '').toString(),
        (json['data'] as Map<String, dynamic>?) ?? const {},
      );
}

/// Dedicated signaling socket. The important part copied from the working
/// Trip Chat implementation is that LiveKit is NEVER connected with a token
/// fetched by a screen. The server first receives call:start/call:join and
/// then sends a freshly minted token in call:you_started/call:join_approved.
class CallSocketService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _events = StreamController<CallSocketEvent>.broadcast();
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _manual = true;
  String? Function()? _tokenProvider;
  Object? _attempt;

  Stream<CallSocketEvent> get events => _events.stream;
  bool get isConnected => _channel != null;

  Future<void> connect(String? Function() tokenProvider) async {
    _tokenProvider = tokenProvider;
    _manual = false;
    _reconnectTimer?.cancel();
    await _connectNow();
  }

  void disconnect() {
    _manual = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void send(String type, Map<String, dynamic> data) {
    final c = _channel;
    if (c == null) return;
    c.sink.add(jsonEncode({'type': type, 'data': data}));
  }

  Future<void> _connectNow() async {
    final token = _tokenProvider?.call();
    if (token == null || token.isEmpty) return;
    final marker = Object();
    _attempt = marker;
    final channel = WebSocketChannel.connect(Uri.parse(ApiClient.resolveChatWsUrl(token)));
    try {
      await channel.ready;
    } catch (_) {
      if (identical(_attempt, marker) && !_manual) _scheduleReconnect();
      return;
    }
    if (!identical(_attempt, marker) || _manual) {
      unawaited(channel.sink.close());
      return;
    }
    _channel = channel;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => send('ping', const {}));
    _subscription = channel.stream.listen(_raw, onDone: _lost, onError: (_) => _lost(), cancelOnError: true);
  }

  void _raw(dynamic raw) {
    if (raw is! String) return;
    try {
      final e = CallSocketEvent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (e.type != 'pong') _events.add(e);
    } catch (_) {}
  }

  void _lost() {
    _heartbeatTimer?.cancel();
    _subscription = null;
    _channel = null;
    if (!_manual) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!_manual) _connectNow();
    });
  }

  Future<void> dispose() async {
    disconnect();
    await _events.close();
  }
}
