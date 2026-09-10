import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';

/// A dedicated `/ws/chat` WebSocket connection used purely for WebRTC call
/// signalling (call_join / call_signal / call_leave, matching chat-service's
/// main.py exactly - see the "WebRTC mesh signalling" section there).
///
/// This is a SEPARATE connection from the one global_chat_screen keeps open
/// for the chat itself - both talk to the same backend endpoint (identity
/// comes from the JWT in the query string, same as chat), but each screen
/// manages its own socket lifecycle. CallScreen owns one of these for as
/// long as the call lasts.
///
/// IMPORTANT LIMITATION: the callee only receives call_peer_joined /
/// call_signal events while a `/ws/chat` connection of theirs is open -
/// i.e. while they're actually on the global chat screen or a call screen.
/// There is currently no persistent, app-wide `/ws/chat` connection, so a
/// call can't "ring" someone who isn't already on one of those screens.
/// Making incoming calls reach someone from anywhere in the app would need
/// a connection kept alive at the app-shell level (e.g. a provider created
/// once in main.dart) - that's a deliberate scope decision to flag, not
/// something this fix silently papers over.
class CallSignalingChannel {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final wsBase = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    _channel = WebSocketChannel.connect(
        Uri.parse('$wsBase/ws/chat?token=${Uri.encodeQueryComponent(token)}'));
    await _channel!.ready.timeout(const Duration(seconds: 10));
    _channel!.stream.listen(
      (raw) {
        try {
          final decoded = jsonDecode(raw as String);
          if (decoded is Map<String, dynamic>) {
            _controller.add(decoded);
          }
        } catch (_) {
          // Ignore anything that isn't valid JSON - same tolerance
          // global_chat_screen.dart's own message handler has.
        }
      },
      onError: (_) => _controller.close(),
      onDone: () => _controller.close(),
    );
  }

  void send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  Future<void> close() async {
    await _channel?.sink.close();
  }
}
