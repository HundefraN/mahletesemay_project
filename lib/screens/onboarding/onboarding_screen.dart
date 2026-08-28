import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlideData {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final String tag;

  const _OnboardingSlideData({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.tag,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  late final AnimationController _ambientAnimationController;

  @override
  void initState() {
    super.initState();
    _ambientAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientAnimationController.dispose();
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

  List<_OnboardingSlideData> _getSlides(AppLocalizations l10n) {
    return [
      _OnboardingSlideData(
        title: l10n.onboardingTitle1,
        description: l10n.onboardingDesc1,
        icon: Icons.music_note_rounded,
        gradientColors: [const Color(0xFFD4AF37), const Color(0xFFEAB308)],
        tag: 'Mahlete Semay',
      ),
      _OnboardingSlideData(
        title: l10n.onboardingTitle2,
        description: l10n.onboardingDesc2,
        icon: Icons.library_music_rounded,
        gradientColors: [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
        tag: 'Lyrics & Scales',
      ),
      _OnboardingSlideData(
        title: l10n.onboardingTitle3,
        description: l10n.onboardingDesc3,
        icon: Icons.graphic_eq_rounded,
        gradientColors: [const Color(0xFF10B981), const Color(0xFF14B8A6)],
        tag: 'Voice Training',
      ),
      _OnboardingSlideData(
        title: l10n.onboardingTitle4,
        description: l10n.onboardingDesc4,
        icon: Icons.stars_rounded,
        gradientColors: [const Color(0xFFEC4899), const Color(0xFF8B5CF6)],
        tag: 'Vocal Ministry',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = themeProvider.isDarkMode || theme.brightness == Brightness.dark;
    final slides = _getSlides(l10n);
    final currentSlide = slides[_currentPageIndex];
    final isLastPage = _currentPageIndex == slides.length - 1;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      body: Stack(
        children: [
          // ── Ambient Dynamic Gradient Background ───────────────────────────
          AnimatedBuilder(
            animation: _ambientAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            currentSlide.gradientColors.first.withValues(alpha: 0.15),
                            const Color(0xFF0A1E3F).withValues(alpha: 0.8),
                            const Color(0xFF070E1B),
                          ]
                        : [
                            currentSlide.gradientColors.first.withValues(alpha: 0.12),
                            const Color(0xFFE8EEF9),
                            const Color(0xFFF5F7FB),
                          ],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top Header Navigation Bar ───────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Language Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language_rounded,
                                size: 14, color: Color(0xFFD4AF37)),
                            const SizedBox(width: 5),
                            Text(
                              languageProvider.currentLocale.languageCode.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Skip Button
                      if (!isLastPage)
                        TextButton(
                          onPressed: _completeOnboarding,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            l10n.skip,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),

                // ── Carousel Slides ─────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: slides.length,
                    onPageChanged: (index) {
                      setState(() => _currentPageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final slide = slides[index];
                      return _buildSlideCard(
                        slide: slide,
                        index: index,
                        isDark: isDark,
                      );
                    },
                  ),
                ),

                // ── Modern Bottom Controls & Indicator ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: Column(
                    children: [
                      // Expandable Pill Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          slides.length,
                          (index) => _buildIndicatorPill(
                            index: index,
                            isActive: index == _currentPageIndex,
                            accentColor: currentSlide.gradientColors.first,
                            isDark: isDark,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFFD4AF37)
                                .withValues(alpha: 0.4),
                          ),
                          onPressed: isLastPage
                              ? _completeOnboarding
                              : () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOutCubic,
                                  );
                                },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastPage ? l10n.getStarted : l10n.next,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLastPage
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildSlideCard({
    required _OnboardingSlideData slide,
    required int index,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hero Icon Container with Glowing Aura
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      slide.gradientColors.first.withValues(alpha: 0.35),
                      slide.gradientColors.last.withValues(alpha: 0.05),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: slide.gradientColors.first.withValues(alpha: 0.25),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xFF0F1D33)
                          : Colors.white,
                      border: Border.all(
                        color: slide.gradientColors.first.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: index == 0
                          ? ClipOval(
                              child: Image.asset(
                                'assets/logo/logo.png',
                                width: 68,
                                height: 68,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              slide.icon,
                              size: 46,
                              color: slide.gradientColors.first,
                            ),
                    ),
                  ),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 24),

              // Feature Tag Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: slide.gradientColors.first.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: slide.gradientColors.first.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  slide.tag,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: slide.gradientColors.first,
                    letterSpacing: 0.3,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // Title
              Text(
                slide.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0A1E3F),
                  letterSpacing: -0.5,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

              const SizedBox(height: 14),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  slide.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorPill({
    required int index,
    required bool isActive,
    required Color accentColor,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? accentColor
            : (isDark ? Colors.white24 : Colors.black12),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }
}
