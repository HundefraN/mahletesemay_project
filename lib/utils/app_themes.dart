import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  // Logo-derived palette: Deep Royal Navy & Celestial Divine Gold
  static const Color royalNavy = Color(0xFF0A1E3F);
  static const Color celestialGold = Color(0xFFDFB76C);
  static const Color celestialGoldLight = Color(0xFFF5E09D);
  static const Color celestialGoldDark = Color(0xFFC59B27);
  static const Color navySurfaceLight = Color(0xFFFFFFFF);
  static const Color navyBackgroundLight = Color(0xFFF5F7FB);
  static const Color navyBackgroundDark = Color(0xFF070E1B);
  static const Color navySurfaceDark = Color(0xFF0F1D33);
  static const Color navyCardDark = Color(0xFF13233D);

  static final Color _lightPrimary = royalNavy;
  static final Color _lightSecondary = celestialGoldDark;
  static final Color _lightBackground = navyBackgroundLight;

  static final Color _darkPrimary = celestialGold;
  static final Color _darkSecondary = const Color(0xFF1B3B6F);
  static final Color _darkBackground = navyBackgroundDark;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.light,
      primary: _lightPrimary,
      secondary: _lightSecondary,
      tertiary: celestialGold,
      surface: navySurfaceLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFF0A1E3F),
    ),
    scaffoldBackgroundColor: _lightBackground,
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: _lightBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: _lightPrimary),
      titleTextStyle: GoogleFonts.montserrat(
        color: _lightPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightPrimary,
        foregroundColor: celestialGoldLight,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: kIsWeb
          ? {
              TargetPlatform.android: const FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: const FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.linux: const FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.macOS: const FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.windows: const FadeUpwardsPageTransitionsBuilder(),
            }
          : const {
              TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: kIsWeb ? WidgetStateProperty.all(true) : null,
      thickness: kIsWeb ? WidgetStateProperty.all(6.0) : null,
      radius: const Radius.circular(8),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return royalNavy.withValues(alpha: 0.5);
        }
        return royalNavy.withValues(alpha: 0.2);
      }),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: royalNavy.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: royalNavy.withValues(alpha: 0.06), width: 1),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.fixed,
      backgroundColor: royalNavy,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      contentTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      brightness: Brightness.dark,
      primary: _darkPrimary,
      secondary: _darkSecondary,
      tertiary: celestialGoldLight,
      surface: navySurfaceDark,
      onPrimary: const Color(0xFF070E1B),
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: _darkBackground,
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: navySurfaceDark,
      elevation: 0,
      iconTheme: IconThemeData(color: _darkPrimary),
      titleTextStyle: GoogleFonts.montserrat(
        color: _darkPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkPrimary,
        foregroundColor: const Color(0xFF070E1B),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: kIsWeb
          ? {
              TargetPlatform.android: const FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: const FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.linux: const FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.macOS: const FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.windows: const FadeUpwardsPageTransitionsBuilder(),
            }
          : const {
              TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: kIsWeb ? WidgetStateProperty.all(true) : null,
      thickness: kIsWeb ? WidgetStateProperty.all(6.0) : null,
      radius: const Radius.circular(8),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return celestialGold.withValues(alpha: 0.6);
        }
        return celestialGold.withValues(alpha: 0.25);
      }),
    ),
    cardTheme: CardThemeData(
      color: navyCardDark,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: celestialGold.withValues(alpha: 0.12), width: 1),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.fixed,
      backgroundColor: Color(0xFF1B3B6F),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      contentTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}