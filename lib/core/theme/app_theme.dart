import 'package:flutter/material.dart';

class AppColors {
  // Professional Obsidian-inspired palette - deeper and more refined
  static const Color background     = Color(0xFF09090B); // Zinc 950
  static const Color surface        = Color(0xFF18181B); // Zinc 900
  static const Color surfaceVariant = Color(0xFF27272A); // Zinc 800
  static const Color surfaceElevated= Color(0xFF3F3F46); // Zinc 700
  static const Color border         = Color(0xFF27272A); // Zinc 800
  static const Color borderLight    = Color(0xFF3F3F46); // Zinc 700
  
  // Modern professional accent colors
  static const Color accent        = Color(0xFF3B82F6); // Blue 500
  static const Color accentGreen   = Color(0xFF10B981); // Emerald 500
  static const Color accentPurple  = Color(0xFF8B5CF6); // Violet 500
  static const Color accentOrange  = Color(0xFFF97316); // Orange 500
  static const Color accentRed     = Color(0xFFEF4444); // Red 500
  static const Color accentYellow  = Color(0xFFF59E0B); // Amber 500
  static const Color accentCyan    = Color(0xFF06B6D4); // Cyan 500
  static const Color accentPink    = Color(0xFFEC4899); // Pink 500
  static const Color accentBlue    = Color(0xFF3B82F6); // Blue 500
  
  // Gradient accents
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Text - improved contrast and readability
  static const Color textPrimary   = Color(0xFFF4F4F5); // Zinc 100
  static const Color textSecondary = Color(0xFFA1A1AA); // Zinc 400
  static const Color textMuted     = Color(0xFF71717A); // Zinc 500
  static const Color textDisabled  = Color(0xFF52525B); // Zinc 600
  
  // Status colors
  static const Color success       = Color(0xFF10B981);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color error         = Color(0xFFEF4444);
  static const Color info          = Color(0xFF3B82F6);
  
  // GSD phase colors
  static const Color phaseBlue   = Color(0xFF3B82F6);
  static const Color phaseGreen  = Color(0xFF22C55E);
  static const Color phaseOrange = Color(0xFFF97316);
  static const Color phaseRed    = Color(0xFFEF4444);
  
  // Light theme
  static const Color lightBackground    = Color(0xFFF8FAFC);
  static const Color lightSurface       = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant= Color(0xFFF1F5F9);
  static const Color lightBorder        = Color(0xFFE2E8F0);
  static const Color lightText          = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  
  // Community colors (12) for graph nodes - vibrant and distinct
  static const List<Color> communityColors = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFF8B5CF6),
    Color(0xFFF97316), Color(0xFFEF4444), Color(0xFFF59E0B),
    Color(0xFF06B6D4), Color(0xFFEC4899), Color(0xFF60A5FA),
    Color(0xFFF472B6), Color(0xFF34D399), Color(0xFFFBBF24),
  ];
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        secondary: AppColors.accentPurple,
        tertiary: AppColors.accentGreen,
        error: AppColors.error,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      // Flutter 3.x uses CardThemeData
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary, size: 24),
      ),
      textTheme: _buildTextTheme(AppColors.textPrimary, AppColors.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
          color: AppColors.textSecondary, size: 24),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        strokeWidth: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle:
            const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      // fontFamily: 'JetBrainsMono', // uncomment after adding font files to assets/fonts/
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: AppColors.lightSurface,
        primary: Color(0xFF0969DA),
        secondary: Color(0xFF8250DF),
        error: Color(0xFFCF222E),
        onSurface: AppColors.lightText,
        outline: AppColors.lightBorder,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      // fontFamily: 'JetBrainsMono', // uncomment after adding font files to assets/fonts/
      textTheme: _buildTextTheme(
          AppColors.lightText, AppColors.lightTextSecondary),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
          fontSize: 36, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -1.2, height: 1.2),
      displayMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -0.8, height: 1.3),
      headlineLarge: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -0.5, height: 1.3),
      headlineMedium: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: primary, letterSpacing: -0.3, height: 1.4),
      titleLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: primary, height: 1.5),
      titleMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: primary, height: 1.5),
      bodyLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400,
          color: primary, height: 1.6),
      bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: primary, height: 1.5),
      bodySmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: secondary, height: 1.4),
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: primary, letterSpacing: 0.1),
      labelSmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: secondary, letterSpacing: 0.5),
    );
  }
}
