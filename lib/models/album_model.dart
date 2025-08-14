import 'package:cloud_firestore/cloud_firestore.dart';

class Album {
  final String id;
  final String title;
  final String artistId;
  final String artistName;
  final String coverImageUrl;
  final int year;

  Album({
    required this.id,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.coverImageUrl,
    required this.year,
  });

  factory Album.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Album(
      id: doc.id,
      title: data['title'] ?? '',
      artistId: data['artistId'] ?? '',
      artistName: data['artistName'] ?? '',
      coverImageUrl: data['coverImageUrl'] ?? '',
      year: data['year'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artistId': artistId,
      'artistName': artistName,
      'coverImageUrl': coverImageUrl,
      'year': year,
    };
  }
}