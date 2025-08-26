import 'package:flutter/material.dart';

class Lesson {
  final String id;
  final String title;
  final String description;
  final String category;
  final String instructor;
  final String duration;
  final String level;
  final String imageUrl;
  final bool isFeatured;
  final double rating;
  final int reviewCount;
  final int viewCount;
  final List<String> tags;
  final String videoId;
  final DateTime? publishedDate;

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.instructor,
    required this.duration,
    required this.level,
    required this.imageUrl,
    this.isFeatured = false,
    required this.rating,
    required this.reviewCount,
    required this.viewCount,
    required this.tags,
    required this.videoId,
    this.publishedDate,
  });
}

class Category {
  final String id;
  final String name;
  final IconData icon;
  Category({required this.id, required this.name, required this.icon});
}

class ISO8601Duration {
  final int hours;
  final int minutes;
  final int seconds;

  ISO8601Duration({
    this.hours = 0, this.minutes = 0, this.seconds = 0,
  });

  factory ISO8601Duration.parse(String isoDuration) {
    final regex = RegExp(r'P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?');
    final match = regex.firstMatch(isoDuration);

    if (match == null) {
      throw FormatException("Invalid ISO 8601 duration format", isoDuration);
    }

    int totalSeconds = 0;
    totalSeconds += (int.tryParse(match.group(5) ?? '0') ?? 0) * 3600;
    totalSeconds += (int.tryParse(match.group(6) ?? '0') ?? 0) * 60;
    totalSeconds += (int.tryParse(match.group(7) ?? '0') ?? 0);

    return ISO8601Duration(
      hours: totalSeconds ~/ 3600,
      minutes: (totalSeconds % 3600) ~/ 60,
      seconds: totalSeconds % 60,
    );
  }
}