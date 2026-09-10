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
  final double? distanceKm;

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
    this.distanceKm,
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
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
      );

  /// All photos in display order: cover photo first, then the extras -
  /// deduped and with blanks dropped, so callers never need to worry
  /// about an empty `image` or a stray empty string in `images`.
  List<String> get allPhotos =>
      {image, ...images}.where((u) => u.isNotEmpty).toList();

  /// Best-effort "open now" guess from the free-text `best_time` field
  /// (e.g. "Matin", "Soirée", "24h/24") matched against the current local
  /// hour. There is no real opening-hours data in the catalogue, so this
  /// is a heuristic, not a guarantee - a place with an empty/unrecognised
  /// best_time is treated as "always open" rather than excluded, since
  /// under-filtering is far less annoying than hiding a place that's
  /// actually open.
  bool isLikelyOpenNow(DateTime now) {
    final t = bestTime.toLowerCase();
    if (t.isEmpty) return true;
    if (t.contains('24h') || t.contains("toute l'année") || t.contains('toute la journée')) {
      return true;
    }
    final hour = now.hour;
    final isMorning = hour >= 6 && hour < 12;
    final isAfternoon = hour >= 12 && hour < 17;
    final isEvening = hour >= 17 && hour < 23;
    bool matches = false;
    if (t.contains('matin')) matches = matches || isMorning;
    if (t.contains('midi') || t.contains('après-midi') || t.contains('journée') || t.contains('déjeuner')) {
      matches = matches || isAfternoon || isMorning;
    }
    if (t.contains('soir') || t.contains('dîner') || t.contains('nuit')) matches = matches || isEvening;
    if (t.contains('heures de bureau') || t.contains('jours ouvrés') || t.contains('bureau')) {
      matches = matches || ((isMorning || isAfternoon) && now.weekday <= 5);
    }
    // Anything else too specific to guess reliably (rendez-vous, jour de
    // match, dates d'événements...) - don't exclude it just because the
    // heuristic can't parse it.
    if (!t.contains('matin') &&
        !t.contains('midi') &&
        !t.contains('après-midi') &&
        !t.contains('journée') &&
        !t.contains('déjeuner') &&
        !t.contains('soir') &&
        !t.contains('dîner') &&
        !t.contains('nuit') &&
        !t.contains('bureau') &&
        !t.contains('ouvrés')) {
      return true;
    }
    return matches;
  }
}
