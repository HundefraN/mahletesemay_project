import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/models/vocal_plan_catalog.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/screens/admin/add_edit_vocal_day_screen.dart';

void main() {
  group('VocalPlanCatalog', () {
    test('maps expected curriculum lengths', () {
      expect(VocalPlanCatalog.expectedDaysFor('male_daily'), 1);
      expect(VocalPlanCatalog.expectedDaysFor('female_weekly'), 7);
      expect(VocalPlanCatalog.expectedDaysFor('male_monthly'), 30);
      expect(VocalPlanCatalog.expectedDaysFor('female_quarterly'), 90);
    });

    test('suggests the first missing day number', () {
      expect(VocalPlanCatalog.nextAvailableDay(const []), 1);
      expect(VocalPlanCatalog.nextAvailableDay(const [1, 2, 4], maxDay: 7), 3);
      expect(VocalPlanCatalog.nextAvailableDay(const [1, 2, 3], maxDay: 3), 4);
    });

    test('detects missing and duplicate days', () {
      expect(
        VocalPlanCatalog.missingDays(const [1, 2, 5], 5),
        [3, 4],
      );
      expect(
        VocalPlanCatalog.duplicateDays(const [1, 2, 2, 4, 4, 4]),
        [2, 4],
      );
    });

    test('formats long missing-day lists', () {
      expect(VocalPlanCatalog.formatDayList(const [1, 2, 3]), '1, 2, 3');
      expect(
        VocalPlanCatalog.formatDayList(List.generate(10, (i) => i + 1), limit: 3),
        '1, 2, 3 + 7',
      );
    });
  });

  group('VocalPlanDayStats', () {
    test('treats unique coverage as complete', () {
      final stats = VocalPlanDayStats(
        planId: 'male_weekly',
        dayNumbers: const [1, 2, 3, 4, 5, 6, 7],
        restDayCount: 1,
      );
      expect(stats.isComplete, isTrue);
      expect(stats.missing, isEmpty);
    });

    test('keeps daily plans complete once one unique day exists', () {
      final stats = VocalPlanDayStats(
        planId: 'female_daily',
        dayNumbers: const [1, 2],
        restDayCount: 0,
      );
      expect(stats.isComplete, isTrue);
      expect(stats.uniqueDayCount, 2);
    });
  });

  group('VocalExerciseDay writes', () {
    test('toSupabase emits snake_case plan-day columns', () {
      final day = VocalExerciseDay.fromForm(
        id: 'day_1',
        dayNumber: 3,
        title: 'Warm Up',
        description: 'Breathing exercises',
        isRestDay: false,
        audioUrl: 'https://example.com/audio.mp3',
      );

      final payload = day.toSupabase('male_weekly');
      expect(payload['plan_id'], 'male_weekly');
      expect(payload['day_number'], 3);
      expect(payload['english_title'], 'Warm Up');
      expect(payload['audio_url'], 'https://example.com/audio.mp3');
      expect(payload['is_rest_day'], isFalse);
      expect(payload['search_keywords'], isNotEmpty);
      expect(payload.containsKey('dayNumber'), isFalse);
      expect(payload.containsKey('audioUrl'), isFalse);
    });
  });

  group('vocal audio review helpers', () {
    test('prefers a newly picked file name', () {
      expect(
        vocalAudioDisplayName(
          'https://example.com/storage/v1/object/public/audio/old.mp3',
          pickedName: 'Warmup.wav',
        ),
        'Warmup.wav',
      );
    });

    test('decodes the uploaded object name from a public URL', () {
      expect(
        vocalAudioDisplayName(
          'https://example.com/storage/v1/object/public/audio/vocal-plans/Day%201%20Warmup.mp3',
        ),
        'Day 1 Warmup.mp3',
      );
    });

    test('formats upload sizes for the status indicator', () {
      expect(formatUploadBytes(512), '512 B');
      expect(formatUploadBytes(2048), '2.0 KB');
      expect(formatUploadBytes(2 * 1024 * 1024), '2.0 MB');
    });
  });
}
