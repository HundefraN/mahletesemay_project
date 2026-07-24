import 'package:flutter/material.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mahlete_semay_project/screens/home_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingInfo {
  final String title;
  final String description;
  final IconData icon;
  _OnboardingInfo(this.title, this.description, this.icon);
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  double _currentPage = 0;

  late final AnimationController _bgAnimationController;

  final List<_OnboardingInfo> _pages = [
    _OnboardingInfo(
      'Welcome to Your Vocal Companion',
      'Everything you need to grow as a worship singer, all in one place.',
      Icons.music_note_rounded,
    ),
    _OnboardingInfo(
      'Find Any Lyric',
      'Access a vast, searchable library of song lyrics, complete with artist and album details.',
      Icons.text_fields_rounded,
    ),
    _OnboardingInfo(
      'Train Your Voice',
      'Follow structured daily, weekly, and monthly vocal exercise plans to improve your skills.',
      Icons.fitness_center_rounded,
    ),
    _OnboardingInfo(
      'Master the Stage',
      'Discover lessons, mashup ideas, and performance tips to elevate your ministry.',
      Icons.school_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgAnimationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 15))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefOnboardingCompleted, true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Scaffold(
      body: Stack(
        children: [
          _buildAnimatedBackground(theme, themeProvider.isDarkMode),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      if (mounted)
                        setState(() => _currentPage = index.toDouble());
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      double pageOffset = (_currentPage - index);

                      return _buildPageContent(theme, page, pageOffset);
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

  Widget _buildAnimatedBackground(ThemeData theme, bool isDarkMode) {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                      theme.colorScheme.background,
                      theme.colorScheme.primary.withOpacity(0.2)
                    ]
                  : [
                      theme.colorScheme.primary.withOpacity(0.1),
                      theme.colorScheme.background
                    ],
              stops: [
                _bgAnimationController.value,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageContent(
      ThemeData theme, _OnboardingInfo item, double pageOffset) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, pageOffset * -30),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 2),
                ),
                child:
                    Icon(item.icon, size: 72, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 32),
            Transform.translate(
              offset: Offset(0, pageOffset * 30),
              child: Text(
                item.title,
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.headlineLarge?.color),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Transform.translate(
              offset: Offset(0, pageOffset * 40),
              child: Text(
                item.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.5, color: theme.textTheme.bodyMedium?.color),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    final isLastPage = _currentPage.round() == _pages.length - 1;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        DotsIndicator(
          dotsCount: _pages.length,
          position: _currentPage,
          decorator: DotsDecorator(
            activeColor: theme.colorScheme.primary,
            color: theme.colorScheme.primary.withOpacity(0.3),
            size: const Size.square(8.0),
            activeSize: const Size(20.0, 8.0),
            activeShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0)),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLastPage
                  ? _completeOnboarding
                  : () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(isLastPage ? "Get Started" : "Next",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        SizedBox(height: isLastPage ? 60 : 20),
        if (!isLastPage)
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text('Skip'),
          ),
        if (!isLastPage) const SizedBox(height: 20),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 600.ms);
  }
}
