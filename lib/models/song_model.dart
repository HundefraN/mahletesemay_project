import 'package:cloud_firestore/cloud_firestore.dart';

class Song {
  final String id;
  final String title;
  final String artistName;
  final String artistId;
  final String albumId;
  final String albumTitle;
  final String lyrics;
  final String scale;
  final int scaleDegree;
  final int viewCount;
  final Timestamp createdAt;
  // bool isFavorite; <-- REMOVE THIS LINE

  Song({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artistId,
    required this.albumId,
    required this.albumTitle,
    required this.lyrics,
    required this.scale,
    required this.scaleDegree,
    required this.viewCount,
    required this.createdAt,
    // this.isFavorite = false, <-- AND REMOVE THIS LINE
  });

  factory Song.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Song(
      id: doc.id,
      title: data['title'] ?? '',
      artistName: data['artistName'] ?? '',
      artistId: data['artistId'] ?? '',
      albumId: data['albumId'] ?? '',
      albumTitle: data['albumTitle'] ?? '',
      lyrics: data['lyrics'] ?? '',
      scale: data['scale'] ?? '',
      scaleDegree: data['scaleDegree'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artistName': artistName,
      'artistId': artistId,
      'albumId': albumId,
      'albumTitle': albumTitle,
      'lyrics': lyrics,
      'scale': scale,
      'scaleDegree': scaleDegree,
      'viewCount': viewCount,
      'createdAt': createdAt,
    };
  }
}