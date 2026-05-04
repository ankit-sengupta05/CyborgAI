/// WM Theme — full port of wm2/lib/theme.dart into Cyborg's package.
/// Contains WMColors, WMTheme, MapVariant enum and extension.
/// All world_monitor files import this single file.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WMColors {
  static const bgPrimary = Color(0xFF080808);
  static const bgSecondary = Color(0xFF0f0f0f);
  static const bgPanel = Color(0xFF111111);
  static const bgHeader = Color(0xFF0a0a0a);
  static const border = Color(0xFF1c1c1c);
  static const borderLight = Color(0xFF252525);
  static const borderGlow = Color(0xFF00ff8840);

  static const accentGreen = Color(0xFF00ff88);
  static const accentRed = Color(0xFFff2244);
  static const accentOrange = Color(0xFFff7700);
  static const accentYellow = Color(0xFFffcc00);
  static const accentBlue = Color(0xFF0088ff);
  static const accentCyan = Color(0xFF00ccff);
  static const accentPurple = Color(0xFF8855ff);
  static const accentPink = Color(0xFFff44aa);

  static const textPrimary = Color(0xFFdedede);
  static const textSecond = Color(0xFF888888);
  static const textSecondary = Color(0xFF888888); // alias used in some panels
  static const textMuted = Color(0xFF444444);
  static const textGreen = Color(0xFF00ff88);
  static const textRed = Color(0xFFff4455);
  static const textOrange = Color(0xFFff8800);
  static const textYellow = Color(0xFFffcc00);

  // Alert levels
  static const highAlert = Color(0xFFff2244);
  static const elevated = Color(0xFFff8800);
  static const monitoring = Color(0xFFffcc00);
  static const conflictZone = Color(0xFFff44aa);
  static const baseMarker = Color(0xFF4488ff);
  static const nuclearMarker = Color(0xFFffee44);
  static const critBg = Color(0xFF120505);
  static const critBorder = Color(0xFF3a0000);

  // Map variant colors
  static const techCyan = Color(0xFF00e5ff);
  static const financeGreen = Color(0xFF00ff66);
  static const commodityOrange = Color(0xFFff9500);
  static const energyPurple = Color(0xFFcc44ff);
  static const goodNewsGreen = Color(0xFF4caf50);

  // Surfacing aliases used by wm_theme.dart adapter code
  static const background = Color(0xFF080808);
  static const surface = Color(0xFF0f0f0f);
  static const surfaceVariant = Color(0xFF111111);
  static const accent = Color(0xFF0088ff);
}

class WMTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: WMColors.bgPrimary,
        colorScheme: const ColorScheme.dark(
          primary: WMColors.accentGreen,
          secondary: WMColors.accentBlue,
          surface: WMColors.bgPanel,
          error: WMColors.accentRed,
        ),
        textTheme:
            GoogleFonts.jetBrainsMonoTextTheme(ThemeData.dark().textTheme)
                .copyWith(
          bodyLarge: const TextStyle(color: WMColors.textPrimary, fontSize: 12),
          bodyMedium: const TextStyle(color: WMColors.textSecond, fontSize: 10),
          bodySmall: const TextStyle(color: WMColors.textMuted, fontSize: 9),
          labelLarge: TextStyle(
              color: WMColors.accentGreen,
              fontSize: 10,
              letterSpacing: 1.2,
              fontFamily: GoogleFonts.jetBrainsMono().fontFamily),
          titleMedium: const TextStyle(
              color: WMColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700),
        ),
        dividerColor: WMColors.border,
        cardColor: WMColors.bgPanel,
        useMaterial3: true,
      );
}

// ── Map mode enum ─────────────────────────────────────────────────────────────
enum MapVariant { world, tech, finance, commodity, energy, goodNews }

extension MapVariantExt on MapVariant {
  String get label {
    switch (this) {
      case MapVariant.world:
        return 'WORLD';
      case MapVariant.tech:
        return 'TECH';
      case MapVariant.finance:
        return 'FINANCE';
      case MapVariant.commodity:
        return 'COMMODITY';
      case MapVariant.energy:
        return 'ENERGY';
      case MapVariant.goodNews:
        return 'GOOD NEWS';
    }
  }

  Color get accent {
    switch (this) {
      case MapVariant.world:
        return WMColors.accentGreen;
      case MapVariant.tech:
        return WMColors.techCyan;
      case MapVariant.finance:
        return WMColors.financeGreen;
      case MapVariant.commodity:
        return WMColors.commodityOrange;
      case MapVariant.energy:
        return WMColors.energyPurple;
      case MapVariant.goodNews:
        return WMColors.goodNewsGreen;
    }
  }
}
