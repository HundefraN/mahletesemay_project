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
  try {
    return (value as dynamic).toDate();
  } catch (_) {
    return DateTime.now();
  }
}

enum SuggestionStatus { pending, approved, rejected }

class Suggestion {
  final String id;
  final String songTitle;
  final String artistName;
  final String lyrics;
  final String? submittedBy;
  final DateTime submittedAt;
  final SuggestionStatus status;

  Suggestion({
    required this.id,
    required this.songTitle,
    required this.artistName,
    required this.lyrics,
    this.submittedBy,
    required this.submittedAt,
    this.status = SuggestionStatus.pending,
  });

  factory Suggestion.fromMap(Map<String, dynamic> data, [String? id]) {
    final statusStr = (data['status']?.toString() ?? 'pending').toLowerCase();
    return Suggestion(
      id: (id != null && id.isNotEmpty) ? id : (data['id']?.toString() ?? ''),
      songTitle: data['songTitle'] ?? data['song_title'] ?? '',
      artistName: data['artistName'] ?? data['artist_name'] ?? '',
      lyrics: data['lyrics'] ?? '',
      submittedBy: data['submittedBy'] ?? data['submitted_by'],
      submittedAt: _parseDateTime(data['submittedAt'] ?? data['submitted_at']),
      status: SuggestionStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => SuggestionStatus.pending,
      ),
    );
  }

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion.fromMap(json);

  factory Suggestion.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return Suggestion.fromMap(doc);
    }
    final data = doc.data() as Map<String, dynamic>;
    return Suggestion.fromMap(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'songTitle': songTitle,
      'song_title': songTitle,
      'artistName': artistName,
      'artist_name': artistName,
      'lyrics': lyrics,
      'submittedBy': submittedBy,
      'submitted_by': submittedBy,
      'submittedAt': submittedAt.toIso8601String(),
      'submitted_at': submittedAt.toIso8601String(),
      'status': status.name,
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id.isNotEmpty) 'id': id,
      'song_title': songTitle,
      'artist_name': artistName,
      'lyrics': lyrics,
      'submitted_by': submittedBy,
      'submitted_at': submittedAt.toIso8601String(),
      'status': status.name,
    };
  }
}