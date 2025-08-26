import 'package:cloud_firestore/cloud_firestore.dart';

class VocalExerciseDay {
  final String id;
  final int dayNumber;
  final String title;
  final String description;
  final String? audioUrl;
  final bool isRestDay;

  VocalExerciseDay({
    required this.id,
    required this.dayNumber,
    required this.title,
    required this.description,
    this.audioUrl,
    this.isRestDay = false,
  });

  factory VocalExerciseDay.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return VocalExerciseDay(
      id: doc.id,
      dayNumber: data['dayNumber'] ?? 0,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      audioUrl: data['audioUrl'],
      isRestDay: data['isRestDay'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayNumber': dayNumber,
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'isRestDay': isRestDay,
    };
  }
}