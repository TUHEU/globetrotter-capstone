class Destination {
  final String id;
  final String name;
  final String quartier;
  final String category;
  final String description;
  final List<String> tags;
  final String image;
  final int avgPriceFcfa;
  final String bestTime;
  final int popularity;
  final double? score;
  final List<String> reasons;

  Destination({
    required this.id,
    required this.name,
    required this.quartier,
    required this.category,
    required this.description,
    required this.tags,
    required this.image,
    required this.avgPriceFcfa,
    required this.bestTime,
    required this.popularity,
    this.score,
    this.reasons = const [],
  });

  factory Destination.fromJson(Map<String, dynamic> j) => Destination(
        id: j['id'],
        name: j['name'],
        quartier: j['quartier'] ?? '',
        category: j['category'] ?? 'attraction',
        description: j['description'] ?? '',
        tags: List<String>.from(j['tags'] ?? []),
        image: j['image'] ?? '',
        avgPriceFcfa: (j['avg_price_fcfa'] ?? 0).toInt(),
        bestTime: j['best_time'] ?? '',
        popularity: (j['popularity'] ?? 0).toInt(),
        score: (j['score'] as num?)?.toDouble(),
        reasons: List<String>.from(j['reasons'] ?? []),
      );
}
