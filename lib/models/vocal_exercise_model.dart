class VocalExercise {
  final String id;
  final String title;
  final String duration;
  final String category; // 'Daily', 'Weekly', 'Monthly'
  final String description;

  VocalExercise({
    required this.id,
    required this.title,
    required this.duration,
    required this.category,
    required this.description,
  });
}