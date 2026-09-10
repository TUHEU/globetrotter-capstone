import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/call_signaling_channel.dart';
import '../services/webrtc_service.dart';

/// WebRTC P2P Call Screen - replaces LiveKit.
/// Used for both Global-chat group call and 1-on-1 DM calls.
///
/// Owns its own [CallSignalingChannel] (a dedicated `/ws/chat` connection)
/// for the lifetime of the call - see that class for why it's a separate
/// connection from the chat screen's, and its important limitation about
/// who can currently receive an incoming call.
class CallScreen extends StatefulWidget {
  final String callRoomId;
  final String title;
  final String userId;
  final String userName;
  final bool startWithVideo;

  const CallScreen({
    super.key,
    required this.callRoomId,
    required this.title,
    required this.userId,
    required this.userName,
    this.startWithVideo = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late WebRTCService webRTCService;
  late RTCVideoRenderer localVideoRenderer;
  final Map<String, RTCVideoRenderer> remoteVideoRenderers = {};
  final CallSignalingChannel _signaling = CallSignalingChannel();
  StreamSubscription<Map<String, dynamic>>? _signalingSub;

  bool _micEnabled = true;
  bool _cameraEnabled = false;
  bool _isConnecting = true;
  bool _hungUp = false;
  String? _error;
  List<String> connectedPeers = [];

  @override
  void initState() {
    super.initState();
    _cameraEnabled = widget.startWithVideo;
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      await _signaling.connect();

      webRTCService = WebRTCService(
        userId: widget.userId,
        userName: widget.userName,
        room: widget.callRoomId,
        sendSignal: _signaling.send,
      );

      webRTCService.onRemoteStreamAdd = _handleRemoteStreamAdd;
      webRTCService.onRemoteStreamRemove = _handleRemoteStreamRemove;
      webRTCService.onError = _handleError;

      final stream = await webRTCService.initializeLocalStream(
        audio: true,
        video: _cameraEnabled,
      );

      localVideoRenderer = RTCVideoRenderer();
      await localVideoRenderer.initialize();
      localVideoRenderer.srcObject = stream;

      _signalingSub = _signaling.messages.listen(_handleSignalingMessage);

      _signaling.send({'type': 'call_join', 'room': widget.callRoomId});

      if (mounted) {
        setState(() => _isConnecting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _error = 'Erreur: $e';
        });
      }
    }
  }

  void _handleSignalingMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      // Sent to us right after call_join: everyone already in the room.
      // Mesh convention is "new peer offers to existing peers", so WE
      // create the offer to each of them (the reverse case, call_peer_joined
      // below, does NOT offer - it waits for the offer to arrive instead).
      case 'call_room_state':
        final peers = (msg['peers'] as List?) ?? const [];
        for (final p in peers) {
          final peerId = (p as Map)['user_id'] as String;
          _addParticipant(peerId);
        }
        break;

      // Someone else joined the room after us - just wait for their offer.
      case 'call_peer_joined':
        final peerId = msg['user_id'] as String;
        if (mounted && !connectedPeers.contains(peerId)) {
          setState(() => connectedPeers.add(peerId));
        }
        break;

      // Relayed SDP offer/answer or ICE candidate from one specific peer.
      case 'call_signal':
        final fromUserId = msg['from_user_id'] as String;
        final data = Map<String, dynamic>.from(msg['data'] as Map);
        webRTCService.handleIncomingSignal(fromUserId, data);
        break;

      case 'call_peer_left':
        final peerId = msg['user_id'] as String;
        webRTCService.closePeerConnection(peerId);
        break;
    }
  }

  void _addParticipant(String peerId) async {
    if (mounted && !connectedPeers.contains(peerId)) {
      setState(() => connectedPeers.add(peerId));
    }
    await webRTCService.createCallOffer(peerId);
  }

  void _handleRemoteStreamAdd(String userId, MediaStream stream) {
    final renderer = RTCVideoRenderer();
    renderer.initialize().then((_) {
      renderer.srcObject = stream;
      if (mounted) {
        setState(() {
          remoteVideoRenderers[userId] = renderer;
        });
      }
    });
  }

  void _handleRemoteStreamRemove(String userId) {
    final renderer = remoteVideoRenderers.remove(userId);
    renderer?.dispose();
    if (mounted) {
      setState(() {
        connectedPeers.remove(userId);
      });
    }
  }

  void _handleError(String error) {
    if (mounted) {
      setState(() {
        _error = error;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleMic() async {
    _micEnabled = !_micEnabled;
    await webRTCService.toggleMicrophone(_micEnabled);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    _cameraEnabled = !_cameraEnabled;
    await webRTCService.toggleCamera(_cameraEnabled);
    if (mounted) setState(() {});
  }

  Future<void> _hangUp() async {
    if (_hungUp) return;
    _hungUp = true;

    await webRTCService.closeAllConnections();
    _signaling.send({'type': 'call_leave', 'room': widget.callRoomId});
    await _signalingSub?.cancel();
    await _signaling.close();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    localVideoRenderer.dispose();
    for (final renderer in remoteVideoRenderers.values) {
      renderer.dispose();
    }
    _hangUp();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _hangUp();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.title),
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Participants: ${connectedPeers.length + 1}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        body: _isConnecting
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text('Connexion en cours...'),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Retour'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SafeArea(
                    child: Column(
                      children: [
                        // Main video area
                        Expanded(
                          child: remoteVideoRenderers.isEmpty
                              ? _buildLocalViewOnly()
                              : _buildGridView(),
                        ),

                        // Call controls
                        Container(
                          color: Theme.of(context).cardColor,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildControlButton(
                                icon: _micEnabled ? Icons.mic : Icons.mic_off,
                                onPressed: _toggleMic,
                              ),
                              const SizedBox(width: 16),
                              _buildControlButton(
                                icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                                onPressed: _toggleCamera,
                              ),
                              const SizedBox(width: 16),
                              _buildControlButton(
                                icon: Icons.call_end,
                                onPressed: _hangUp,
                                isEndCall: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildLocalViewOnly() {
    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: RTCVideoView(
            localVideoRenderer,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          ),
        ),

        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_in_talk, size: 48, color: Colors.white54),
                SizedBox(height: 12),
                Text(
                  'En attente de participants...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridView() {
    final videoRenderers = remoteVideoRenderers.entries.toList();
    final itemCount = videoRenderers.length;

    int crossAxisCount;
    if (itemCount == 1) {
      crossAxisCount = 1;
    } else if (itemCount <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final entry = videoRenderers[index];
        final peerId = entry.key;
        final renderer = entry.value;

        return Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    peerId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isEndCall = false,
  }) {
    final color = isEndCall ? Colors.red : Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        iconSize: 24,
        onPressed: onPressed,
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}
