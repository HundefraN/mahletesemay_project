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

  /// Performs the version comparison.
  ///
  /// Returns [ForceUpdateResult.updateRequired] == `false` when:
  /// - The backend column is missing, null, or disabled (graceful degradation).
  /// - The version strings cannot be parsed.
  /// - The installed version is greater than or equal to the minimum.
  Future<ForceUpdateResult> checkForUpdate() async {
    if (kIsWeb) {
      return const ForceUpdateResult(updateRequired: false);
    }
    try {
      // 1. Fetch the minimum required version from the backend.
      final minVersionString = await SupabaseService().getMinRequiredVersion();

      if (minVersionString == null || minVersionString.trim().isEmpty) {
        // No remote config set or explicitly empty — allow the app to run.
        return const ForceUpdateResult(updateRequired: false);
      }

      final minRequiredVersion = parseVersion(minVersionString);
      if (minRequiredVersion == null) {
        debugPrint(
          '[ForceUpdate] Min required version is disabled or invalid: $minVersionString',
        );
        return const ForceUpdateResult(updateRequired: false);
      }

      // 2. Read the installed app version from the native platform.
      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersionString = packageInfo.version; // e.g. "1.0.0"
      final installedVersion = parseVersion(installedVersionString);

      if (installedVersion == null) {
        debugPrint(
          '[ForceUpdate] Could not parse installed version: $installedVersionString',
        );
        return const ForceUpdateResult(updateRequired: false);
      }

      // 3. If installed < minimum → force update.
      final needsUpdate = installedVersion < minRequiredVersion;

      debugPrint(
        '[ForceUpdate] Version check: installed=$installedVersion (raw: $installedVersionString), '
        'min_required=$minRequiredVersion (raw: $minVersionString), needsUpdate=$needsUpdate',
      );

      return ForceUpdateResult(
        updateRequired: needsUpdate,
        installedVersion: installedVersionString,
        minRequiredVersion: minVersionString,
      );
    } catch (e, st) {
      // Never block the user because of an unexpected network or parsing error.
      debugPrint('[ForceUpdate] checkForUpdate error: $e\n$st');
      return const ForceUpdateResult(updateRequired: false);
    }
  }
}
