class Review {
  final String id;
  final String userId;
  final String fullName;
  final int rating;
  final String comment;
  final String createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'],
        userId: j['user_id'],
        fullName: j['full_name'] ?? '',
        rating: (j['rating'] as num).toInt(),
        comment: j['comment'] ?? '',
        createdAt: j['created_at'] ?? '',
      );
}
