class Destination {
  final String id;
  final String name;
  final String quartier;
  final String category;
  final String description;
  final List<String> tags;
  final String image;
  final List<String> images; // up to 4 extra community-contributed photos
  final int avgPriceFcfa;
  final String bestTime;
  final int popularity;
  final double? score;
  final List<String> reasons;
  final double lat;
  final double lng;
  final int? foundedYear;
  final String? history;
  final String? mapsUrl;

  Destination({
    required this.id,
    required this.name,
    required this.quartier,
    required this.category,
    required this.description,
    required this.tags,
    required this.image,
    this.images = const [],
    required this.avgPriceFcfa,
    required this.bestTime,
    required this.popularity,
    this.score,
    this.reasons = const [],
    this.lat = 3.8480,
    this.lng = 11.5021,
    this.foundedYear,
    this.history,
    this.mapsUrl,
  });

  factory Destination.fromJson(Map<String, dynamic> j) => Destination(
        id: j['id'],
        name: j['name'],
        quartier: j['quartier'] ?? '',
        category: j['category'] ?? 'attraction',
        description: j['description'] ?? '',
        tags: List<String>.from(j['tags'] ?? []),
        image: j['image'] ?? '',
        images: List<String>.from(j['images'] ?? []),
        avgPriceFcfa: (j['avg_price_fcfa'] ?? 0).toInt(),
        bestTime: j['best_time'] ?? '',
        popularity: (j['popularity'] ?? 0).toInt(),
        score: (j['score'] as num?)?.toDouble(),
        reasons: List<String>.from(j['reasons'] ?? []),
        lat: (j['lat'] as num?)?.toDouble() ?? 3.8480,
        lng: (j['lng'] as num?)?.toDouble() ?? 11.5021,
        foundedYear: (j['founded_year'] as num?)?.toInt(),
        history: j['history'],
        mapsUrl: j['maps_url'],
      );

  /// All photos in display order: cover photo first, then the extras -
  /// deduped and with blanks dropped, so callers never need to worry
  /// about an empty `image` or a stray empty string in `images`.
  List<String> get allPhotos =>
      {image, ...images}.where((u) => u.isNotEmpty).toList();
}
