import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6B46C1);
  static const Color secondaryColor = Color(0xFFEC4899);
  static const Color accentColor = Color(0xFFF59E0B);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color darkBackgroundColor = Color(0xFF0F172A);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color darkCardColor = Color(0xFF1E293B);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: MaterialColor(0xFF6B46C1, {
      50: Color(0xFFF3F0FF),
      100: Color(0xFFE9E2FF),
      200: Color(0xFFD6CCFF),
      300: Color(0xFFBBA8FF),
      400: Color(0xFF9B7AFF),
      500: Color(0xFF6B46C1),
      600: Color(0xFF553C9A),
      700: Color(0xFF44337A),
      800: Color(0xFF362A5F),
      900: Color(0xFF2A2048),
    }),
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: MaterialColor(0xFF6B46C1, {
      50: Color(0xFFF3F0FF),
      100: Color(0xFFE9E2FF),
      200: Color(0xFFD6CCFF),
      300: Color(0xFFBBA8FF),
      400: Color(0xFF9B7AFF),
      500: Color(0xFF6B46C1),
      600: Color(0xFF553C9A),
      700: Color(0xFF44337A),
      800: Color(0xFF362A5F),
      900: Color(0xFF2A2048),
    }),
    scaffoldBackgroundColor: darkBackgroundColor,
    cardColor: darkCardColor,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCardColor,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}