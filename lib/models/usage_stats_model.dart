class UsageDailyPoint {
  final DateTime day;
  final int appInstalls;
  final int websiteVisits;

  const UsageDailyPoint({
    required this.day,
    required this.appInstalls,
    required this.websiteVisits,
  });

  factory UsageDailyPoint.fromMap(Map<String, dynamic> map) {
    return UsageDailyPoint(
      day: DateTime.tryParse(map['day']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      appInstalls: asUsageInt(map['app_installs']),
      websiteVisits: asUsageInt(map['website_visits']),
    );
  }
}

class UsageStats {
  final int appInstalls;
  final int websiteVisitors;
  final int websiteVisits;
  final int appOpens;
  final int installsToday;
  final int visitorsToday;
  final List<UsageDailyPoint> last7Days;

  const UsageStats({
    required this.appInstalls,
    required this.websiteVisitors,
    required this.websiteVisits,
    required this.appOpens,
    required this.installsToday,
    required this.visitorsToday,
    required this.last7Days,
  });

  factory UsageStats.empty() => const UsageStats(
        appInstalls: 0,
        websiteVisitors: 0,
        websiteVisits: 0,
        appOpens: 0,
        installsToday: 0,
        visitorsToday: 0,
        last7Days: [],
      );

  factory UsageStats.fromMap(Map<String, dynamic> map) {
    final rawDays = map['last_7_days'];
    final days = <UsageDailyPoint>[];
    if (rawDays is List) {
      for (final item in rawDays) {
        if (item is Map<String, dynamic>) {
          days.add(UsageDailyPoint.fromMap(item));
        } else if (item is Map) {
          days.add(UsageDailyPoint.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return UsageStats(
      appInstalls: asUsageInt(map['app_installs']),
      websiteVisitors: asUsageInt(map['website_visitors']),
      websiteVisits: asUsageInt(map['website_visits']),
      appOpens: asUsageInt(map['app_opens']),
      installsToday: asUsageInt(map['installs_today']),
      visitorsToday: asUsageInt(map['visitors_today']),
      last7Days: days,
    );
  }

  bool get hasAudience =>
      appInstalls > 0 || websiteVisitors > 0 || websiteVisits > 0;
}

int asUsageInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
