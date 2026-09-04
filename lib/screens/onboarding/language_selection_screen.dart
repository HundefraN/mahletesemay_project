import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../admin/permissions/permission_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../home_screen.dart';
import 'onboarding_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgAnimationController;

  final List<_LanguageItem> _languages = const [
    _LanguageItem(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
      subtitleKey: 'Spiritual Hymns & Vocal Training',
      badge: 'EN',
      accentColor: Color(0xFF3B82F6),
    ),
    _LanguageItem(
      code: 'am',
      nativeName: 'አማርኛ',
      englishName: 'Amharic',
      subtitleKey: 'የመንፈሳዊ ዝማሬዎች እና የድምፅ ስልጠና',
      badge: 'አማ',
      accentColor: Color(0xFFF59E0B),
    ),
    _LanguageItem(
      code: 'om',
      nativeName: 'Afaan Oromoo',
      englishName: 'Oromiffa',
      subtitleKey: 'Faarfannaa fi Leenjii Sagalee',
      badge: 'OM',
      accentColor: Color(0xFF10B981),
    ),
    _LanguageItem(
      code: 'ti',
      nativeName: 'ትግርኛ',
      englishName: 'Tigrinya',
      subtitleKey: 'መንፈሳዊ ዝማሬን ስልጠና ድምጽን',
      badge: 'ትግ',
      accentColor: Color(0xFFEF4444),
    ),
    _LanguageItem(
      code: 'so',
      nativeName: 'Af Soomaali',
      englishName: 'Somali',
      subtitleKey: 'Heesaha Ruuxiga iyo Tababarka Codka',
      badge: 'SO',
      accentColor: Color(0xFF0EA5E9),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefLanguageSelected, true);

    if (!mounted) return;

    // On Web: Skip permissions and onboarding, navigate directly to HomeScreen.
    if (kIsWeb) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
      return;
    }

    final hasCompletedPermissions =
        prefs.getBool(prefPermissionsCompleted) ?? false;
    final hasCompletedOnboarding =
        prefs.getBool(prefOnboardingCompleted) ?? false;

    Widget nextScreen;
    if (!hasCompletedPermissions) {
      nextScreen = const PermissionScreen();
    } else if (!hasCompletedOnboarding) {
      nextScreen = const OnboardingScreen();
    } else {
      nextScreen = const HomeScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final l10n = AppLocalizations.of(context);
    final isDark = themeProvider.isDarkMode || theme.brightness == Brightness.dark;
    final selectedCode = languageProvider.currentLocale.languageCode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      body: Stack(
        children: [
          // ── Ambient Animated Gradient Background ──────────────────────────
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
                            const Color(0xFF0F172A).withValues(alpha: 0.8),
                            const Color(0xFF070E1B),
                          ]
                        : [
                            const Color(0xFFE0E7FF),
                            const Color(0xFFEDE9FE).withValues(alpha: 0.6),
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
                  const SizedBox(height: 24),

                  // ── Logo & Title Section ──────────────────────────────────
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 20),

                  Text(
                    l10n?.chooseLanguageTitle ?? 'Choose Your Language',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0A1E3F),
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 8),

                  Text(
                    l10n?.chooseLanguageSubtitle ??
                        'Select your preferred language to continue.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                  const SizedBox(height: 28),

                  // ── Language Options Cards ────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _languages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = _languages[index];
                        final isSelected = selectedCode == item.code;

                        return _buildLanguageCard(
                          context: context,
                          item: item,
                          isSelected: isSelected,
                          isDark: isDark,
                          onTap: () {
                            languageProvider.setLocale(Locale(item.code));
                          },
                        )
                            .animate(delay: (200 + index * 100).ms)
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1, end: 0);
                      },
                    ),
                  ),

                  // ── Footer Note ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      l10n?.languageSelectionNote ??
                          'You can always change your language anytime in Settings.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // ── Continue Button ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor:
                            const Color(0xFFD4AF37).withValues(alpha: 0.4),
                      ),
                      onPressed: _proceed,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n?.continueButton ?? 'Continue',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required _LanguageItem item,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? item.accentColor.withValues(alpha: 0.18)
                  : item.accentColor.withValues(alpha: 0.1))
              : (isDark
                  ? const Color(0xFF0F1D33).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? item.accentColor
                : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: item.accentColor.withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            // Badge / Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.accentColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: item.accentColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  item.badge,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: item.accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Names & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.nativeName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0A1E3F),
                        ),
                      ),
                      if (item.nativeName != item.englishName) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${item.englishName})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitleKey,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Radio / Checkmark indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? item.accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? item.accentColor
                      : (isDark ? Colors.white30 : Colors.black26),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageItem {
  final String code;
  final String nativeName;
  final String englishName;
  final String subtitleKey;
  final String badge;
  final Color accentColor;

  const _LanguageItem({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.subtitleKey,
    required this.badge,
    required this.accentColor,
  });
}
