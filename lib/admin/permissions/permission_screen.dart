import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../utils/constants.dart';
import '../../utils/permission_helper.dart';
import '../widgets/admin_ui_kit.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _bgAnimationController;
  bool _isMicGranted = false;
  bool _isNotifGranted = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _checkPermissionStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatuses();
    }
  }

  Future<void> _checkPermissionStatuses() async {
    final micStatus = await Permission.microphone.status;
    final notifStatus = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _isMicGranted = micStatus.isGranted;
        _isNotifGranted = notifStatus.isGranted;
      });
    }
  }

  Future<void> _requestMicrophone() async {
    if (_isMicGranted) return;
    await PermissionHelper.requestMicrophone(context);
    await _checkPermissionStatuses();
  }

  Future<void> _requestNotification() async {
    if (_isNotifGranted) return;
    await PermissionHelper.requestNotification(context);
    await _checkPermissionStatuses();
  }

  Future<void> _grantAllAndProceed() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    try {
      if (!_isMicGranted) {
        await PermissionHelper.requestMicrophone(context);
      }
      if (!_isNotifGranted && mounted) {
        await PermissionHelper.requestNotification(context);
      }
      await _checkPermissionStatuses();
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
        await _completePermissions();
      }
    }
  }

  Future<void> _completePermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefPermissionsCompleted, true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      body: Stack(
        children: [
          // ── Animated Ambient Mesh Background ──────────────────────────────
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF0A1E3F),
                            const Color(0xFF0F172A).withValues(alpha: 0.85),
                            const Color(0xFF070E1B),
                          ]
                        : [
                            const Color(0xFFE8EEF9),
                            const Color(0xFFF0F4FC),
                            const Color(0xFFF5F7FB),
                          ],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                children: [
                  const SizedBox(height: 16),

                  // ── Top Security / Trust Badge ────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminUiKit.goldAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AdminUiKit.goldAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 16,
                          color: AdminUiKit.goldAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n?.onDeviceProcessingOnly ??
                              '100% On-Device Processing',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AdminUiKit.goldAccent,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

                  const SizedBox(height: 16),

                  // ── Title & Subtitle ──────────────────────────────────────
                  Text(
                    l10n?.appPermissionsTitle ?? 'App Permissions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                  const SizedBox(height: 8),

                  Text(
                    l10n?.permissionsSubtitle ??
                        'Enable these permissions for the best spiritual & vocal training experience.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  // ── Permission Cards ──────────────────────────────────────
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Card 1: Microphone
                        _buildPermissionCard(
                          context: context,
                          icon: Icons.mic_rounded,
                          accentColor: AdminUiKit.royalBlue,
                          title: l10n?.micPermissionTitle ?? 'Microphone Access',
                          description: l10n?.micPermissionDesc ??
                              'Required for real-time vocal pitch detection, range finder, and chord-matching training modules.',
                          isGranted: _isMicGranted,
                          isDark: isDark,
                          onAction: _requestMicrophone,
                        )
                            .animate(delay: 300.ms)
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1),

                        const SizedBox(height: 16),

                        // Card 2: Notification
                        _buildPermissionCard(
                          context: context,
                          icon: Icons.notifications_active_rounded,
                          accentColor: AdminUiKit.goldAccent,
                          title: l10n?.notifPermissionTitle ??
                              'Notification Access',
                          description: l10n?.notifPermissionDesc ??
                              'Get timely reminders for your daily vocal workouts and service alerts on schedule.',
                          isGranted: _isNotifGranted,
                          isDark: isDark,
                          onAction: _requestNotification,
                        )
                            .animate(delay: 400.ms)
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1),

                        const SizedBox(height: 20),

                        // Privacy Assurance Note
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F1D33).withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          child: Text(
                            l10n?.privacyAssurance ??
                                '🔒 Your privacy is protected. Audio is processed on-device only and never uploaded.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black54,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ).animate(delay: 500.ms).fadeIn(duration: 400.ms),
                      ],
                    ),
                  ),

                  // ── Action Buttons ────────────────────────────────────────
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AdminUiKit.goldAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor:
                                AdminUiKit.goldAccent.withValues(alpha: 0.35),
                          ),
                          onPressed: _grantAllAndProceed,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isRequesting)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              else ...[
                                Text(
                                  (_isMicGranted && _isNotifGranted)
                                      ? (l10n?.continueButton ?? 'Continue')
                                      : (l10n?.grantAndContinue ??
                                          'Grant & Continue'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 18),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _isRequesting ? null : _completePermissions,
                        child: Text(
                          l10n?.configureLater ??
                              'Configure Later in Settings',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String description,
    required bool isGranted,
    required bool isDark,
    required VoidCallback onAction,
  }) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1D33).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGranted
              ? AdminUiKit.emeraldGreen.withValues(alpha: 0.4)
              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
          width: isGranted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isGranted
                ? AdminUiKit.emeraldGreen.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                  ),
                ),
              ),
              if (isGranted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AdminUiKit.emeraldGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AdminUiKit.emeraldGreen.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AdminUiKit.emeraldGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n?.permissionGranted ?? 'Granted',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AdminUiKit.emeraldGreen,
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: accentColor, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(
                    l10n?.allowAccess ?? 'Allow Access',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}