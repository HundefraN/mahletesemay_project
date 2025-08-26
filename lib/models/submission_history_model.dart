import 'dart:convert';

class SubmissionHistoryEntry {
  final String songTitle;
  final String artistName;
  final DateTime submittedAt;

  SubmissionHistoryEntry({
    required this.songTitle,
    required this.artistName,
    required this.submittedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'songTitle': songTitle,
      'artistName': artistName,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }

  factory SubmissionHistoryEntry.fromMap(Map<String, dynamic> map) {
    return SubmissionHistoryEntry(
      songTitle: map['songTitle'] ?? '',
      artistName: map['artistName'] ?? '',
      submittedAt: DateTime.parse(map['submittedAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory SubmissionHistoryEntry.fromJson(String source) => SubmissionHistoryEntry.fromMap(json.decode(source));
}