import 'dart:convert';
import 'package:nanoid/nanoid.dart';

class ServiceReminder {
  final String id;
  final String title;
  final DateTime serviceDateTime;
  final String? notes;

  ServiceReminder({
    required this.id,
    required this.title,
    required this.serviceDateTime,
    this.notes,
  });

  factory ServiceReminder.create({
    required String title,
    required DateTime serviceDateTime,
    String? notes,
  }) {
    return ServiceReminder(
      id: nanoid(),
      title: title,
      serviceDateTime: serviceDateTime,
      notes: notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'serviceDateTime': serviceDateTime.toIso8601String(),
      'notes': notes,
    };
  }

  factory ServiceReminder.fromMap(Map<String, dynamic> map) {
    return ServiceReminder(
      id: map['id'] ?? nanoid(),
      title: map['title'] ?? '',
      serviceDateTime: DateTime.parse(map['serviceDateTime']),
      notes: map['notes'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ServiceReminder.fromJson(String source) =>
      ServiceReminder.fromMap(json.decode(source));
}