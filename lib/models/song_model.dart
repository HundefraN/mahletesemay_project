import '../utils/amharic_transliterator.dart';

extension DateTimeCompatExtension on DateTime {
  DateTime toDate() => this;
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }
  // If object has toDate method
  try {
    return (value as dynamic).toDate();
  } catch (_) {
    return DateTime.now();
  }
}

class Song {
  final String id;
  final String title;
  final String englishTitle;
  final String artistName;
  final String artistId;
  final String albumId;
  final String albumTitle;
  final String lyrics;
  final String? scale;
  final String? rhythm;
  final int viewCount;
  final DateTime createdAt;
  final List<String> searchKeywords;

  Song({
    required this.id,
    required this.title,
    this.englishTitle = '',
    required this.artistName,
    required this.artistId,
    required this.albumId,
    required this.albumTitle,
    required this.lyrics,
    this.scale,
    this.rhythm,
    required this.viewCount,
    required this.createdAt,
    this.searchKeywords = const [],
  });

  factory Song.fromMap(Map<String, dynamic> data, [String? id]) {
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
    final albumTitle = data['albumTitle']?.toString() ?? data['album_title']?.toString() ?? '';
    final lyrics = data['lyrics']?.toString() ?? '';

    if (keywords.isEmpty) {
      keywords = AmharicTransliterator.generateSearchKeywords(
        title: title,
        englishTitle: engTitle,
        subtitleOrArtist: artistName,
        lyricsOrDescription: lyrics,
      );
    }

    return Song(
      id: (id != null && id.isNotEmpty) ? id : (data['id']?.toString() ?? ''),
      title: title,
      englishTitle: engTitle,
      artistName: artistName,
      artistId: data['artistId']?.toString() ?? data['artist_id']?.toString() ?? '',
      albumId: data['albumId']?.toString() ?? data['album_id']?.toString() ?? '',
      albumTitle: albumTitle,
      lyrics: lyrics,
      scale: data['scale']?.toString(),
      rhythm: data['rhythm']?.toString(),
      viewCount: data['viewCount'] is int
          ? data['viewCount']
          : (data['view_count'] is int ? data['view_count'] : int.tryParse(data['view_count']?.toString() ?? '') ?? 0),
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      searchKeywords: keywords,
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) => Song.fromMap(json);

  factory Song.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return Song.fromMap(doc);
    }
    final data = doc.data() as Map<String, dynamic>;
    return Song.fromMap(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'englishTitle': englishTitle,
      'english_title': englishTitle,
      'artistName': artistName,
      'artist_name': artistName,
      'artistId': artistId,
      'artist_id': artistId,
      'albumId': albumId,
      'album_id': albumId,
      'albumTitle': albumTitle,
      'album_title': albumTitle,
      'lyrics': lyrics,
      'scale': scale,
      'rhythm': rhythm,
      'viewCount': viewCount,
      'view_count': viewCount,
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'search_keywords': searchKeywords,
    };
  }

  Map<String, dynamic> toLocalDbMap() {
    return {
      'id': id,
      'title': title,
      'englishTitle': englishTitle,
      'artistName': artistName,
      'artistId': artistId,
      'albumId': albumId,
      'albumTitle': albumTitle,
      'lyrics': lyrics,
      'scale': scale,
      'rhythm': rhythm,
      'viewCount': viewCount,
      'createdAt': createdAt.millisecondsSinceEpoch,
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
            lyricsOrDescription: lyrics,
          );

    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'english_title': englishTitle,
      'artist_name': artistName,
      'artist_id': artistId,
      'album_id': albumId,
      'album_title': albumTitle,
      'lyrics': lyrics,
      'scale': scale,
      'rhythm': rhythm,
      'view_count': viewCount,
      'created_at': createdAt.toIso8601String(),
      'search_keywords': effectiveKeywords,
    };
  }
}