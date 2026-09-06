/// Canonical admin + user vocal-plan IDs and curriculum lengths.
class VocalPlanCatalog {
  VocalPlanCatalog._();

  static const List<String> planIds = [
    'male_daily',
    'female_daily',
    'male_weekly',
    'female_weekly',
    'male_monthly',
    'female_monthly',
    'male_quarterly',
    'female_quarterly',
  ];

  static int expectedDaysFor(String planId) {
    if (planId.endsWith('_daily')) return 1;
    if (planId.endsWith('_weekly')) return 7;
    if (planId.endsWith('_monthly')) return 30;
    if (planId.endsWith('_quarterly')) return 90;
    return 0;
  }

  static bool isMale(String planId) => planId.startsWith('male_');

  static bool enforcesDayRange(String planId) => expectedDaysFor(planId) > 1;

  static int nextAvailableDay(Iterable<int> occupied, {int? maxDay}) {
    final taken = occupied.where((n) => n > 0).toSet();
    final cap = maxDay ??
        (taken.isEmpty ? 1 : (taken.reduce((a, b) => a > b ? a : b) + 1));
    for (var i = 1; i <= cap; i++) {
      if (!taken.contains(i)) return i;
    }
    return cap + 1;
  }

  static List<int> missingDays(Iterable<int> occupied, int expected) {
    if (expected <= 0) return const [];
    final taken = occupied.toSet();
    return [for (var i = 1; i <= expected; i++) if (!taken.contains(i)) i];
  }

  static List<int> duplicateDays(Iterable<int> occupied) {
    final seen = <int>{};
    final duplicates = <int>{};
    for (final n in occupied) {
      if (n <= 0) continue;
      if (!seen.add(n)) duplicates.add(n);
    }
    return duplicates.toList()..sort();
  }

  static String formatDayList(List<int> days, {int limit = 8}) {
    if (days.isEmpty) return '';
    if (days.length <= limit) return days.join(', ');
    final shown = days.take(limit).join(', ');
    return '$shown + ${days.length - limit}';
  }
}

class VocalPlanDayStats {
  const VocalPlanDayStats({
    required this.planId,
    required this.dayNumbers,
    required this.restDayCount,
  });

  final String planId;
  final List<int> dayNumbers;
  final int restDayCount;

  int get publishedCount => dayNumbers.length;

  int get uniqueDayCount => dayNumbers.toSet().length;

  int get expectedDays => VocalPlanCatalog.expectedDaysFor(planId);

  bool get isEmpty => publishedCount == 0;

  bool get isComplete =>
      expectedDays > 0 && uniqueDayCount >= expectedDays;

  List<int> get missing =>
      VocalPlanCatalog.missingDays(dayNumbers, expectedDays);

  List<int> get duplicates => VocalPlanCatalog.duplicateDays(dayNumbers);

  static VocalPlanDayStats empty(String planId) => VocalPlanDayStats(
        planId: planId,
        dayNumbers: const [],
        restDayCount: 0,
      );
}
