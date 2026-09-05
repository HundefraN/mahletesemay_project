import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/app_distribution_service.dart';
import 'custom_snackbar.dart';

/// Web-only prompt to download the published Android APK onto this device.
class WebDownloadAppBanner extends StatefulWidget {
  const WebDownloadAppBanner({super.key});

  @override
  State<WebDownloadAppBanner> createState() => _WebDownloadAppBannerState();
}

class _WebDownloadAppBannerState extends State<WebDownloadAppBanner> {
  static const _prefDismissed = 'web_download_app_banner_dismissed';

  bool _visible = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _loadVisibility();
  }

  Future<void> _loadVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefDismissed) ?? false) return;

    final apkUrl = await AppDistributionService.instance.resolveApkUrl();
    if (!mounted || apkUrl == null) return;
    setState(() => _visible = true);
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDismissed, true);
    if (mounted) setState(() => _visible = false);
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await AppDistributionService.instance.downloadAndroidApp();
    } catch (_) {
      if (mounted) {
        CustomSnackbar.show(context, l10n.downloadAppUnavailable, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF12243D) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.android_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.downloadAppBannerTitle,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.downloadAppBannerBody,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _download,
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
                  foregroundColor: isDark ? const Color(0xFF0A1E3F) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  visualDensity: VisualDensity.compact,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.downloadApp, style: const TextStyle(fontSize: 12)),
              ),
              IconButton(
                tooltip: l10n.cancel,
                onPressed: _dismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
