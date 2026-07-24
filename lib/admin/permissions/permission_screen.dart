import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/screens/onboarding/onboarding_screen.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:mahlete_semay_project/utils/permission_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      icon: Icons.notifications_active_outlined,
      title: 'Enable Notifications',
      description: 'Get friendly reminders for your daily vocal workouts to stay on track with your training.',
    ),
    _PermissionInfo(
      permission: Permission.microphone,
      icon: Icons.mic_none_rounded,
      title: 'Microphone Access',
      description: 'Needed for the Vocal Range Finder to analyze your pitch and help you discover your voice type.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() => setState(() => _currentPage = _pageController.page ?? 0));
    _bgAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
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
      bool granted = false;

      if (currentPermissionInfo.permission == Permission.microphone) {
        granted = await PermissionHelper.requestMicrophone(context);
      } else if (currentPermissionInfo.permission == Permission.notification) {
        granted = await PermissionHelper.requestNotification(context);
      } else {
        granted = await currentPermissionInfo.permission.request().isGranted;
      }

      if (granted && mounted) {
        if (_currentPage.round() < _permissions.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        } else {
          await _markPermissionsAsCompleted();
        }
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

    return Scaffold(
      body: Stack(
        children: [
          _buildAnimatedBackground(theme),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _permissions.length,
                    itemBuilder: (context, index) {
                      final item = _permissions[index];
                      double pageOffset = (_currentPage - index);

                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: (1 - pageOffset.abs()).clamp(0.0, 1.0),
                            child: child,
                          );
                        },
                        child: _buildPageContent(theme, item, pageOffset),
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _buildControls(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(ThemeData theme) {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withOpacity(0.2),
                theme.colorScheme.secondary.withOpacity(0.2),
                theme.colorScheme.background,
              ],
              stops: [
                0,
                _bgAnimationController.value,
                1,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageContent(ThemeData theme, _PermissionInfo item, double pageOffset) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.translate(
            offset: Offset(0, pageOffset * -50),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.1),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 2),
              ),
              child: Icon(item.icon, size: 80, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 48),
          Transform.translate(
            offset: Offset(0, pageOffset * 50),
            child: Text(
              item.title,
              style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.headlineLarge?.color),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Transform.translate(
            offset: Offset(0, pageOffset * 70),
            child: Text(
              item.description,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, color: theme.textTheme.bodyMedium?.color),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        DotsIndicator(
          dotsCount: _permissions.length,
          position: _currentPage,
          decorator: DotsDecorator(
            activeColor: theme.colorScheme.primary,
            color: theme.colorScheme.primary.withOpacity(0.3),
            size: const Size.square(8.0),
            activeSize: const Size(20.0, 8.0),
            activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isRequestingPermission ? null : _requestCurrentPermission,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isRequestingPermission
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Allow Access', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        TextButton(
          onPressed: _isRequestingPermission ? null : _markPermissionsAsCompleted,
          child: const Text('Ask Me Later'),
        ),
        const SizedBox(height: 20),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 600.ms);
  }
}

class _PermissionInfo {
  final Permission permission;
  final IconData icon;
  final String title;
  final String description;

  _PermissionInfo({
    required this.permission,
    required this.icon,
    required this.title,
    required this.description,
  });
}