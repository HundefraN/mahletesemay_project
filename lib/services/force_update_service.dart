import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'supabase_service.dart';

/// Result of the force-update version check.
///
/// [updateRequired] — `true` when the installed version is strictly lower than
///                     the minimum version stored in the backend.
/// [storeUrl]       — the platform-appropriate store listing URL (only
///                     meaningful when [updateRequired] is `true`).
class ForceUpdateResult {
  final bool updateRequired;

  const ForceUpdateResult({required this.updateRequired});
}

/// Encapsulates the force-update logic:
///
/// 1. Reads the installed app version via `package_info_plus`.
/// 2. Fetches the `min_required_version` from Supabase (`app_settings` table).
/// 3. Compares both using `pub_semver`.
///
/// Call [checkForUpdate] once during app initialization (e.g. in the splash
/// screen) before navigating to the main content.
class ForceUpdateService {
  ForceUpdateService._();
  static final ForceUpdateService instance = ForceUpdateService._();

  /// Performs the version comparison.
  ///
  /// Returns [ForceUpdateResult.updateRequired] == `false` when:
  /// - The backend column is missing or null (graceful degradation).
  /// - The version strings cannot be parsed.
  /// - The installed version is greater than or equal to the minimum.
  Future<ForceUpdateResult> checkForUpdate() async {
    try {
      // 1. Fetch the minimum required version from the backend.
      final minVersionString =
          await SupabaseService().getMinRequiredVersion();

      if (minVersionString == null || minVersionString.trim().isEmpty) {
        // No remote config set — allow the app to run.
        return const ForceUpdateResult(updateRequired: false);
      }

      // 2. Read the installed app version from the native platform.
      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersionString = packageInfo.version; // e.g. "1.0.0"

      // 3. Parse both using pub_semver for proper semantic comparison.
      final installedVersion = Version.parse(installedVersionString);
      final minRequiredVersion = Version.parse(minVersionString.trim());

      // 4. If installed < minimum → force update.
      final needsUpdate = installedVersion < minRequiredVersion;

      if (needsUpdate) {
        debugPrint(
          'Force update required: installed=$installedVersion, '
          'min_required=$minRequiredVersion',
        );
      }

      return ForceUpdateResult(updateRequired: needsUpdate);
    } catch (e, st) {
      // Never block the user because of a parsing/network error.
      debugPrint('ForceUpdateService.checkForUpdate error: $e\n$st');
      return const ForceUpdateResult(updateRequired: false);
    }
  }
}
