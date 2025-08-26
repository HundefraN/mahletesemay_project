import 'package:cloud_firestore/cloud_firestore.dart';

class Song {
  final String id;
  final String title;
  final String artistName;
  final String artistId;
  final String albumId;
  final String albumTitle;
  final String lyrics;
  final String? scale;
  final String? rhythm;
  final int viewCount;
  final Timestamp createdAt;

  Song({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artistId,
    required this.albumId,
    required this.albumTitle,
    required this.lyrics,
    this.scale,
    this.rhythm,
    required this.viewCount,
    required this.createdAt,
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
      scale: data['scale'],
      rhythm: data['rhythm'],
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
      'rhythm': rhythm,
      'viewCount': viewCount,
      'createdAt': createdAt,
    };
  }
}