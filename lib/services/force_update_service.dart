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
  ///
  /// `flutter build apk --split-per-abi` rewrites Android versionCode to
  /// `abiIndex * 1000 + pubspecBuild` (armeabi-v7a → 1005 for `+5`).
  static int? parseBuildNumber(String? raw, {String? fallback}) {
    int? parsed;
    if (raw != null) {
      final plus = raw.trim().split('+');
      if (plus.length > 1) {
        parsed = int.tryParse(plus.last.trim());
      }
      if (parsed == null) {
        final version = parseVersion(raw);
        if (version != null && version.build.isNotEmpty) {
          final first = version.build.first;
          parsed = first is int ? first : int.tryParse(first.toString());
        }
      }
    }
    parsed ??= (fallback != null && fallback.trim().isNotEmpty)
        ? int.tryParse(fallback.trim())
        : null;
    return _normalizeSplitAbiBuild(parsed);
  }

  /// Strips the ABI prefix Flutter adds for split APKs (1xxx / 2xxx / 4xxx).
  static int? _normalizeSplitAbiBuild(int? build) {
    if (build == null) return null;
    final abiIndex = build ~/ 1000;
    if (abiIndex == 1 || abiIndex == 2 || abiIndex == 3 || abiIndex == 4) {
      return build % 1000;
    }
    return build;
  }

  /// Compares two versions, using Android `versionCode` / pubspec `+build`
  /// when the marketing versions are equal.
  ///
  /// pub_semver treats `1.0.5` as older than `1.0.5+7`. The app often parses
  /// those separately (`version` + `buildNumber`), so build must not decide
  /// the marketing comparison.
  static int compareVersions({
    required Version left,
    int? leftBuild,
    required Version right,
    int? rightBuild,
  }) {
    final marketing = Version(
      left.major,
      left.minor,
      left.patch,
      pre: left.preRelease.isEmpty ? null : left.preRelease.join('.'),
    ).compareTo(
      Version(
        right.major,
        right.minor,
        right.patch,
        pre: right.preRelease.isEmpty ? null : right.preRelease.join('.'),
      ),
    );
    if (marketing != 0) return marketing;
    return (leftBuild ?? 0).compareTo(rightBuild ?? 0);
  }

  static bool _isSameMarketingVersion(Version left, Version right) {
    return left.major == right.major &&
        left.minor == right.minor &&
        left.patch == right.patch &&
        listEquals(left.preRelease, right.preRelease);
  }

  /// True when [installedVersion] is the same release or newer than [targetVersion].
  ///
  /// Same `major.minor.patch` with a missing `+build` on either side is treated
  /// as current. Admin fields and PackageInfo often disagree on build after
  /// an APK install, which previously left updated users stuck on the lock.
  static bool isInstalledAtLeast({
    required String? installedVersion,
    String? installedBuild,
    required String? targetVersion,
  }) {
    final installed = parseVersion(installedVersion);
    final target = parseVersion(targetVersion);
    if (installed == null || target == null) return false;

    final leftBuild = parseBuildNumber(
      installedVersion,
      fallback: installedBuild,
    );
    final rightBuild = parseBuildNumber(targetVersion);

    if (compareVersions(
          left: installed,
          leftBuild: leftBuild,
          right: target,
          rightBuild: rightBuild,
        ) >=
        0) {
      return true;
    }

    if (_isSameMarketingVersion(installed, target) &&
        ((leftBuild ?? 0) == 0 || (rightBuild ?? 0) == 0)) {
      return true;
    }

    return false;
  }

  /// Formats a version for UI (`v1.0.6+8`) without stacking extra `v` prefixes.
  static String formatDisplay(String? raw, {String fallback = '—'}) {
    final canonical = formatCanonical(raw);
    if (canonical.isEmpty) return fallback;
    return 'v$canonical';
  }

  /// `1.0.6+8` with ABI prefixes stripped and a leading `v` removed.
  static String formatCanonical(String? raw, {String? build}) {
    final parsed = parseVersion(raw);
    if (parsed == null) {
      return (raw ?? '').trim().replaceFirst(RegExp(r'^[vV]'), '');
    }
    final normalizedBuild = parseBuildNumber(raw, fallback: build);
    if (normalizedBuild != null && normalizedBuild > 0) {
      return '${parsed.major}.${parsed.minor}.${parsed.patch}+$normalizedBuild';
    }
    return '${parsed.major}.${parsed.minor}.${parsed.patch}';
  }

  /// Returns the newer of [a] and [b]. Empty / unparsable values lose.
  static String? selectNewerVersion(String? a, String? b) {
    final left = (a ?? '').trim();
    final right = (b ?? '').trim();
    if (left.isEmpty) return right.isEmpty ? null : right;
    if (right.isEmpty) return left;
    if (isInstalledAtLeast(installedVersion: left, targetVersion: right)) {
      return formatCanonical(left);
    }
    return formatCanonical(right);
  }

  /// Identity of the running binary: the newer of compile-time pubspec
  /// version and what Android PackageManager reports.
  ///
  /// Sideloaded / split APKs often keep a stale `versionName` (e.g. `1.0.3+5`)
  /// even after the 1.0.6 code is what is executing. The compiled constant
  /// must win in that case or the lock screen never clears.
  static String resolveRunningVersion({
    required String compileTimeVersion,
    String? compileTimeBuild,
    String? platformVersion,
    String? platformBuild,
  }) {
    final compiled = formatCanonical(
      compileTimeVersion,
      build: compileTimeBuild,
    );
    final platform = formatCanonical(
      platformVersion,
      build: platformBuild,
    );
    return selectNewerVersion(compiled, platform) ?? compiled;
  }

  /// Single source of truth for the lock screen.
  ///
  /// A user who is already on [latestVersion] (or newer) is never locked,
  /// even if `min_required_version` is higher or `force_update` is still on.
  static bool isUpdateRequired({
    required String? installedVersion,
    String? installedBuild,
    required String? minRequiredVersion,
    required String? latestVersion,
    required bool forceUpdate,
  }) {
    final installed = parseVersion(installedVersion);
    if (installed == null) return false;

    // Already on the published latest → never lock.
    if (isInstalledAtLeast(
      installedVersion: installedVersion,
      installedBuild: installedBuild,
      targetVersion: latestVersion,
    )) {
      return false;
    }

    if (!isInstalledAtLeast(
          installedVersion: installedVersion,
          installedBuild: installedBuild,
          targetVersion: minRequiredVersion,
        ) &&
        parseVersion(minRequiredVersion) != null) {
      return true;
    }

    // Force update only locks devices that are still behind the published latest.
    return forceUpdate && parseVersion(latestVersion) != null;
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
        installedVersion: installedDisplay,
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
