import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ILM HUB brand palette for the "21" app.
class AppColors {
  // Primary brand
  static const blue = Color(0xFF1E3A8A);
  static const teal = Color(0xFF18BEBC);
  static const orange = Color(0xFFF15A29);
  static const navy = Color(0xFF033D95);

  // Inverted / accents
  static const gold = Color(0xFFF6C744);
  static const softGold = Color(0xFFFFD166);
  static const cream = Color(0xFFFFF8E7);

  // Semantic aliases — orange-led mockup CTA style
  static const primary = orange;
  static const primaryLight = teal;
  static const accent = gold;
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const hp = Color(0xFFEF4444);
  static const streak = orange;

  // Surfaces — clean white like the mockup
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFEEF1F5);
  static const borderStrong = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF1A1D26);
  static const textSecondary = Color(0xFF8B93A7);
  static const muted = Color(0xFFB8C0D0);

  // Dark
  static const backgroundDark = Color(0xFF0B1220);
  static const surfaceDark = Color(0xFF151E2E);
  static const textPrimaryDark = Color(0xFFF3F7FB);

  // 3D button depth shades
  static const blueDepth = Color(0xFF152A63);
  static const tealDepth = Color(0xFF0E8F8D);
  static const orangeDepth = Color(0xFFC44316);
  static const goldDepth = Color(0xFFD4A020);
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final base = GoogleFonts.nunitoTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    );
    final color = brightness == Brightness.light
        ? AppColors.textPrimary
        : AppColors.textPrimaryDark;
    return base.apply(bodyColor: color, displayColor: color).copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: color,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: color,
          ),
          headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
          headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.orange,
        secondary: AppColors.teal,
        tertiary: AppColors.blue,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    return base.copyWith(
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderStrong, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderStrong, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.teal, width: 2.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.orange.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            color: selected ? AppColors.orange : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.orange : AppColors.muted,
            size: 26,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.teal.withValues(alpha: 0.18),
        side: const BorderSide(color: AppColors.borderStrong, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
      ),
      dividerColor: AppColors.border,
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.teal,
        secondary: AppColors.gold,
        tertiary: AppColors.orange,
        surface: AppColors.surfaceDark,
        error: AppColors.orange,
        onPrimary: AppColors.navy,
        onSecondary: AppColors.navy,
        onSurface: AppColors.textPrimaryDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
    );
    return base.copyWith(
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.teal.withValues(alpha: 0.2),
      ),
    );
  }
}
