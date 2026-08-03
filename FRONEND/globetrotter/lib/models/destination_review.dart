class DestinationReview {
  final String id;
  final String destinationId;
  final String userId;
  final String reviewerName;
  final int rating;
  final String comment;
  final String createdAt;

  DestinationReview({
    required this.id,
    required this.destinationId,
    required this.userId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory DestinationReview.fromJson(Map<String, dynamic> j) => DestinationReview(
        id: j['id'],
        destinationId: j['destination_id'],
        userId: j['user_id'],
        reviewerName: j['reviewer_name'] ?? 'Utilisateur',
        rating: (j['rating'] as num).toInt(),
        comment: j['comment'] ?? '',
        createdAt: j['created_at'] ?? '',
      );
}
