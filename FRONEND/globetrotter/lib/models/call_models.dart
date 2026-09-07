/// Call payloads used by the LiveKit-powered chat call protocol.
class CallSession {
  const CallSession({
    required this.id,
    required this.roomId,
    required this.initiatorUsername,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.participantCount = 0,
  });

  final String id;
  final String? roomId;
  final String initiatorUsername;
  final String callType;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int participantCount;

  bool get isActive => status == 'active';
  bool get isVideo => callType == 'video';

  factory CallSession.fromJson(Map<String, dynamic> json) => CallSession(
        id: (json['id'] ?? '').toString(),
        roomId: json['room_id']?.toString(),
        initiatorUsername: (json['initiator_username'] ?? '').toString(),
        callType: (json['call_type'] ?? 'video').toString(),
        status: (json['status'] ?? 'active').toString(),
        startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()),
        endedAt: json['ended_at'] == null
            ? null
            : DateTime.tryParse(json['ended_at'].toString()),
        participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      );
}

class CallJoinRequest {
  const CallJoinRequest({required this.callId, required this.username, this.avatarUrl});
  final String callId;
  final String username;
  final String? avatarUrl;

  factory CallJoinRequest.fromJson(Map<String, dynamic> json) => CallJoinRequest(
        callId: (json['call_id'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        avatarUrl: json['avatar_url']?.toString(),
      );
}

class CallConnectionInfo {
  const CallConnectionInfo({required this.callId, required this.token, required this.livekitUrl});
  final String callId;
  final String token;
  final String livekitUrl;
}

class IncomingCallInfo {
  const IncomingCallInfo({required this.call, this.callerAvatarUrl});
  final CallSession call;
  final String? callerAvatarUrl;

  factory IncomingCallInfo.fromJson(Map<String, dynamic> json) => IncomingCallInfo(
        call: CallSession.fromJson(json['call'] as Map<String, dynamic>),
        callerAvatarUrl: json['caller_avatar_url']?.toString(),
      );
}
