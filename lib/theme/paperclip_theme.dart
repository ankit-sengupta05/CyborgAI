import 'package:flutter/material.dart';

/// CyborgAI Design System
/// Deep obsidian backgrounds + electric green/cyan accent palette
/// Matches the app's GPU badge, connection status, and overall AGI aesthetic

class PaperclipTheme {
  PaperclipTheme._();

  // ── Brand / Accent ────────────────────────────────────────────────────────
  static const Color accentGreen  = Color(0xFF00E5A0);   // Electric mint green
  static const Color accentCyan   = Color(0xFF00C2FF);   // Electric cyan
  static const Color accentPurple = Color(0xFF9B5FFF);   // Neon purple
  static const Color accentAmber  = Color(0xFFFFAB00);   // Warm amber
  static const Color accentRed    = Color(0xFFFF4C6E);   // Neon red

  // ── Dark palette ─────────────────────────────────────────────────────────
  static const Color backgroundDark      = Color(0xFF0C0E12);  // Near-black
  static const Color surfaceDark         = Color(0xFF131620);  // Card surface
  static const Color surfaceElevatedDark = Color(0xFF1A1D2E);  // Elevated cards
  static const Color sidebarDark         = Color(0xFF0F1118);  // Sidebar
  static const Color borderDark          = Color(0xFF252840);  // Subtle border
  static const Color borderBrightDark    = Color(0xFF353868);  // Brighter border
  static const Color foregroundDark      = Color(0xFFF0F2FF);  // Primary text
  static const Color mutedDark           = Color(0xFF8B90B8);  // Secondary text
  static const Color mutedFgDark         = Color(0xFF5C6080);  // Tertiary text

  // ── Light palette ─────────────────────────────────────────────────────────
  static const Color backgroundLight     = Color(0xFFF4F6FA);
  static const Color surfaceLight        = Color(0xFFFFFFFF);
  static const Color sidebarLight        = Color(0xFFFFFFFF);
  static const Color borderLight         = Color(0xFFE3E7F0);
  static const Color foregroundLight     = Color(0xFF0C0E12);
  static const Color mutedLight          = Color(0xFF6B7280);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color statusOpen       = Color(0xFF8B90B8);
  static const Color statusInProgress = Color(0xFF00C2FF);
  static const Color statusDone       = Color(0xFF00E5A0);
  static const Color statusCancelled  = Color(0xFF5C6080);
  static const Color statusBlocked    = Color(0xFFFF4C6E);

  // ── Typography ────────────────────────────────────────────────────────────
  static const String fontFamily = 'Inter';

  // ── Geometry ──────────────────────────────────────────────────────────────
  static const double sidebarWidth = 228;
  static const double panelWidth   = 320;
  static const double radius       = 8.0;
  static const double radiusSm     = 5.0;
  static const double radiusLg     = 12.0;

  // ─────────────────────────────────────────────────────────────────────────
  static ThemeData dark() {
    const fg    = foregroundDark;
    const muted = mutedDark;
    const bg    = backgroundDark;
    const surf  = surfaceDark;
    const bord  = borderDark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary:          accentGreen,
        onPrimary:        Color(0xFF001A12),
        secondary:        surfaceElevatedDark,
        onSecondary:      fg,
        surface:          surf,
        onSurface:        fg,
        error:            accentRed,
        onError:          Colors.white,
        outline:          bord,
        tertiary:         accentCyan,
        onTertiary:       Color(0xFF001A26),
      ),
      dividerColor: bord,
      cardTheme: CardThemeData(
        color: surf,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: bord),
          borderRadius: BorderRadius.circular(radius),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
        ),
      ),
      textTheme: _buildTextTheme(fg, muted),
      inputDecorationTheme: _buildInputTheme(bord, surf, fg),
      elevatedButtonTheme: _buildElevatedButtonTheme(accentGreen, const Color(0xFF001A12)),
      outlinedButtonTheme: _buildOutlinedButtonTheme(bord, fg),
      textButtonTheme: _buildTextButtonTheme(muted),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        minVerticalPadding: 2,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: bord, thickness: 1, space: 0),
      iconTheme: const IconThemeData(color: mutedDark, size: 16),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceElevatedDark,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: bord),
        ),
        textStyle: const TextStyle(color: fg, fontSize: 12, fontFamily: fontFamily),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentGreen;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(const Color(0xFF001A12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        side: const BorderSide(color: borderBrightDark, width: 1.5),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentGreen.withValues(alpha: 0.15);
            return surf;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentGreen;
            return muted;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: bord)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: _buildInputTheme(bord, surf, fg),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surfaceElevatedDark),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              side: const BorderSide(color: bord),
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(borderBrightDark),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }

  static ThemeData light() {
    const fg   = foregroundLight;
    const muted = mutedLight;
    const bg   = backgroundLight;
    const surf = surfaceLight;
    const bord = borderLight;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.light(
        primary:    accentGreen.withValues(alpha: 0.9),
        onPrimary:  Colors.white,
        secondary:  const Color(0xFFEFF3FA),
        onSecondary: fg,
        surface:    surf,
        onSurface:  fg,
        error:      const Color(0xFFDC2626),
        onError:    Colors.white,
        outline:    bord,
      ),
      dividerColor: bord,
      cardTheme: CardThemeData(
        color: surf,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: bord),
          borderRadius: BorderRadius.circular(radius),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surf,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: fg, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: fontFamily,
        ),
      ),
      textTheme: _buildTextTheme(fg, muted),
      inputDecorationTheme: _buildInputTheme(bord, surf, fg),
      elevatedButtonTheme: _buildElevatedButtonTheme(fg, Colors.white),
      outlinedButtonTheme: _buildOutlinedButtonTheme(bord, fg),
      textButtonTheme: _buildTextButtonTheme(fg),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        minVerticalPadding: 2,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: bord, thickness: 1, space: 0),
      iconTheme: const IconThemeData(color: mutedLight, size: 16),
    );
  }

  static TextTheme _buildTextTheme(Color fg, Color muted) => TextTheme(
        displayLarge:  TextStyle(color: fg,    fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displayMedium: TextStyle(color: fg,    fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        displaySmall:  TextStyle(color: fg,    fontSize: 20, fontWeight: FontWeight.w600),
        headlineLarge: TextStyle(color: fg,    fontSize: 18, fontWeight: FontWeight.w600),
        headlineMedium:TextStyle(color: fg,    fontSize: 16, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: fg,    fontSize: 14, fontWeight: FontWeight.w600),
        titleLarge:    TextStyle(color: fg,    fontSize: 14, fontWeight: FontWeight.w600),
        titleMedium:   TextStyle(color: fg,    fontSize: 13, fontWeight: FontWeight.w500),
        titleSmall:    TextStyle(color: fg,    fontSize: 12, fontWeight: FontWeight.w500),
        bodyLarge:     TextStyle(color: fg,    fontSize: 14, height: 1.6),
        bodyMedium:    TextStyle(color: fg,    fontSize: 13, height: 1.5),
        bodySmall:     TextStyle(color: muted, fontSize: 12, height: 1.4),
        labelLarge:    TextStyle(color: fg,    fontSize: 13, fontWeight: FontWeight.w500),
        labelMedium:   TextStyle(color: muted, fontSize: 12),
        labelSmall:    TextStyle(color: muted, fontSize: 11, letterSpacing: 0.4),
      );

  static InputDecorationTheme _buildInputTheme(Color border, Color fill, Color fg) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: accentGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: accentRed),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 13),
        hintStyle: TextStyle(color: fg.withValues(alpha: 0.35), fontSize: 13),
        isDense: true,
      );

  static ElevatedButtonThemeData _buildElevatedButtonTheme(Color bg, Color fg) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: fontFamily),
        ),
      );

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(Color border, Color fg) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: fontFamily),
        ),
      );

  static TextButtonThemeData _buildTextButtonTheme(Color fg) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: fontFamily),
        ),
      );
}