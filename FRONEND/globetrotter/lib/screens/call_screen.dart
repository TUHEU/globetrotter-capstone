import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// One screen, used for both the Global-chat group call and 1-on-1 DM
/// calls - the only difference between them is which room/token the
/// backend hands back (see chat-service's /chat/call/token and
/// user-service's /calls/dm-token), not anything in this UI.
class CallScreen extends StatefulWidget {
  final String url;
  final String token;
  final String roomName;
  final String title;
  final bool startWithVideo;

  const CallScreen({
    super.key,
    required this.url,
    required this.token,
    required this.roomName,
    required this.title,
    this.startWithVideo = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final Room _room;
  EventsListener<RoomEvent>? _listener;
  bool _connecting = true;
  String? _error;
  bool _micEnabled = true;
  bool _cameraEnabled = false;

  @override
  void initState() {
    super.initState();
    _cameraEnabled = widget.startWithVideo;
    _room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _listener = _room.createListener();
    // Room extends ChangeNotifier itself, but listening to raw RoomEvents
    // (not just "something changed") lets us react to specific things
    // later (e.g. a toast when someone joins) without extra plumbing.
    _listener!.on<RoomDisconnectedEvent>((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
    _room.addListener(_onRoomChanged);
    _connect();
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    try {
      await _room.connect(widget.url, widget.token);
      await _room.localParticipant?.setMicrophoneEnabled(true);
      if (widget.startWithVideo) {
        try {
          await _room.localParticipant?.setCameraEnabled(true);
        } catch (_) {
          // Camera can legitimately fail (no camera, permission denied,
          // already in use) - the call should still work as audio-only.
          _cameraEnabled = false;
        }
      }
      if (mounted) setState(() => _connecting = false);
    } catch (e) {
      if (mounted) setState(() { _connecting = false; _error = '$e'; });
    }
  }

  @override
  void dispose() {
    _room.removeListener(_onRoomChanged);
    _listener?.dispose();
    _room.disconnect();
    _room.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    _micEnabled = !_micEnabled;
    await _room.localParticipant?.setMicrophoneEnabled(_micEnabled);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    _cameraEnabled = !_cameraEnabled;
    await _room.localParticipant?.setCameraEnabled(_cameraEnabled);
    if (mounted) setState(() {});
  }

  Future<void> _hangUp() async {
    await _room.disconnect();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final remoteParticipants = _room.remoteParticipants.values.toList();
    final local = _room.localParticipant;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _room.disconnect();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title),
        ),
        body: SafeArea(
          child: _connecting
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Impossible de rejoindre l\'appel :\n${_error!}',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: remoteParticipants.isEmpty
                              ? (local != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: _tileFor(local, isLocal: true),
                                    )
                                  : const SizedBox.shrink())
                              : GridView.count(
                                  crossAxisCount: remoteParticipants.length > 1 ? 2 : 1,
                                  padding: const EdgeInsets.all(8),
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  children: [
                                    for (final p in remoteParticipants) _tileFor(p),
                                  ],
                                ),
                        ),
                        if (remoteParticipants.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('En attente que quelqu\'un d\'autre rejoigne…',
                                style: TextStyle(color: Colors.white54)),
                          )
                        else if (local != null)
                          SizedBox(
                            height: 120,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(width: 90, child: _tileFor(local, isLocal: true)),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _callButton(
                                icon: _micEnabled ? Icons.mic : Icons.mic_off,
                                onPressed: _toggleMic,
                              ),
                              const SizedBox(width: 16),
                              _callButton(
                                icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                                onPressed: _toggleCamera,
                              ),
                              const SizedBox(width: 16),
                              _callButton(
                                icon: Icons.call_end,
                                background: Colors.red,
                                onPressed: _hangUp,
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

  Widget _callButton({required IconData icon, required VoidCallback onPressed, Color? background}) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: background ?? Colors.white24,
      child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onPressed),
    );
  }

  Widget _tileFor(Participant participant, {bool isLocal = false}) {
    VideoTrack? videoTrack;
    for (final pub in participant.videoTrackPublications) {
      if (pub.subscribed && pub.track != null && !pub.track!.muted) {
        videoTrack = pub.track as VideoTrack;
        break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack != null)
            VideoTrackRenderer(videoTrack, mirrorMode: isLocal ? VideoViewMirrorMode.mirror : VideoViewMirrorMode.off)
          else
            Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Text(
                  participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isLocal ? 'Vous' : participant.name,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
