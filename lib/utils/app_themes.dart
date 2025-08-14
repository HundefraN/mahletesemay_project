import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  static final Color _lightFocusColor = Colors.black.withOpacity(0.12);
  static final Color _darkFocusColor = Colors.white.withOpacity(0.12);

  static ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0D47A1),
      brightness: Brightness.light,
      primary: const Color(0xFF0D47A1),
      secondary: const Color(0xFFFBC02D),
      background: const Color(0xFFF4F6F8),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onBackground: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
    ),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
      titleTextStyle: GoogleFonts.montserrat(
        color: const Color(0xFF0D47A1),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    focusColor: _lightFocusColor,
  );

  static ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFBC02D),
      brightness: Brightness.dark,
      primary: const Color(0xFFFBC02D),
      secondary: const Color(0xFF0D47A1),
      background: const Color(0xFF121212),
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onBackground: Colors.white,
      surface: const Color(0xFF1E1E1E),
      onSurface: Colors.white,
    ),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFFFBC02D)),
      titleTextStyle: GoogleFonts.montserrat(
        color: const Color(0xFFFBC02D),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    focusColor: _darkFocusColor,
  );
}