import 'package:flutter/material.dart';

class AppColors {
  // Primary Obsidian/LM Studio palette
  static const Color background     = Color(0xFF15161A);
  static const Color surface        = Color(0xFF1E1F24);
  static const Color surfaceVariant = Color(0xFF282931);
  static const Color border         = Color(0xFF383A43);

  // Accent colors
  static const Color accent        = Color(0xFF5A4BC2); // LM Studio purple
  static const Color accentGreen   = Color(0xFF3FB950);
  static const Color accentPurple  = Color(0xFFBC8CFF);
  static const Color accentOrange  = Color(0xFFF0883E);
  static const Color accentRed     = Color(0xFFF85149);
  static const Color accentYellow  = Color(0xFFE3B341);
  static const Color accentCyan    = Color(0xFF39D353);
  static const Color accentPink    = Color(0xFFF778BA);

  // Text
  static const Color textPrimary   = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted     = Color(0xFF484F58);

  // GSD phase colors
  static const Color phaseBlue   = Color(0xFF3B82F6);
  static const Color phaseGreen  = Color(0xFF22C55E);
  static const Color phaseOrange = Color(0xFFF97316);
  static const Color phaseRed    = Color(0xFFEF4444);

  // Light theme
  static const Color lightBackground    = Color(0xFFF6F8FA);
  static const Color lightSurface       = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant= Color(0xFFF0F2F5);
  static const Color lightBorder        = Color(0xFFD0D7DE);
  static const Color lightText          = Color(0xFF1F2328);
  static const Color lightTextSecondary = Color(0xFF656D76);

  // Community colors (12) for graph nodes
  static const List<Color> communityColors = [
    Color(0xFF58A6FF), Color(0xFF3FB950), Color(0xFFBC8CFF),
    Color(0xFFF0883E), Color(0xFFF85149), Color(0xFFE3B341),
    Color(0xFF39D353), Color(0xFFF778BA), Color(0xFF79C0FF),
    Color(0xFFFFB3C2), Color(0xFFAFF5B4), Color(0xFFFFD700),
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
        error: AppColors.accentRed,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      // Flutter 3.x uses CardThemeData
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      textTheme: _buildTextTheme(AppColors.textPrimary, AppColors.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(
            color: AppColors.textSecondary, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.border),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(
          color: AppColors.textSecondary, size: 20),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceVariant,
        contentTextStyle:
            const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
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
          fontSize: 32, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -1.0),
      displayMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -0.5),
      headlineLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -0.3),
      headlineMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600,
          color: primary, letterSpacing: -0.2),
      titleLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: primary),
      titleMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: primary),
      bodyLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: primary, height: 1.6),
      bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: primary, height: 1.5),
      bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w400,
          color: secondary, height: 1.4),
      labelLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: primary),
      labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500,
          color: secondary, letterSpacing: 0.5),
    );
  }
}
