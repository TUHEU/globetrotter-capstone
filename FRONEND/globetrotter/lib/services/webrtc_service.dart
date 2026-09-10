import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC Service - Manages peer-to-peer video calls.
///
/// Talks to the backend's mesh signalling relay (chat-service main.py,
/// "WebRTC mesh signalling" section) via [sendSignal], which the owner of
/// this service (CallScreen) wires to a CallSignalingChannel. Every
/// outgoing message here is a `call_signal` envelope
/// `{type: 'call_signal', room, target_user_id, data}` - the server relays
/// `data` untouched to `target_user_id` and stamps who it came from; the
/// caller only ever fills in what to send, never who it's "from" (the
/// server derives that from the authenticated connection).
class WebRTCService {
  final String userId;
  final String userName;
  final String room;
  final void Function(Map<String, dynamic> message) sendSignal;

  MediaStream? localStream;

  final Map<String, RTCPeerConnection> remotePeerConnections = {};
  final Map<String, MediaStream> remoteStreams = {};

  void Function(String userId, MediaStream stream)? onRemoteStreamAdd;
  void Function(String userId)? onRemoteStreamRemove;
  void Function(String error)? onError;

  static const List<Map<String, String>> iceCandidates = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ];

  WebRTCService({
    required this.userId,
    required this.userName,
    required this.room,
    required this.sendSignal,
  });

  Future<MediaStream> initializeLocalStream({
    bool audio = true,
    bool video = true,
  }) async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': audio ? {'echoCancellation': true} : false,
        'video': video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      });
      localStream = stream;
      return stream;
    } catch (e) {
      onError?.call('Failed to get local media: $e');
      rethrow;
    }
  }

  void _sendToPeer(String remotePeerId, Map<String, dynamic> data) {
    sendSignal({
      'type': 'call_signal',
      'room': room,
      'target_user_id': remotePeerId,
      'data': data,
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(String remotePeerId) async {
    final peerConnection = await createPeerConnection(
      {'iceServers': iceCandidates},
      {'optional': [{'RtpDataChannels': true}]},
    );

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      _sendToPeer(remotePeerId, {
        'type': 'ice',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        },
      });
    };

    peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStreams[remotePeerId] = event.streams[0];
        onRemoteStreamAdd?.call(remotePeerId, event.streams[0]);
      }
    };

    // MediaStream doesn't expose `audioTracks`/`videoTracks` as properties
    // in flutter_webrtc - only as the methods getAudioTracks()/getVideoTracks().
    final stream = localStream;
    if (stream != null) {
      final audioTracks = stream.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        // addTrack's 2nd parameter is a single MediaStream (or omitted),
        // not a List<String> of stream ids - passing [stream.id] doesn't
        // type-check against the installed flutter_webrtc version.
        await peerConnection.addTrack(audioTracks.first, stream);
      }
      final videoTracks = stream.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await peerConnection.addTrack(videoTracks.first, stream);
      }
    }

    return peerConnection;
  }

  /// Called for each peer already in the room when we join (server's
  /// call_room_state) - the mesh convention is "new peer offers to
  /// existing peers", so this is only ever called by the side that just
  /// joined, never by the side that receives call_peer_joined.
  Future<void> createCallOffer(String remoteUserId) async {
    try {
      if (remotePeerConnections.containsKey(remoteUserId)) return;

      final peerConnection = await _createPeerConnection(remoteUserId);
      remotePeerConnections[remoteUserId] = peerConnection;

      final offer = await peerConnection.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });

      await peerConnection.setLocalDescription(offer);

      _sendToPeer(remoteUserId, {
        'type': 'offer',
        'sdp': {'type': offer.type, 'sdp': offer.sdp},
      });
    } catch (e) {
      onError?.call('Failed to create offer: $e');
    }
  }

  Future<void> _handleCallOffer(
    String remotePeerId,
    Map<String, dynamic> sdp,
  ) async {
    try {
      if (remotePeerConnections.containsKey(remotePeerId)) return;

      final peerConnection = await _createPeerConnection(remotePeerId);
      remotePeerConnections[remotePeerId] = peerConnection;

      final remoteDescription = RTCSessionDescription(sdp['sdp'], sdp['type']);
      await peerConnection.setRemoteDescription(remoteDescription);

      final answer = await peerConnection.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });

      await peerConnection.setLocalDescription(answer);

      _sendToPeer(remotePeerId, {
        'type': 'answer',
        'sdp': {'type': answer.type, 'sdp': answer.sdp},
      });
    } catch (e) {
      onError?.call('Failed to handle offer: $e');
    }
  }

  Future<void> _handleCallAnswer(
    String remotePeerId,
    Map<String, dynamic> sdp,
  ) async {
    try {
      final peerConnection = remotePeerConnections[remotePeerId];
      if (peerConnection == null) return;

      final remoteDescription = RTCSessionDescription(sdp['sdp'], sdp['type']);
      await peerConnection.setRemoteDescription(remoteDescription);
    } catch (e) {
      onError?.call('Failed to handle answer: $e');
    }
  }

  Future<void> _handleIceCandidate(
    String remotePeerId,
    Map<String, dynamic> candidateData,
  ) async {
    try {
      final peerConnection = remotePeerConnections[remotePeerId];
      if (peerConnection == null) return;

      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'] ?? 0,
      );

      await peerConnection.addCandidate(candidate);
    } catch (e) {
      onError?.call('ICE candidate error: $e');
    }
  }

  /// Entry point CallScreen feeds every incoming `call_signal` message
  /// into (fromUserId = the envelope's `from_user_id`, data = its `data`).
  Future<void> handleIncomingSignal(
    String fromUserId,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'];
    switch (type) {
      case 'offer':
        await _handleCallOffer(fromUserId, Map<String, dynamic>.from(data['sdp'] as Map));
        break;
      case 'answer':
        await _handleCallAnswer(fromUserId, Map<String, dynamic>.from(data['sdp'] as Map));
        break;
      case 'ice':
        await _handleIceCandidate(fromUserId, Map<String, dynamic>.from(data['candidate'] as Map));
        break;
    }
  }

  Future<void> toggleMicrophone(bool enabled) async {
    final stream = localStream;
    if (stream == null) return;
    final audioTracks = stream.getAudioTracks();
    if (audioTracks.isEmpty) return;
    for (var track in audioTracks) {
      // `enabled` is a plain property (getter/setter) on MediaStreamTrack
      // in the installed flutter_webrtc version, not a method - assigning
      // to it is synchronous, there's nothing to await.
      track.enabled = enabled;
    }
  }

  Future<void> toggleCamera(bool enabled) async {
    final stream = localStream;
    if (stream == null) return;
    final videoTracks = stream.getVideoTracks();
    if (videoTracks.isEmpty) return;
    for (var track in videoTracks) {
      track.enabled = enabled;
    }
  }

  Future<void> closePeerConnection(String peerId) async {
    final peerConnection = remotePeerConnections.remove(peerId);
    if (peerConnection != null) {
      await peerConnection.close();
    }

    remoteStreams.remove(peerId);
    onRemoteStreamRemove?.call(peerId);
  }

  Future<void> closeAllConnections() async {
    for (final peerId in remotePeerConnections.keys.toList()) {
      await closePeerConnection(peerId);
    }

    final stream = localStream;
    if (stream != null) {
      for (var track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      localStream = null;
    }
  }

  MediaStream? getRemoteStream(String peerId) {
    return remoteStreams[peerId];
  }

  List<String> getConnectedPeers() {
    return remotePeerConnections.keys.toList();
  }
}
