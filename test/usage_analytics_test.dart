import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/models/usage_stats_model.dart';
import 'package:mahlete_semay_project/services/usage_analytics_service.dart';

void main() {
  test('UsageStats.fromMap parses compact and string counts', () {
    final stats = UsageStats.fromMap({
      'app_installs': 12,
      'website_visitors': '7',
      'website_visits': 15.0,
      'app_opens': null,
      'installs_today': 2,
      'visitors_today': 3,
      'last_7_days': [
        {'day': '2026-09-01', 'app_installs': 1, 'website_visits': '4'},
        {'day': '2026-09-02', 'app_installs': 0, 'website_visits': 2},
      ],
    });

    expect(stats.appInstalls, 12);
    expect(stats.websiteVisitors, 7);
    expect(stats.websiteVisits, 15);
    expect(stats.appOpens, 0);
    expect(stats.installsToday, 2);
    expect(stats.visitorsToday, 3);
    expect(stats.hasAudience, isTrue);
    expect(stats.last7Days, hasLength(2));
    expect(stats.last7Days.first.appInstalls, 1);
    expect(stats.last7Days.first.websiteVisits, 4);
    expect(stats.last7Days.first.day.year, 2026);
    expect(stats.last7Days.first.day.month, 9);
    expect(stats.last7Days.first.day.day, 1);
  });

  test('UsageAnalyticsService classifies web vs app channels', () {
    expect(UsageAnalyticsService.resolveChannel(isWeb: true), 'web');
    expect(UsageAnalyticsService.resolveChannel(isWeb: false), 'app');
    expect(
      UsageAnalyticsService.resolvePlatform(isWeb: true),
      'web',
    );
    expect(
      UsageAnalyticsService.resolvePlatform(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      'android',
    );
    expect(
      UsageAnalyticsService.resolvePlatform(
        isWeb: false,
        platform: TargetPlatform.iOS,
      ),
      'ios',
    );
  });

  test('utcDayKey is a stable YYYY-MM-DD stamp', () {
    expect(
      UsageAnalyticsService.utcDayKey(DateTime.utc(2026, 9, 6, 23, 15)),
      '2026-09-06',
    );
  });
}
