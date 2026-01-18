import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------------------------------------
  // 🔴 RED THEME (Default / "Nothing")
  // ---------------------------------------------------------
  static ThemeData themeRed = _buildDarkTheme(const Color(0xFFFF2E2E));

  // Helper to build consistent dark themes with different primary colors
  static ThemeData _buildDarkTheme(Color primaryColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF111111),
      dividerColor: Colors.transparent,

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
      ),

      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          color: Colors.white,
          fontSize: 14,
          letterSpacing: 0.8,
        ),
        bodySmall: TextStyle(
          color: Color(0xFFB3B3B3),
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),

      iconTheme: const IconThemeData(
        color: Colors.white,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black, // darker contrast for neon colors
        elevation: 0,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: Colors.white12,
        circularTrackColor: Colors.white12,
      ),

      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: Colors.white,
        surface: const Color(0xFF111111),
        // Ensure text on primary is readable (black looks good on neon)
        onPrimary: Colors.black, 
      ),
    );
  }
}
