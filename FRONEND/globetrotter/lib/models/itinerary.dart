class ItineraryStop {
  final String destinationId;
  final int day;
  final String? notes;

  ItineraryStop({required this.destinationId, this.day = 1, this.notes});

  factory ItineraryStop.fromJson(Map<String, dynamic> j) => ItineraryStop(
        destinationId: j['destination_id'],
        day: (j['day'] ?? 1).toInt(),
        notes: j['notes'],
      );

  Map<String, dynamic> toJson() =>
      {'destination_id': destinationId, 'day': day, 'notes': notes};
}

class Itinerary {
  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String? description;
  final String? startDate;
  final String? endDate;
  final List<ItineraryStop> stops;
  final List<String> sharedWith;
  final bool isPublic;
  final int likeCount;
  final bool likedByMe;
  final int commentCount;

  Itinerary({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    required this.stops,
    required this.sharedWith,
    this.isPublic = false,
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
  });

  factory Itinerary.fromJson(Map<String, dynamic> j) => Itinerary(
        id: j['id'],
        ownerId: j['owner_id'],
        ownerName: j['owner_name'] ?? '',
        title: j['title'],
        description: j['description'],
        startDate: j['start_date'],
        endDate: j['end_date'],
        stops: (j['stops'] as List? ?? []).map((s) => ItineraryStop.fromJson(s)).toList(),
        sharedWith: List<String>.from(j['shared_with'] ?? []),
        isPublic: j['is_public'] ?? false,
        likeCount: j['like_count'] ?? 0,
        likedByMe: j['liked_by_me'] ?? false,
        commentCount: j['comment_count'] ?? 0,
      );

  Itinerary copyWith({int? likeCount, bool? likedByMe, int? commentCount}) => Itinerary(
        id: id,
        ownerId: ownerId,
        ownerName: ownerName,
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        stops: stops,
        sharedWith: sharedWith,
        isPublic: isPublic,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        commentCount: commentCount ?? this.commentCount,
      );
}
