import 'package:cloud_firestore/cloud_firestore.dart';

enum SuggestionStatus { pending, approved, rejected }

class Suggestion {
  final String id;
  final String songTitle;
  final String artistName;
  final String lyrics;
  final String? submittedBy;
  final Timestamp submittedAt;
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

  factory Suggestion.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Suggestion(
      id: doc.id,
      songTitle: data['songTitle'] ?? '',
      artistName: data['artistName'] ?? '',
      lyrics: data['lyrics'] ?? '',
      submittedBy: data['submittedBy'],
      submittedAt: data['submittedAt'] ?? Timestamp.now(),
      status: SuggestionStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => SuggestionStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songTitle': songTitle,
      'artistName': artistName,
      'lyrics': lyrics,
      'submittedBy': submittedBy,
      'submittedAt': submittedAt,
      'status': status.name,
    };
  }
}