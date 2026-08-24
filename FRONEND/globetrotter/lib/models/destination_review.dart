class ReviewReply {
  final String id;
  final String userId;
  final String authorName;
  final String text;
  final String createdAt;

  ReviewReply({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory ReviewReply.fromJson(Map<String, dynamic> j) => ReviewReply(
        id: j['id'],
        userId: j['user_id'],
        authorName: j['author_name'] ?? 'Utilisateur',
        text: j['text'] ?? '',
        createdAt: j['created_at'] ?? '',
      );
}

class DestinationReview {
  final String id;
  final String destinationId;
  final String userId;
  final String reviewerName;
  final int rating;
  final String comment;
  final String createdAt;
  final List<ReviewReply> replies;

  DestinationReview({
    required this.id,
    required this.destinationId,
    required this.userId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.replies = const [],
  });

  factory DestinationReview.fromJson(Map<String, dynamic> j) => DestinationReview(
        id: j['id'],
        destinationId: j['destination_id'],
        userId: j['user_id'],
        reviewerName: j['reviewer_name'] ?? 'Utilisateur',
        rating: (j['rating'] as num).toInt(),
        comment: j['comment'] ?? '',
        createdAt: j['created_at'] ?? '',
        replies: (j['replies'] as List? ?? [])
            .map((r) => ReviewReply.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}
