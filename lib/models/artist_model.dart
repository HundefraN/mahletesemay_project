import 'package:cloud_firestore/cloud_firestore.dart';

class Artist {
  final String id;
  final String name;
  final String imageUrl;
  final String region;

  Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.region,
  });

  factory Artist.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Artist(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      region: data['region'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'region': region,
    };
  }
}