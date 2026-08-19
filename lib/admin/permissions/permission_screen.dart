import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/onboarding/onboarding_screen.dart';
import '../../utils/constants.dart';
import '../../utils/permission_helper.dart';
import '../widgets/admin_ui_kit.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  double _currentPage = 0;
  bool _isRequestingPermission = false;
  late final AnimationController _bgAnimationController;

  final List<_PermissionInfo> _permissions = [
    _PermissionInfo(
      permission: Permission.notification,
      icon: Icons.notifications_active_rounded,
      title: 'Enable Notifications',
      description: 'Get timely reminders for your daily vocal workouts and keep your spiritual singing practice disciplined.',
      accentColor: AdminUiKit.goldAccent,
    ),
    _PermissionInfo(
      permission: Permission.microphone,
      icon: Icons.mic_rounded,
      title: 'Microphone Access',
      description: 'Required for real-time vocal pitch detection, range finder, and chord-matching training modules.',
      accentColor: AdminUiKit.royalBlue,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() => setState(() => _currentPage = _pageController.page ?? 0));
    _bgAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  Future<void> _requestCurrentPermission() async {
    if (_isRequestingPermission) return;
    setState(() => _isRequestingPermission = true);

    try {
      final currentPermissionInfo = _permissions[_currentPage.round()];

      if (currentPermissionInfo.permission == Permission.microphone) {
        await PermissionHelper.requestMicrophone(context);
      } else if (currentPermissionInfo.permission == Permission.notification) {
        await PermissionHelper.requestNotification(context);
      } else {
        await currentPermissionInfo.permission.request();
      }

      if (!mounted) return;

      if (_currentPage.round() < _permissions.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      } else {
        await _markPermissionsAsCompleted();
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingPermission = false);
      }
    }
  }

  Future<void> _markPermissionsAsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefPermissionsCompleted, true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      body: Stack(
        children: [
          // Animated Background mesh
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AdminUiKit.primaryNavy.withOpacity(isDark ? 0.95 : 0.08),
                      AdminUiKit.goldAccent.withOpacity(0.06 * _bgAnimationController.value),
                      isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
                    ],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Indicator dots
                DotsIndicator(
                  dotsCount: _permissions.length,
                  position: _currentPage,
                  decorator: DotsDecorator(
                    activeColor: AdminUiKit.goldAccent,
                    color: AdminUiKit.goldAccent.withOpacity(0.25),
                    size: const Size.square(8.0),
                    activeSize: const Size(24.0, 8.0),
                    activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _permissions.length,
                    itemBuilder: (context, index) {
                      final item = _permissions[index];
                      return _buildPermissionSlide(item, isDark);
                    },
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      AdminPrimaryButton(
                        label: 'Grant & Continue',
                        icon: Icons.check_circle_rounded,
                        isLoading: _isRequestingPermission,
                        onPressed: _requestCurrentPermission,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _isRequestingPermission ? null : _markPermissionsAsCompleted,
                        child: Text(
                          'Configure Later in Settings',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSlide(_PermissionInfo item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.accentColor.withOpacity(0.12),
              border: Border.all(color: item.accentColor.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: item.accentColor.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(item.icon, size: 72, color: item.accentColor),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 40),
          Text(
            item.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AdminUiKit.primaryNavy,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            item.description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PermissionInfo {
  final Permission permission;
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  _PermissionInfo({
    required this.permission,
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });
}