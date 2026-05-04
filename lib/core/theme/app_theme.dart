import 'package:flutter/material.dart';

/// LM Studio-inspired Color Palette
/// Replicating the clean, professional dark theme of LM Studio
class AppColors {
  // Background colors - LM Studio's signature dark grays
  static const Color backgroundMain = Color(0xFF18181B);      // Main app background (Zinc 900)
  static const Color backgroundSidebar = Color(0xFF202022);   // Sidebar background
  static const Color backgroundSurface = Color(0xFF27272A);   // Cards, panels (Zinc 800)
  static const Color backgroundInput = Color(0xFF3F3F46);     // Input fields (Zinc 700)
  
  // Border colors - subtle but defined
  static const Color borderDefault = Color(0xFF3F3F46);       // Default borders
  static const Color borderHover = Color(0xFF52525B);         // Hover state borders
  
  // Text colors - excellent contrast and hierarchy
  static const Color textPrimary = Color(0xFFFAFAFA);         // Primary text (Zinc 50)
  static const Color textSecondary = Color(0xFFA1A1AA);       // Secondary text (Zinc 400)
  static const Color textTertiary = Color(0xFF71717A);        // Muted text (Zinc 500)
  
  // Accent color - LM Studio's blue
  static const Color accentBlue = Color(0xFF3B82F6);          // Primary accent (Blue 500)
  static const Color accentBlueHover = Color(0xFF2563EB);     // Hover state (Blue 600)
  
  // Status colors
  static const Color success = Color(0xFF10B981);             // Emerald 500
  static const Color warning = Color(0xFFF59E0B);             // Amber 500
  static const Color error = Color(0xFFEF4444);               // Red 500
  static const Color info = Color(0xFF3B82F6);                // Blue 500
  
  // Gradient for special elements
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Community/node colors (12 distinct colors)
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
      scaffoldBackgroundColor: AppColors.backgroundMain,
      primaryColor: AppColors.accentBlue,
      
      colorScheme: const ColorScheme.dark(
        surface: AppColors.backgroundSurface,
        primary: AppColors.accentBlue,
        secondary: AppColors.accentBlue,
        tertiary: AppColors.success,
        error: AppColors.error,
        onSurface: AppColors.textPrimary,
        outline: AppColors.borderDefault,
      ),
      
      // Card Styles - LM Studio style with subtle borders
      cardTheme: CardThemeData(
        color: AppColors.backgroundSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
      ),
      
      // AppBar - Clean, minimal
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundMain,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary, size: 20),
      ),
      
      // Typography - Clean Inter font, perfect hierarchy
      textTheme: _buildTextTheme(AppColors.textPrimary, AppColors.textSecondary),
      
      // Input Decoration - LM Studio's signature flat inputs with border on focus
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
      
      // Elevated Buttons - Blue accent, rounded corners
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      
      // Outlined Buttons - Subtle borders
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundSurface,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      
      // Divider - Subtle separation
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDefault,
        thickness: 1,
        space: 1,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      
      // Progress Indicator - Slim blue line
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentBlue,
        strokeWidth: 3,
      ),
      
      // Snackbar - Floating with border
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundSurface,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      
      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      
      // Scrollbar - Minimalist
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.textTertiary),
        trackVisibility: WidgetStateProperty.all(true),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(6),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: Colors.white,
        primary: Color(0xFF0969DA),
        secondary: Color(0xFF0969DA),
        error: Color(0xFFCF222E),
        onSurface: Color(0xFF0F172A),
        outline: Color(0xFFE2E8F0),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      textTheme: _buildTextTheme(const Color(0xFF0F172A), const Color(0xFF64748B)),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.8, height: 1.2),
      displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.6, height: 1.3),
      displaySmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.4, height: 1.3),
      headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.3, height: 1.3),
      headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.2, height: 1.4),
      headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary, height: 1.4),
      titleLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primary, height: 1.5),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary, height: 1.5),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondary, height: 1.4),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: primary, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: primary, height: 1.5),
      bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: secondary, height: 1.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: primary, letterSpacing: 0.1),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0.1),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0.2),
    );
  }
}
