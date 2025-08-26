import 'dart:convert';

class HistoryEntry {
  final String songId;
  final DateTime viewedAt;

  HistoryEntry({
    required this.songId,
    required this.viewedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'songId': songId,
      'viewedAt': viewedAt.toIso8601String(),
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      songId: map['songId'] ?? '',
      viewedAt: DateTime.parse(map['viewedAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory HistoryEntry.fromJson(String source) => HistoryEntry.fromMap(json.decode(source));
}