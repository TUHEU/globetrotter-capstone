import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/call_models.dart';
import 'call_socket_service.dart';

const String communityRoomId = 'community';

/// Persistent call state, following the working Trip Chat implementation:
/// signaling comes from /chat/ws, the backend mints the LiveKit token only
/// after the call action, and the LiveKit Room belongs to this controller,
/// not to a page. Navigating away therefore does not invalidate the call.
class CallController extends ChangeNotifier {
  CallController() {
    _sub = _socket.events.listen(_onEvent);
  }

  final CallSocketService _socket = CallSocketService();
  StreamSubscription<CallSocketEvent>? _sub;
  final Map<String, CallSession> _active = {};
  final List<CallJoinRequest> _pendingJoinRequests = [];
  String? _myCallId;
  CallConnectionInfo? _connection;
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _roomListener;
  bool _connecting = false;
  bool _permissionDenied = false;
  String? _connectError;
  bool micEnabled = true;
  bool cameraEnabled = false;

  List<CallSession> activeCallsFor(String roomId) =>
      _active.values.where((c) => c.roomId == roomId).toList();
  CallSession? get myCall => _myCallId == null ? null : _active[_myCallId];
  List<CallSession> joinableCallsFor(String roomId) =>
      activeCallsFor(roomId).where((c) => c.id != _myCallId).toList();
  lk.Room? get room => _room;
  bool get isInCall => _room != null;
  bool get connectingRoom => _connecting;
  bool get permissionDenied => _permissionDenied;
  String? get connectError => _connectError;
  List<CallJoinRequest> get pendingJoinRequests => List.unmodifiable(_pendingJoinRequests);
  bool get amICreator => myCall != null && _creator;
  bool get signalingConnected => _socket.isConnected;
  String? _currentUsername;
  String? _connectedToken;
  bool _creator = false;

  Future<String?> _token() async => (await SharedPreferences.getInstance()).getString('token');

  Future<void> ensureConnected() async {
    final token = await _token();
    if (token != null && token.isNotEmpty) {
      if (_socket.isConnected && _connectedToken == token) return;
      if (_socket.isConnected) _socket.disconnect();
      await _socket.connect(() => token);
      _connectedToken = token;
      if (!_socket.isConnected) {
        _connectedToken = null;
        _connectError = 'Impossible de connecter le canal d'appel.';
        notifyListeners();
        return;
      }
      try {
        final me = await ApiClient.instance.dio.get('/me');
        _currentUsername = me.data['username']?.toString() ?? me.data['full_name']?.toString();
      } catch (_) {}
      await loadActiveCalls(communityRoomId);
    }
  }

  Future<void> loadActiveCalls(String roomId) async {
    final token = await _token();
    if (token == null || token.isEmpty) return;
    try {
      final res = await ApiClient.instance.dio.get('/chat/calls/active', queryParameters: {'room_id': roomId});
      final list = (res.data['calls'] as List? ?? [])
          .map((j) => CallSession.fromJson(j as Map<String, dynamic>))
          .toList();
      _active.removeWhere((_, c) => c.roomId == roomId);
      for (final c in list) _active[c.id] = c;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> _ensureMedia(bool video) async {
    _permissionDenied = false;
    _connectError = null;
    lk.LocalAudioTrack? audio;
    lk.LocalVideoTrack? camera;
    try {
      audio = await lk.LocalAudioTrack.create();
      if (video) camera = await lk.LocalVideoTrack.createCameraTrack();
      return true;
    } catch (e) {
      final m = e.toString().toLowerCase();
      if (m.contains('permission') || m.contains('notallowed')) {
        _permissionDenied = true;
      } else {
        _connectError = e.toString();
      }
      notifyListeners();
      return false;
    } finally {
      await audio?.stop();
      await camera?.stop();
    }
  }

  Future<void> startCall({bool video = true, String roomId = communityRoomId}) async {
    if (_myCallId != null || _connecting) return;
    if (!await _ensureMedia(video)) return;
    await ensureConnected();
    if (!_socket.isConnected) return;
    _socket.send('call:start', {'call_type': video ? 'video' : 'audio', 'room_id': roomId});
  }

  Future<void> requestJoin(String callId) async {
    final call = _active[callId];
    if (!await _ensureMedia(call?.isVideo ?? true)) return;
    await ensureConnected();
    if (!_socket.isConnected) return;
    _myCallId = callId;
    notifyListeners();
    _socket.send('call:request_join', {'call_id': callId});
  }

  Future<void> _connectRoom(CallConnectionInfo info) async {
    if (info.token.isEmpty || info.livekitUrl.isEmpty) {
      _connectError = 'Le serveur n\'a pas fourni les informations LiveKit.';
      notifyListeners();
      return;
    }
    if (_room != null) await _disconnectRoom();
    _connecting = true;
    _connectError = null;
    _permissionDenied = false;
    notifyListeners();
    final room = lk.Room(roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true));
    try {
      await room.connect(
        info.livekitUrl,
        info.token,
        connectOptions: const lk.ConnectOptions(
          timeouts: lk.Timeouts(
            connection: Duration(seconds: 20),
            debounce: Duration(milliseconds: 20),
            publish: Duration(seconds: 10),
            subscribe: Duration(seconds: 10),
            peerConnection: Duration(seconds: 10),
            iceRestart: Duration(seconds: 10),
          ),
        ),
      );
      await room.localParticipant?.setMicrophoneEnabled(true);
      final video = _active[info.callId]?.isVideo ?? true;
      if (video) {
        try {
          await room.localParticipant?.setCameraEnabled(true);
          cameraEnabled = true;
        } catch (_) {
          cameraEnabled = false;
        }
      }
      micEnabled = true;
      _room = room;
      _roomListener = room.createListener()..on<lk.RoomDisconnectedEvent>((_) => _onRoomDisconnected());
    } catch (e) {
      final m = e.toString().toLowerCase();
      if (m.contains('permission') || m.contains('notallowed')) {
        _permissionDenied = true;
      } else {
        _connectError = e.toString();
      }
      await room.dispose();
    }
    _connecting = false;
    notifyListeners();
  }

  void _onRoomDisconnected() {
    if (_room == null) return;
    _myCallId = null;
    _creator = false;
    _connection = null;
    unawaited(_disconnectRoom());
    notifyListeners();
  }

  Future<void> _disconnectRoom() async {
    final room = _room;
    _room = null;
    unawaited(_roomListener?.dispose());
    _roomListener = null;
    if (room != null) {
      try { await room.disconnect(); } catch (_) {}
      try { await room.dispose(); } catch (_) {}
    }
  }

  Future<void> retryConnect() async {
    final info = _connection;
    if (info != null) await _connectRoom(info);
  }

  Future<void> toggleMicrophone() async {
    final p = _room?.localParticipant;
    if (p == null) return;
    final next = !micEnabled;
    await p.setMicrophoneEnabled(next);
    micEnabled = next;
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    final p = _room?.localParticipant;
    if (p == null) return;
    final next = !cameraEnabled;
    try {
      await p.setCameraEnabled(next);
      cameraEnabled = next;
      notifyListeners();
    } catch (e) {
      _connectError = e.toString();
      notifyListeners();
    }
  }


  Future<void> respondToJoinRequest(String callId, String username, bool approve) async {
    _pendingJoinRequests.removeWhere((r) => r.username == username && r.callId == callId);
    notifyListeners();
    await ensureConnected();
    _socket.send('call:respond_join', {
      'call_id': callId,
      'target_username': username,
      'approve': approve,
    });
  }

  void leaveCall() {
    final id = _myCallId;
    if (id == null) return;
    _myCallId = null;
    _creator = false;
    _connection = null;
    unawaited(_disconnectRoom());
    _socket.send('call:leave', {'call_id': id});
    notifyListeners();
  }

  void endCall() {
    final id = _myCallId;
    if (id == null) return;
    _myCallId = null;
    _creator = false;
    _connection = null;
    unawaited(_disconnectRoom());
    _socket.send('call:end', {'call_id': id});
    notifyListeners();
  }

  void _onEvent(CallSocketEvent event) {
    switch (event.type) {
      case 'call:started':
      case 'call:participant_update':
        final c = CallSession.fromJson(event.data);
        _active[c.id] = c;
        notifyListeners();
        break;
      case 'call:you_started':
        final json = event.data['call'];
        if (json is! Map<String, dynamic>) return;
        final c = CallSession.fromJson(json);
        _active[c.id] = c;
        _myCallId = c.id;
        _creator = true;
        _connection = CallConnectionInfo(
          callId: c.id,
          token: (event.data['token'] ?? '').toString(),
          livekitUrl: (event.data['livekit_url'] ?? '').toString(),
        );
        unawaited(_connectRoom(_connection!));
        notifyListeners();
        break;
      case 'call:join_requested':
        final r = CallJoinRequest.fromJson(event.data);
        if (!_pendingJoinRequests.any((x) => x.callId == r.callId && x.username == r.username)) {
          _pendingJoinRequests.add(r);
          notifyListeners();
        }
        break;
      case 'call:join_approved':
        final id = (event.data['call_id'] ?? '').toString();
        _myCallId = id;
        _creator = false;
        _connection = CallConnectionInfo(
          callId: id,
          token: (event.data['token'] ?? '').toString(),
          livekitUrl: (event.data['livekit_url'] ?? '').toString(),
        );
        unawaited(_connectRoom(_connection!));
        notifyListeners();
        break;
      case 'call:join_rejected':
        _myCallId = null;
        notifyListeners();
        break;
      case 'call:ended':
        final id = (event.data['call_id'] ?? '').toString();
        _active.remove(id);
        _pendingJoinRequests.removeWhere((r) => r.callId == id);
        if (id == _myCallId) {
          _myCallId = null;
          _creator = false;
          _connection = null;
          unawaited(_disconnectRoom());
        }
        notifyListeners();
        break;
      case 'error':
        _connectError = event.data['detail']?.toString();
        notifyListeners();
        break;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_disconnectRoom());
    unawaited(_socket.dispose());
    super.dispose();
  }
}
