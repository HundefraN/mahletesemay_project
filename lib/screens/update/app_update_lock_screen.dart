import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin/widgets/admin_ui_kit.dart';
import '../../models/app_config_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/app_update_service.dart';

/// Production-grade, strict non-dismissible App Lock Screen shown when a mandatory update is required.
class AppUpdateLockScreen extends StatelessWidget {
  final AppConfigModel? config;

  const AppUpdateLockScreen({
    super.key,
    this.config,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return PopScope(
      canPop: false, // Strict app lock: Android back button/gestures completely disabled
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF4F6FA),
        body: Stack(
          children: [
            // Ambient glowing background mesh
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AdminUiKit.goldAccent.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AdminUiKit.royalBlue.withValues(alpha: 0.1),
                ),
              ),
            ),

            // Main Content Area
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AnimatedBuilder(
                    animation: AppUpdateService.instance,
                    builder: (context, _) {
                      final updateService = AppUpdateService.instance;
                      final effectiveConfig = config ?? updateService.currentConfig;
                      final installedVersion = updateService.installedVersion ?? '1.0.0';
                      final latestVersion = effectiveConfig?.latestVersion ?? 'Latest';
                      final releaseNotes = effectiveConfig?.releaseNotes;
                      final apkUrl = effectiveConfig?.apkUrl;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Hero Animated Icon Beacon
                            Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          AdminUiKit.goldAccent.withValues(alpha: 0.25),
                                          AdminUiKit.royalBlue.withValues(alpha: 0.15),
                                        ],
                                      ),
                                    ),
                                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                                        begin: 0.95,
                                        end: 1.12,
                                        duration: 1600.ms,
                                      ),
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF0A1E3F), Color(0xFF132A52)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AdminUiKit.goldAccent.withValues(alpha: 0.35),
                                          blurRadius: 18,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.system_update_rounded,
                                        color: AdminUiKit.goldAccent,
                                        size: 38,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 2. Title & Mandatory Tag
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AdminUiKit.roseRed.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AdminUiKit.roseRed.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'MANDATORY UPDATE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AdminUiKit.roseRed,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Update Required',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A newer version of Mahlete Semay is required to ensure optimal performance and security.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                color: isDark ? Colors.white70 : Colors.black54,
                                height: 1.45,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),

                            // 3. Version Comparison Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        'INSTALLED',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'v$installedVersion',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white60 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: AdminUiKit.goldAccent.withValues(alpha: 0.8),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        'NEW RELEASE',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AdminUiKit.emeraldGreen,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'v$latestVersion',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AdminUiKit.emeraldGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // 4. Release Notes Box
                            if (releaseNotes != null && releaseNotes.trim().isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F1D33) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AdminUiKit.goldAccent.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.notes_rounded,
                                          size: 16,
                                          color: AdminUiKit.goldAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "What's New in This Release",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxHeight: 110),
                                      child: SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        child: Text(
                                          releaseNotes.trim(),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // 5. Error Banner (if any)
                            if (updateService.errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AdminUiKit.roseRed.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AdminUiKit.roseRed.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: AdminUiKit.roseRed,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        updateService.errorMessage!,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AdminUiKit.roseRed,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 6. Action Panel: Download / Progress / Install
                            _buildActionSection(context, updateService, apkUrl, isDark),

                            // 7. Developer & Admin Session Bypass
                            if (kDebugMode || authProvider.isAdmin) ...[
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
                                  onPressed: () {
                                    updateService.bypassForAdminOrDebug();
                                  },
                                  label: Text(
                                    'Bypass App Lock (Admin / Debug)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AdminUiKit.amberOrange,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context,
    AppUpdateService updateService,
    String? apkUrl,
    bool isDark,
  ) {
    // A. Downloading State with Live Progress Bar
    if (updateService.isDownloading) {
      final percent = (updateService.downloadProgress * 100).toStringAsFixed(1);
      final downloadedMb = (updateService.downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
      final totalMb = updateService.totalBytes > 0
          ? (updateService.totalBytes / (1024 * 1024)).toStringAsFixed(1)
          : '--';

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1D33) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AdminUiKit.royalBlue.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloading update...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                  ),
                ),
                Text(
                  '$percent%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AdminUiKit.royalBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: updateService.downloadProgress > 0 ? updateService.downloadProgress : null,
                minHeight: 10,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: const AlwaysStoppedAnimation<Color>(AdminUiKit.royalBlue),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$downloadedMb MB of $totalMb MB',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                GestureDetector(
                  onTap: () => updateService.cancelDownload(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminUiKit.roseRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // B. Permission Required on Android (Install unknown apps)
    if (updateService.installPermissionRequired) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminUiKit.amberOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AdminUiKit.amberOrange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_update_warning_rounded, color: AdminUiKit.amberOrange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Android requires permission to install APK packages directly. Tap below to enable.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AdminUiKit.amberOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () => updateService.openInstallSettings(),
              icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 20),
              label: Text(
                'Allow "Install Unknown Apps"',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => updateService.triggerApkInstallation(),
            child: Text(
              'I have granted permission • Try Installing',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AdminUiKit.royalBlue,
              ),
            ),
          ),
        ],
      );
    }

    // C. Download Complete / Ready to Install
    if (updateService.downloadedApkPath != null) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AdminUiKit.emeraldGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              onPressed: () => updateService.triggerApkInstallation(),
              icon: const Icon(Icons.download_done_rounded, color: Colors.white, size: 22),
              label: Text(
                'Install Update Now',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            onPressed: () => updateService.downloadAndInstallApk(apkUrl: apkUrl),
            label: Text(
              'Re-download APK',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      );
    }

    // D. Initial State: "Update Now" Action Button
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.royalBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              shadowColor: AdminUiKit.royalBlue.withValues(alpha: 0.4),
            ),
            onPressed: () => updateService.downloadAndInstallApk(apkUrl: apkUrl),
            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
            label: Text(
              'Update Now',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // Web or Direct Browser Download Fallback
        if (apkUrl != null && apkUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.black12,
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final uri = Uri.tryParse(apkUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_browser_rounded, size: 18),
            label: Text(
              'Download APK via Browser',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
