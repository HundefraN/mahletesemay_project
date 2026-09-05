import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'supabase_service.dart';

/// Result of the force-update version check.
///
/// [updateRequired]      — `true` when the installed version is strictly lower
///                         than the minimum version required by the backend.
/// [installedVersion]    — the local version string read from the platform.
/// [minRequiredVersion]  — the minimum required version string from backend.
class ForceUpdateResult {
  final bool updateRequired;
  final String? installedVersion;
  final String? minRequiredVersion;

  const ForceUpdateResult({
    required this.updateRequired,
    this.installedVersion,
    this.minRequiredVersion,
  });
}

/// Encapsulates the force-update logic:
///
/// 1. Reads the installed app version via `package_info_plus`.
/// 2. Fetches the `min_required_version` from Supabase (`app_settings` table).
/// 3. Safely sanitizes and compares both using `pub_semver`.
///
/// Call [checkForUpdate] once during app initialization (e.g. in the splash
/// screen) before navigating to the main content.
class ForceUpdateService {
  ForceUpdateService._();
  static final ForceUpdateService instance = ForceUpdateService._();

  /// Normalizes a version string so that pub_semver can parse it reliably.
  /// Handles "v1.0.0", "1.0", "1.0.0.1", "1.0.0+1", whitespace, etc.
  static Version? parseVersion(String? raw) {
    if (raw == null) return null;
    var v = raw.trim();
    if (v.isEmpty ||
        v.toLowerCase() == 'none' ||
        v.toLowerCase() == 'disabled' ||
        v == '0.0.0') {
      return null;
    }
    // Remove leading 'v' or 'V'
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1).trim();
    }

    try {
      return Version.parse(v);
    } catch (_) {
      // Fallback normalization: extract major.minor.patch
      try {
        final regExp = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?');
        final match = regExp.firstMatch(v);
        if (match != null) {
          final major = int.tryParse(match.group(1) ?? '0') ?? 0;
          final minor = int.tryParse(match.group(2) ?? '0') ?? 0;
          final patch = int.tryParse(match.group(3) ?? '0') ?? 0;
          return Version(major, minor, patch);
        }
      } catch (_) {}
      return null;
    }
  }

  /// Reads the `+build` suffix from a version string such as `1.0.2+4`.
  static int? parseBuildNumber(String? raw, {String? fallback}) {
    if (raw != null) {
      final plus = raw.trim().split('+');
      if (plus.length > 1) {
        final fromString = int.tryParse(plus.last.trim());
        if (fromString != null) return fromString;
      }
      final parsed = parseVersion(raw);
      if (parsed != null && parsed.build.isNotEmpty) {
        final first = parsed.build.first;
        if (first is int) return first;
        final fromBuild = int.tryParse(first.toString());
        if (fromBuild != null) return fromBuild;
      }
    }
    if (fallback != null && fallback.trim().isNotEmpty) {
      return int.tryParse(fallback.trim());
    }
    return null;
  }

  /// Compares two versions, using Android `versionCode` / pubspec `+build`
  /// when the marketing versions are equal.
  static int compareVersions({
    required Version left,
    int? leftBuild,
    required Version right,
    int? rightBuild,
  }) {
    final semver = left.compareTo(right);
    if (semver != 0) return semver;
    return (leftBuild ?? 0).compareTo(rightBuild ?? 0);
  }

  /// Single source of truth for the lock screen.
  ///
  /// A user who is already on [latestVersion] (or newer) is never locked,
  /// even if `force_update` is still enabled in admin.
  static bool isUpdateRequired({
    required String? installedVersion,
    String? installedBuild,
    required String? minRequiredVersion,
    required String? latestVersion,
    required bool forceUpdate,
  }) {
    final installed = parseVersion(installedVersion);
    if (installed == null) return false;

    final installedBuildNo = parseBuildNumber(
      installedVersion,
      fallback: installedBuild,
    );
    final minRequired = parseVersion(minRequiredVersion);
    final minBuild = parseBuildNumber(minRequiredVersion);
    final latest = parseVersion(latestVersion);
    final latestBuild = parseBuildNumber(latestVersion);

    if (minRequired != null &&
        compareVersions(
              left: installed,
              leftBuild: installedBuildNo,
              right: minRequired,
              rightBuild: minBuild,
            ) <
            0) {
      return true;
    }

    // Force update only locks devices that are still behind the published latest.
    if (forceUpdate && latest != null) {
      return compareVersions(
            left: installed,
            leftBuild: installedBuildNo,
            right: latest,
            rightBuild: latestBuild,
          ) <
          0;
    }

    return false;
  }

  /// Performs the version comparison.
  ///
  /// Returns [ForceUpdateResult.updateRequired] == `false` when:
  /// - The backend column is missing, null, or disabled (graceful degradation).
  /// - The version strings cannot be parsed.
  /// - The installed version is greater than or equal to the minimum / latest.
  Future<ForceUpdateResult> checkForUpdate() async {
    if (kIsWeb) {
      return const ForceUpdateResult(updateRequired: false);
    }
    try {
      // 1. Fetch release config from the backend.
      final config = await SupabaseService().getAppConfig();
      final minVersionString = config?.minRequiredVersion ?? await SupabaseService().getMinRequiredVersion();
      final latestVersionString = config?.latestVersion;

      if (config == null && (minVersionString == null || minVersionString.trim().isEmpty)) {
        return const ForceUpdateResult(updateRequired: false);
      }

      // 2. Read the installed app version from the native platform.
      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersionString = packageInfo.version;
      final installedDisplay = packageInfo.buildNumber.isNotEmpty
          ? '${packageInfo.version}+${packageInfo.buildNumber}'
          : packageInfo.version;

      final needsUpdate = isUpdateRequired(
        installedVersion: installedVersionString,
        installedBuild: packageInfo.buildNumber,
        minRequiredVersion: minVersionString,
        latestVersion: latestVersionString,
        forceUpdate: config?.forceUpdate ?? false,
      );

      debugPrint(
        '[ForceUpdate] Version check: installed=$installedDisplay, '
        'min_required=$minVersionString, latest=$latestVersionString, '
        'force=${config?.forceUpdate} -> needsUpdate=$needsUpdate',
      );

      return ForceUpdateResult(
        updateRequired: needsUpdate,
        installedVersion: installedDisplay,
        minRequiredVersion: minVersionString,
      );
    } catch (e, st) {
      // Never block the user because of an unexpected network or parsing error.
      debugPrint('[ForceUpdate] checkForUpdate error: $e\n$st');
      return const ForceUpdateResult(updateRequired: false);
    }
  }
}
