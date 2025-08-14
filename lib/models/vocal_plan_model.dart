import 'package:mahlete_semay_project/models/vocal_exercise_model.dart';

enum PlanDuration { daily, weekly, monthly, quarterly }

class VocalExerciseStep {
  final String title;
  final String description;
  final String audioAsset;
  final int durationInSeconds;

  VocalExerciseStep({
    required this.title,
    required this.description,
    required this.audioAsset,
    required this.durationInSeconds,
  });
}

class VocalExerciseRoutine {
  final String id;
  final String title;
  final String category; // e.g., 'Breathing', 'Range', 'Warm-up'
  final List<VocalExerciseStep> steps;

  VocalExerciseRoutine({
    required this.id,
    required this.title,
    required this.category,
    required this.steps,
  });
}

class VocalPlan {
  final String title;
  final PlanDuration duration;
  final List<VocalExerciseRoutine> routines;

  VocalPlan({
    required this.title,
    required this.duration,
    required this.routines,
  });
}