class ItineraryComment {
  final String id;
  final String itineraryId;
  final String userId;
  final String userName;
  final String text;
  final String createdAt;

  ItineraryComment({
    required this.id,
    required this.itineraryId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory ItineraryComment.fromJson(Map<String, dynamic> j) => ItineraryComment(
        id: j['id'],
        itineraryId: j['itinerary_id'],
        userId: j['user_id'],
        userName: j['user_name'],
        text: j['text'],
        createdAt: j['created_at'],
      );
}
