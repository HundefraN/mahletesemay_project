import '../utils/amharic_transliterator.dart';

class Artist {
  final String id;
  final String name;
  final String englishName;
  final String imageUrl;
  final String region;
  final List<String> searchKeywords;

  Artist({
    required this.id,
    required this.name,
    this.englishName = '',
    required this.imageUrl,
    required this.region,
    this.searchKeywords = const [],
  });

  factory Artist.fromMap(Map<String, dynamic> data, [String? id]) {
    final name = data['name']?.toString() ?? '';
    final engName = data['englishName']?.toString() ??
        data['english_name']?.toString() ??
        (AmharicTransliterator.containsAmharic(name)
            ? AmharicTransliterator.toLatin(name)
            : '');

    List<String> keywords = [];
    if (data['searchKeywords'] is List) {
      keywords = List<String>.from(data['searchKeywords'].map((e) => e.toString()));
    } else if (data['search_keywords'] is List) {
      keywords = List<String>.from(data['search_keywords'].map((e) => e.toString()));
    }

    if (keywords.isEmpty) {
      keywords = AmharicTransliterator.generateSearchKeywords(
        title: name,
        englishTitle: engName,
        subtitleOrArtist: data['region']?.toString(),
      );
    }

    return Artist(
      id: (id != null && id.isNotEmpty) ? id : (data['id']?.toString() ?? ''),
      name: name,
      englishName: engName,
      imageUrl: data['imageUrl'] ?? data['image_url'] ?? '',
      region: data['region'] ?? '',
      searchKeywords: keywords,
    );
  }

  factory Artist.fromJson(Map<String, dynamic> json) => Artist.fromMap(json);

  // Backward compatibility factory alias
  factory Artist.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return Artist.fromMap(doc);
    }
    final data = doc.data() as Map<String, dynamic>;
    return Artist.fromMap(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'englishName': englishName,
      'english_name': englishName,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'region': region,
      'search_keywords': searchKeywords,
    };
  }

  Map<String, dynamic> toLocalDbMap() {
    return {
      'id': id,
      'name': name,
      'englishName': englishName,
      'imageUrl': imageUrl,
      'region': region,
      'search_keywords': searchKeywords.join(','),
    };
  }

  Map<String, dynamic> toSupabase() {
    final effectiveKeywords = searchKeywords.isNotEmpty
        ? searchKeywords
        : AmharicTransliterator.generateSearchKeywords(
            title: name,
            englishTitle: englishName,
            subtitleOrArtist: region,
          );

    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'english_name': englishName,
      'image_url': imageUrl,
      'region': region,
      'search_keywords': effectiveKeywords,
    };
  }
}