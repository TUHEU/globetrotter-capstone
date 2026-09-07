import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import '../services/call_controller.dart';

class PersistentCallScreen extends StatelessWidget {
  const PersistentCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallController>();
    final room = call.room;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Appel du Chat Global'),
        actions: [
          if (call.amICreator)
            IconButton(
              tooltip: 'Demandes',
              icon: Badge(
                label: Text('${call.pendingJoinRequests.length}'),
                isLabelVisible: call.pendingJoinRequests.isNotEmpty,
                child: const Icon(Icons.person_add_alt),
              ),
              onPressed: () => _showRequests(context, call),
            ),
        ],
      ),
      body: SafeArea(
        child: call.connectingRoom
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : call.connectError != null && room == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 34),
                        const SizedBox(height: 12),
                        Text(call.connectError!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: call.retryConnect, child: const Text('Réessayer')),
                      ]),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(child: room == null ? const Center(child: Text('En attente…', style: TextStyle(color: Colors.white54))) : _participants(room)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _button(call.micEnabled ? Icons.mic : Icons.mic_off, call.toggleMicrophone),
                          const SizedBox(width: 16),
                          if (call.myCall?.isVideo ?? true) ...[
                            _button(call.cameraEnabled ? Icons.videocam : Icons.videocam_off, call.toggleCamera),
                            const SizedBox(width: 16),
                          ],
                          _button(Icons.call_end, call.leaveCall, red: true),
                        ]),
                      ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _showRequests(BuildContext context, CallController call) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => AnimatedBuilder(
        animation: call,
        builder: (_, __) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: call.pendingJoinRequests.isEmpty
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune demande en attente.')))
                : ListView(shrinkWrap: true, children: [
                    for (final r in call.pendingJoinRequests)
                      ListTile(
                        leading: CircleAvatar(child: Text(r.username.isEmpty ? '?' : r.username[0].toUpperCase())),
                        title: Text(r.username),
                        subtitle: const Text('Demande à rejoindre l’appel'),
                        trailing: Wrap(spacing: 4, children: [
                          IconButton(tooltip: 'Refuser', icon: const Icon(Icons.close), onPressed: () => call.respondToJoinRequest(r.callId, r.username, false)),
                          IconButton(tooltip: 'Accepter', icon: const Icon(Icons.check), onPressed: () => call.respondToJoinRequest(r.callId, r.username, true)),
                        ]),
                      ),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _participants(lk.Room room) {
    final participants = <lk.Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
    if (participants.isEmpty) return const Center(child: Text('En attente que quelqu\'un rejoigne…', style: TextStyle(color: Colors.white54)));
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length > 1 ? 2 : 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: participants.length,
      itemBuilder: (_, i) => _tile(participants[i], local: i == 0 && room.localParticipant != null),
    );
  }

  Widget _tile(lk.Participant p, {required bool local}) {
    lk.VideoTrack? video;
    for (final pub in p.videoTrackPublications) {
      if (pub.subscribed && pub.track != null && !pub.track!.muted) {
        video = pub.track as lk.VideoTrack;
        break;
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFF1A1A1A),
        child: Stack(fit: StackFit.expand, children: [
          if (video != null)
            lk.VideoTrackRenderer(video, mirrorMode: local ? lk.VideoViewMirrorMode.mirror : lk.VideoViewMirrorMode.off)
          else
            Center(child: CircleAvatar(radius: 34, child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'))),
          Positioned(left: 10, bottom: 10, child: DecoratedBox(decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(local ? 'Vous' : (p.name.isEmpty ? p.identity : p.name), style: const TextStyle(color: Colors.white))))),
        ]),
      ),
    );
  }

  Widget _button(IconData icon, VoidCallback onPressed, {bool red = false}) => CircleAvatar(
        radius: 27,
        backgroundColor: red ? Colors.red : Colors.white24,
        child: IconButton(onPressed: onPressed, icon: Icon(icon, color: Colors.white)),
      );
}
