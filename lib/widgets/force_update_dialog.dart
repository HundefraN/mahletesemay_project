import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Un-dismissible, full-coverage dialog shown when the installed app version
/// is below the minimum required version set in the backend.
///
/// ┌─────────────────────────────────────────┐
/// │              🔄  Update Required        │
/// │                                         │
/// │  A newer version of Mahlete Semay is    │
/// │  available. Please update to continue.  │
/// │                                         │
/// │           [ Update Now ]                │
/// └─────────────────────────────────────────┘
///
/// • [PopScope] with `canPop: false` prevents the system back button from
///   closing the dialog (Android).
/// • `barrierDismissible: false` prevents tapping outside to close.
/// • The only escape is the **Update Now** button, which opens the correct
///   app store listing.
class ForceUpdateDialog {
  ForceUpdateDialog._();

  // ---------------------------------------------------------------------------
  // TODO: Replace these with your actual store listing URLs.
  // ---------------------------------------------------------------------------

  /// Google Play Store listing URL.
  ///
  /// Use the `market://` scheme for a direct Play Store deep-link, or fall back
  /// to the `https://play.google.com/store/apps/details?id=...` URL.
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mahletesemay.app';

  /// Apple App Store listing URL.
  ///
  /// Replace `id0000000000` with your actual App Store numeric ID.
  static const String _appStoreUrl =
      'https://apps.apple.com/app/mahlete-semay/id0000000000';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Shows the force-update dialog.
  ///
  /// Call this from the splash/initialization flow when [ForceUpdateService]
  /// reports that an update is required. The dialog cannot be dismissed — the
  /// user must tap **Update Now**.
  static Future<void> show(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Cannot tap outside to close.
      builder: (context) {
        return PopScope(
          canPop: false, // Disable Android back button.
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: colorScheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- Icon ----
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),

                // ---- Title ----
                Text(
                  l10n?.updateRequired ?? 'Update Required',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // ---- Description ----
                Text(
                  l10n?.updateRequiredDesc ??
                      'A newer version of Mahlete Semay is available. Please update to continue using the app.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ---- Update Now button ----
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _openStore(),
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    label: Text(
                      l10n?.updateNow ?? 'Update Now',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: const Text(
                      'Bypass Update (Debug Mode)',
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Opens the correct store listing based on the current platform.
  static Future<void> _openStore() async {
    final url = (!kIsWeb && Platform.isIOS) ? _appStoreUrl : _playStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
