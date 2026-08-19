import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';

void main() {
  test('Album and VocalPlan serialization sanity test', () {
    final album = Album(
      id: 'alb_1',
      title: 'Zelesegna',
      artistId: 'art_1',
      artistName: 'Mahlete Semay',
      coverImageUrl: 'https://example.com/cover.jpg',
      year: 2024,
      volume: 1,
    );

    final map = album.toSupabase();
    expect(map['title'], 'Zelesegna');
    expect(map['year'], 2024);

    final day = VocalExerciseDay(
      id: 'day_1',
      dayNumber: 1,
      title: 'Warm Up',
      description: 'Breathing exercises',
      audioUrl: 'https://example.com/audio.mp3',
      isRestDay: false,
    );

    final dayMap = day.toSupabase('male_daily');
    expect(dayMap['plan_id'], 'male_daily');
    expect(dayMap['day_number'], 1);
  });
}
