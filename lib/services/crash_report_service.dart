import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingCrash {
  final String error;
  final String stackTrace;
  final DateTime occurredAt;

  const PendingCrash({
    required this.error,
    required this.stackTrace,
    required this.occurredAt,
  });

  Map<String, dynamic> toJson() => {
        'error': error,
        'stackTrace': stackTrace,
        'occurredAt': occurredAt.toIso8601String(),
      };

  factory PendingCrash.fromJson(Map<String, dynamic> json) {
    return PendingCrash(
      error: json['error']?.toString() ?? 'Unknown error',
      stackTrace: json['stackTrace']?.toString() ?? '',
      occurredAt: DateTime.tryParse(json['occurredAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class DeviceReportMeta {
  final String appVersion;
  final String buildNumber;
  final String platform;
  final String deviceModel;
  final String osVersion;
  final String locale;

  const DeviceReportMeta({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
    required this.locale,
  });
}

/// Persists unexpected Flutter / platform errors so the user can send them
/// after the app is relaunched.
class CrashReportService {
  static const _pendingKey = 'pending_crash_report_v1';
  static const _maxStackChars = 8000;

  static bool _installed = false;
  static bool _promptShownThisSession = false;

  static void install() {
    if (_installed) return;
    _installed = true;

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      if (previousOnError == null) {
        FlutterError.presentError(details);
      }
      final text = details.exceptionAsString();
      if (text.contains('overflowed') || text.contains('OVERFLOWING')) {
        return;
      }
      record(
        details.exception,
        details.stack,
        context: details.context?.toDescription(),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      return false;
    };
  }

  static Future<void> record(
    Object error,
    StackTrace? stack, {
    String? context,
  }) async {
    try {
      final message = [
        if (context != null && context.trim().isNotEmpty) context.trim(),
        error.toString(),
      ].join('\n');
      var stackText = stack?.toString() ?? '';
      if (stackText.length > _maxStackChars) {
        stackText = stackText.substring(0, _maxStackChars);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingKey,
        jsonEncode(
          PendingCrash(
            error: message,
            stackTrace: stackText,
            occurredAt: DateTime.now(),
          ).toJson(),
        ),
      );
    } catch (e) {
      debugPrint('CrashReportService.record failed: $e');
    }
  }

  static Future<PendingCrash?> peekPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null || raw.isEmpty) return null;
      return PendingCrash.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('CrashReportService.peekPending failed: $e');
      return null;
    }
  }

  /// Returns a pending crash once per app session so the prompt is not shown
  /// repeatedly while the user is still deciding.
  static Future<PendingCrash?> peekForSessionPrompt() async {
    if (_promptShownThisSession) return null;
    final pending = await peekPending();
    if (pending == null) return null;
    _promptShownThisSession = true;
    return pending;
  }

  static Future<void> clearPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);
    } catch (e) {
      debugPrint('CrashReportService.clearPending failed: $e');
    }
  }

  static Future<DeviceReportMeta> collectDeviceMeta() async {
    String appVersion = '';
    String buildNumber = '';
    String platform = 'unknown';
    String deviceModel = '';
    String osVersion = '';

    try {
      final package = await PackageInfo.fromPlatform();
      appVersion = package.version;
      buildNumber = package.buildNumber;
    } catch (e) {
      debugPrint('CrashReportService package info failed: $e');
    }

    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final info = await plugin.webBrowserInfo;
        platform = 'web';
        deviceModel = info.browserName.name;
        osVersion = info.platform ?? info.userAgent ?? '';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        platform = 'android';
        deviceModel = '${info.brand} ${info.model}'.trim();
        osVersion = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await plugin.iosInfo;
        platform = 'ios';
        deviceModel = info.utsname.machine;
        osVersion = 'iOS ${info.systemVersion}';
      } else {
        platform = defaultTargetPlatform.name;
      }
    } catch (e) {
      debugPrint('CrashReportService device info failed: $e');
    }

    return DeviceReportMeta(
      appVersion: appVersion,
      buildNumber: buildNumber,
      platform: platform,
      deviceModel: deviceModel,
      osVersion: osVersion,
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
    );
  }
}
