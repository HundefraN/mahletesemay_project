import '../utils/amharic_transliterator.dart';

class Album {
  final String id;
  final String title;
  final String englishTitle;
  final String artistId;
  final String artistName;
  final String coverImageUrl;
  final int? year;
  final int? volume;
  final List<String> searchKeywords;

  Album({
    required this.id,
    required this.title,
    this.englishTitle = '',
    required this.artistId,
    required this.artistName,
    required this.coverImageUrl,
    this.year,
    this.volume,
    this.searchKeywords = const [],
  });

  factory Album.fromMap(Map<String, dynamic> data, [String? id]) {
    final title = data['title']?.toString() ?? '';
    final engTitle = data['englishTitle']?.toString() ??
        data['english_title']?.toString() ??
        (AmharicTransliterator.containsAmharic(title)
            ? AmharicTransliterator.toLatin(title)
            : '');

    List<String> keywords = [];
    if (data['searchKeywords'] is List) {
      keywords = List<String>.from(data['searchKeywords'].map((e) => e.toString()));
    } else if (data['search_keywords'] is List) {
      keywords = List<String>.from(data['search_keywords'].map((e) => e.toString()));
    }

    final artistName = data['artistName']?.toString() ?? data['artist_name']?.toString() ?? '';

    if (keywords.isEmpty) {
      keywords = AmharicTransliterator.generateSearchKeywords(
        title: title,
        englishTitle: engTitle,
        subtitleOrArtist: artistName,
      );
    }

    return Album(
      id: (id != null && id.isNotEmpty) ? id : (data['id']?.toString() ?? ''),
      title: title,
      englishTitle: engTitle,
      artistId: data['artistId']?.toString() ?? data['artist_id']?.toString() ?? '',
      artistName: artistName,
      coverImageUrl: data['coverImageUrl'] ?? data['cover_image_url'] ?? '',
      year: data['year'] is int ? data['year'] : int.tryParse(data['year']?.toString() ?? ''),
      volume: data['volume'] is int ? data['volume'] : int.tryParse(data['volume']?.toString() ?? ''),
      searchKeywords: keywords,
    );
  }

  factory Album.fromJson(Map<String, dynamic> json) => Album.fromMap(json);

  // Backward compatibility factory alias
  factory Album.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return Album.fromMap(doc);
    }
    final data = doc.data() as Map<String, dynamic>;
    return Album.fromMap(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'englishTitle': englishTitle,
      'english_title': englishTitle,
      'artistId': artistId,
      'artist_id': artistId,
      'artistName': artistName,
      'artist_name': artistName,
      'coverImageUrl': coverImageUrl,
      'cover_image_url': coverImageUrl,
      'year': year,
      'volume': volume,
      'search_keywords': searchKeywords,
    };
  }

  Map<String, dynamic> toLocalDbMap() {
    return {
      'id': id,
      'title': title,
      'englishTitle': englishTitle,
      'artistId': artistId,
      'artistName': artistName,
      'coverImageUrl': coverImageUrl,
      'year': year,
      'volume': volume,
      'search_keywords': searchKeywords.join(','),
    };
  }

  Map<String, dynamic> toSupabase() {
    final effectiveKeywords = searchKeywords.isNotEmpty
        ? searchKeywords
        : AmharicTransliterator.generateSearchKeywords(
            title: title,
            englishTitle: englishTitle,
            subtitleOrArtist: artistName,
          );

    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'english_title': englishTitle,
      'artist_id': artistId,
      'artist_name': artistName,
      'cover_image_url': coverImageUrl,
      'year': year,
      'volume': volume,
      'search_keywords': effectiveKeywords,
    };
  }
}