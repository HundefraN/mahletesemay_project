import 'package:flutter/foundation.dart';
import 'package:nanoid/nanoid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_version.dart';
import '../models/usage_stats_model.dart';

/// Anonymous install / website-visit tracking.
///
/// Mobile first-open creates one `app` device. Flutter web first-open creates
/// one `web` visitor. Repeat opens increment daily visit totals at most once
/// per UTC day.
class UsageAnalyticsService {
  UsageAnalyticsService._();
  static final UsageAnalyticsService instance = UsageAnalyticsService._();

  static const prefDeviceId = 'usage_anonymous_device_id';
  static const prefLastPingDay = 'usage_last_ping_utc_day';

  static String utcDayKey([DateTime? now]) {
    final day = (now ?? DateTime.now()).toUtc();
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  static String resolveChannel({required bool isWeb}) => isWeb ? 'web' : 'app';

  static String resolvePlatform({
    required bool isWeb,
    TargetPlatform? platform,
  }) {
    if (isWeb) return 'web';
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> recordVisit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = utcDayKey();
      if (prefs.getString(prefLastPingDay) == today) return;

      final deviceId = await _deviceId(prefs);
      await Supabase.instance.client.rpc(
        'record_usage_ping',
        params: {
          'p_device_id': deviceId,
          'p_channel': resolveChannel(isWeb: kIsWeb),
          'p_platform': resolvePlatform(isWeb: kIsWeb),
          'p_app_version': AppVersion.full,
        },
      );
      await prefs.setString(prefLastPingDay, today);
    } catch (e) {
      debugPrint('[UsageAnalytics] recordVisit failed: $e');
    }
  }

  Future<UsageStats> fetchStats() async {
    final response = await Supabase.instance.client.rpc('get_usage_stats');
    if (response is Map<String, dynamic>) {
      return UsageStats.fromMap(response);
    }
    if (response is Map) {
      return UsageStats.fromMap(Map<String, dynamic>.from(response));
    }
    return UsageStats.empty();
  }

  Future<String> _deviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(prefDeviceId);
    if (existing != null && existing.length >= 8) return existing;
    final created = nanoid();
    await prefs.setString(prefDeviceId, created);
    return created;
  }
}
