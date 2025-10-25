// lib/app/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Base brand colors
  static const Color brandPurple = Color(0xFF9333EA);
  static const Color brandOrange = Color(0xFFF59E0B);
  static const Color brandBlue = Color(0xFF3B82F6);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color brandRed = Color(0xFFEF4444);
  static const Color brandTeal = Color(0xFF14B8A6);
  static const Color brandCyan = Color(0xFF06B6D4);
  static const Color brandIndigo = Color(0xFF6366F1);
  static const Color brandPink = Color(0xFFDB2777);

  // Accent (secondary)
  static const Color brandAccent = Color(0xFFEC4899);

  // Dynamic title gradient (light brand → brand → deep ink)
  static LinearGradient titleGradientFrom(Color brand) {
    final hsl = HSLColor.fromColor(brand);

    final lighter = hsl
        .withSaturation((hsl.saturation * 0.95).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.20).clamp(0.0, 0.88))
        .toColor();

    final mid = hsl
        .withSaturation((hsl.saturation * 1.00).clamp(0.0, 1.0))
        .withLightness(hsl.lightness.clamp(0.18, 0.72))
        .toColor();

    final ink = hsl
        .withSaturation((hsl.saturation * 0.60).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 0.40).clamp(0.08, 0.18))
        .toColor();

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lighter, mid, ink],
      stops: const [0.0, 0.60, 1.0],
      tileMode: TileMode.clamp,
    );
  }

  // Surfaces
  static const Color kBlack = Colors.black;
  static const Color kCardDark = Color(0xFF0E0E0E);
  static const Color kLightBg = Color(0xFFF3F4F6);
  static const Color kLightCard = Colors.white;

  static ThemeData dark(Color brandPrimary) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBlack,
      canvasColor: kBlack,
      cardColor: kCardDark,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: brandPrimary,
            brightness: Brightness.dark,
          ).copyWith(
            surface: kBlack,
            primary: brandPrimary,
            secondary: brandAccent,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kBlack,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );

    final inter = GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      textTheme: inter.copyWith(
        headlineMedium: GoogleFonts.quicksand(
          textStyle: inter.headlineMedium,
        ).copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  static ThemeData light(Color brandPrimary) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: kLightBg,
      canvasColor: kLightBg,
      cardColor: kLightCard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.light,
      ).copyWith(primary: brandPrimary, secondary: brandAccent),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1F2937),
        elevation: 0,
      ),
    );

    final inter = GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      textTheme: inter.copyWith(
        headlineMedium: GoogleFonts.quicksand(
          textStyle: inter.headlineMedium,
        ).copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
