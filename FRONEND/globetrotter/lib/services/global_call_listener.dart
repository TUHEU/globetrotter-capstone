import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'call_signaling_channel.dart';
import 'notification_service.dart';

/// Kept alive for as long as the user is logged in (created once in
/// [main.dart] and started right after login/auto-login succeeds - see
/// HomeScreen.initState). This is the fix for the limitation documented in
/// [CallSignalingChannel]: without one `/ws/chat` connection that stays
/// open app-wide, an incoming call could only reach someone already
/// sitting on the global chat screen or a call screen. Now it reaches them
/// on ANY screen - a profile page, the map, settings, wherever.
///
/// Two things arrive here:
///  - `call_incoming` (a direct DM call aimed at *this* user specifically)
///    → full-screen ringing UI, real ringtone + vibration, until answered/
///    declined/timed out.
///  - `call_start` (someone joined the shared Global Chat call room) → a
///    light, non-intrusive banner ("X started a call - join?"), no ringing,
///    since nobody is being personally singled out.
class IncomingCall {
  final String room;
  final String fromUserId;
  final String fromUserName;
  final bool video;
  IncomingCall({
    required this.room,
    required this.fromUserId,
    required this.fromUserName,
    required this.video,
  });
}

class GlobalCallStartBanner {
  final String userName;
  GlobalCallStartBanner(this.userName);
}

class GlobalCallListener extends ChangeNotifier {
  final CallSignalingChannel _channel = CallSignalingChannel();
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _ringTimer;
  Timer? _reconnectTimer;
  bool _started = false;
  bool _disposed = false;

  IncomingCall? incomingCall;
  GlobalCallStartBanner? globalBanner;
  String? _myUserId;

  /// True once the app-wide socket is actually connected (used only for
  /// diagnostics/retry logic, not shown in the UI).
  bool connected = false;

  Future<void> start(String myUserId) async {
    _myUserId = myUserId;
    if (_started) return;
    _started = true;
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      await _channel.connect();
      connected = true;
      _sub = _channel.messages.listen(_onMessage, onDone: _scheduleReconnect);
    } catch (_) {
      connected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    connected = false;
    if (_disposed || !_started) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), _connect);
  }

  void _onMessage(Map<String, dynamic> msg) {
    final type = msg['type'];
    if (type == 'call_incoming') {
      incomingCall = IncomingCall(
        room: msg['room']?.toString() ?? '',
        fromUserId: msg['from_user_id']?.toString() ?? '',
        fromUserName: msg['from_user_name']?.toString() ?? 'Inconnu',
        video: msg['video'] == true,
      );
      _startRinging();
      NotificationService.instance.showMessage(
        title: incomingCall!.video ? 'Appel vidéo entrant' : 'Appel entrant',
        body: incomingCall!.fromUserName,
      );
      notifyListeners();
    } else if (type == 'call_declined' || type == 'call_invite_failed') {
      // The person we called said no, or couldn't be reached - stop
      // whatever ring/dial UI is showing for that outgoing attempt.
      outgoingCallEnded = msg['detail']?.toString() ?? 'declined';
      notifyListeners();
    } else if (type == 'call_start') {
      final uid = msg['user_id']?.toString();
      if (uid != null && uid != _myUserId) {
        globalBanner = GlobalCallStartBanner(msg['user_name']?.toString() ?? '');
        notifyListeners();
      }
    } else if (type == 'call_end') {
      if (globalBanner != null) {
        globalBanner = null;
        notifyListeners();
      }
    }
  }

  String? outgoingCallEnded;
  void clearOutgoingCallEnded() {
    outgoingCallEnded = null;
  }

  void _startRinging() {
    _ringTimer?.cancel();
    // No bundled ringtone asset shipped with this project (nothing to add
    // to pubspec.yaml without it being uploaded), so this uses a system
    // alert sound + repeated haptic pulses instead of a custom audio file -
    // works out of the box on every platform, no new asset/dependency.
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    });
    // Auto-dismiss like a real phone if nobody answers.
    Future.delayed(const Duration(seconds: 30), () {
      if (incomingCall != null) {
        final missed = incomingCall!;
        _declineInternal(missed);
        NotificationService.instance.showMessage(
          title: 'Appel manqué',
          body: missed.fromUserName,
        );
      }
    });
  }

  void _stopRinging() {
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  /// Sent by the caller right before opening CallScreen, so the callee
  /// gets a real ring even though they haven't joined the room yet.
  void sendInvite({required String targetUserId, required String room, required bool video}) {
    _channel.send({
      'type': 'call_invite',
      'target_user_id': targetUserId,
      'room': room,
      'video': video,
    });
  }

  void _declineInternal(IncomingCall call) {
    _channel.send({
      'type': 'call_decline',
      'target_user_id': call.fromUserId,
      'room': call.room,
    });
    _stopRinging();
    incomingCall = null;
    notifyListeners();
  }

  void declineIncomingCall() {
    final call = incomingCall;
    if (call == null) return;
    _declineInternal(call);
  }

  /// Called by the UI once it has navigated to CallScreen for this invite.
  void consumeIncomingCall() {
    _stopRinging();
    incomingCall = null;
    notifyListeners();
  }

  void dismissGlobalBanner() {
    globalBanner = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ringTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel.close();
    super.dispose();
  }
}
