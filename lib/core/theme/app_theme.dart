import 'package:flutter/material.dart';

class AppColors {
  // Refined Obsidian/LM Studio palette - deeper, more professional
  static const Color background     = Color(0xFF0D0E12);
  static const Color surface        = Color(0xFF16181D);
  static const Color surfaceVariant = Color(0xFF1F2229);
  static const Color surfaceElevated= Color(0xFF252932);
  static const Color border         = Color(0xFF2A2E38);
  static const Color borderLight    = Color(0xFF3A3F4B);
  
  // Accent colors - refined and modern
  static const Color accent        = Color(0xFF6366F1); // Modern indigo
  static const Color accentGreen   = Color(0xFF10B981);
  static const Color accentPurple  = Color(0xFFA855F7);
  static const Color accentOrange  = Color(0xFFF97316);
  static const Color accentRed     = Color(0xFFEF4444);
  static const Color accentYellow  = Color(0xFFEAB308);
  static const Color accentCyan    = Color(0xFF06B6D4);
  static const Color accentPink    = Color(0xFFEC4899);
  static const Color accentBlue    = Color(0xFF3B82F6);
  
  // Gradient accents
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Text - improved contrast
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);
  static const Color textDisabled  = Color(0xFF475569);
  
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
  
  // Community colors (12) for graph nodes - more vibrant
  static const List<Color> communityColors = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFA855F7),
    Color(0xFFF97316), Color(0xFFEF4444), Color(0xFFEAB308),
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
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      textTheme: _buildTextTheme(AppColors.textPrimary, AppColors.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(
          color: AppColors.textSecondary, size: 22),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle:
            const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        behavior: SnackBarBehavior.floating,
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
          color: primary, letterSpacing: -1.2),
      displayMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -0.8),
      headlineLarge: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -0.5),
      headlineMedium: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: primary, letterSpacing: -0.3),
      titleLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: primary),
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
          fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelSmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: secondary, letterSpacing: 0.5),
    );
  }
}
