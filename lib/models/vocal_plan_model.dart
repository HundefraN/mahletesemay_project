import '../utils/amharic_transliterator.dart';

class VocalExerciseDay {
  final String id;
  final int dayNumber;
  final String title;
  final String englishTitle;
  final String description;
  final String? audioUrl;
  final bool isRestDay;
  final List<String> searchKeywords;

  VocalExerciseDay({
    required this.id,
    required this.dayNumber,
    required this.title,
    this.englishTitle = '',
    required this.description,
    this.audioUrl,
    this.isRestDay = false,
    this.searchKeywords = const [],
  });

  factory VocalExerciseDay.fromMap(Map<String, dynamic> data, [String? id]) {
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

    final description = data['description']?.toString() ?? '';

    if (keywords.isEmpty) {
      keywords = AmharicTransliterator.generateSearchKeywords(
        title: title,
        englishTitle: engTitle,
        lyricsOrDescription: description,
      );
    }

    return VocalExerciseDay(
      id: (id != null && id.isNotEmpty) ? id : (data['id']?.toString() ?? ''),
      dayNumber: data['dayNumber'] is int
          ? data['dayNumber']
          : (data['day_number'] is int ? data['day_number'] : int.tryParse(data['day_number']?.toString() ?? '') ?? 0),
      title: title,
      englishTitle: engTitle,
      description: description,
      audioUrl: data['audioUrl'] ?? data['audio_url'],
      isRestDay: data['isRestDay'] ?? data['is_rest_day'] ?? false,
      searchKeywords: keywords,
    );
  }

  factory VocalExerciseDay.fromJson(Map<String, dynamic> json) => VocalExerciseDay.fromMap(json);

  factory VocalExerciseDay.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return VocalExerciseDay.fromMap(doc);
    }
    final data = doc.data() as Map<String, dynamic>;
    return VocalExerciseDay.fromMap(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'dayNumber': dayNumber,
      'day_number': dayNumber,
      'title': title,
      'englishTitle': englishTitle,
      'english_title': englishTitle,
      'description': description,
      'audioUrl': audioUrl,
      'audio_url': audioUrl,
      'isRestDay': isRestDay,
      'is_rest_day': isRestDay,
      'search_keywords': searchKeywords,
    };
  }

  Map<String, dynamic> toSupabase([String? planId]) {
    final effectiveKeywords = searchKeywords.isNotEmpty
        ? searchKeywords
        : AmharicTransliterator.generateSearchKeywords(
            title: title,
            englishTitle: englishTitle,
            lyricsOrDescription: description,
          );

    return {
      if (id.isNotEmpty) 'id': id,
      if (planId != null) 'plan_id': planId,
      'day_number': dayNumber,
      'title': title,
      'english_title': englishTitle,
      'description': description,
      'audio_url': audioUrl,
      'is_rest_day': isRestDay,
      'search_keywords': effectiveKeywords,
    };
  }
}