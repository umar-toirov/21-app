import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ILM HUB brand palette for the "21" app.
///
/// Brand hues are constant. Surfaces, borders and text resolve against
/// [AppColors.isDark], which the app root sets before every build.
class AppColors {
  /// Set by the app root from the resolved theme mode.
  static bool isDark = false;

  // Primary brand
  static const orange = Color(0xFFF15A29);
  static const teal = Color(0xFF18BEBC);
  static const gold = Color(0xFFF6C744);
  static const softGold = Color(0xFFFFD166);

  // Brand blues are lifted in dark mode so they stay readable.
  static Color get blue => isDark ? const Color(0xFF8AA8FF) : const Color(0xFF1E3A8A);
  static Color get navy => isDark ? const Color(0xFF7FA3FF) : const Color(0xFF033D95);

  // Semantic aliases
  static const primary = orange;
  static const primaryLight = teal;
  static const accent = gold;
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const hp = Color(0xFFEF4444);
  static const streak = orange;

  // Surfaces
  static Color get background =>
      isDark ? const Color(0xFF0C0D10) : const Color(0xFFF5F5F7);
  static Color get surface =>
      isDark ? const Color(0xFF16181D) : const Color(0xFFFFFFFF);
  static Color get surfaceRaised =>
      isDark ? const Color(0xFF1D2026) : const Color(0xFFFFFFFF);
  static Color get border =>
      isDark ? const Color(0xFF24272F) : const Color(0xFFEBEBEF);
  static Color get borderStrong =>
      isDark ? const Color(0xFF30343E) : const Color(0xFFDCDDE3);

  // Text
  static Color get textPrimary =>
      isDark ? const Color(0xFFF2F3F6) : const Color(0xFF15161A);
  static Color get textSecondary =>
      isDark ? const Color(0xFF9A9EAB) : const Color(0xFF70737F);
  static Color get muted =>
      isDark ? const Color(0xFF5E6270) : const Color(0xFFA9ACB8);

  // Soft tinted fills (badges, chips, highlights)
  static Color get cream =>
      isDark ? const Color(0xFF221D14) : const Color(0xFFFFF8E7);
  static Color get orangeSoft =>
      isDark ? const Color(0xFF2A1A13) : const Color(0xFFFFF0E8);
  static Color get blueSoft =>
      isDark ? const Color(0xFF151D33) : const Color(0xFFE8F0FF);
  static Color get tealSoft =>
      isDark ? const Color(0xFF0F2524) : const Color(0xFFE6F7F6);
  static Color get goldSoft =>
      isDark ? const Color(0xFF2A2412) : const Color(0xFFFFF4D6);
  static Color get dangerSoft =>
      isDark ? const Color(0xFF2B1517) : const Color(0xFFFFF1F1);

  // Legacy 3D shades (kept so old references still compile)
  static const orangeDepth = Color(0xFFC44316);
  static const tealDepth = Color(0xFF0E8F8D);
  static const goldDepth = Color(0xFFD4A020);
  static const blueDepth = Color(0xFF152A63);
}

/// Fade + gentle rise. Fast, and identical on web, Android and iOS.
class _SnappyTransitions extends PageTransitionsBuilder {
  const _SnappyTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class AppTheme {
  static final _transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: const _SnappyTransitions(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: _SnappyTransitions(),
      TargetPlatform.macOS: _SnappyTransitions(),
      TargetPlatform.linux: _SnappyTransitions(),
      TargetPlatform.fuchsia: _SnappyTransitions(),
    },
  );

  static TextTheme _textTheme(Brightness brightness, Color color) {
    final base = GoogleFonts.interTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    );
    return base.apply(bodyColor: color, displayColor: color).copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: color,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: color,
          ),
          headlineLarge:
              base.headlineLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
          headlineMedium:
              base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
          headlineSmall:
              base.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: color,
          ),
          titleMedium:
              base.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: color),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: color,
          ),
        );
  }

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    // Tokens are resolved here (not through AppColors) so both themes can be
    // built at once, whatever AppColors.isDark currently says.
    final background = dark ? const Color(0xFF0C0D10) : const Color(0xFFF5F5F7);
    final surface = dark ? const Color(0xFF16181D) : const Color(0xFFFFFFFF);
    final border = dark ? const Color(0xFF24272F) : const Color(0xFFEBEBEF);
    final borderStrong = dark ? const Color(0xFF30343E) : const Color(0xFFDCDDE3);
    final text = dark ? const Color(0xFFF2F3F6) : const Color(0xFF15161A);
    final textSecondary = dark ? const Color(0xFF9A9EAB) : const Color(0xFF70737F);
    final muted = dark ? const Color(0xFF5E6270) : const Color(0xFFA9ACB8);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.orange,
      onPrimary: Colors.white,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      tertiary: dark ? const Color(0xFF7FA3FF) : const Color(0xFF1E3A8A),
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      outline: borderStrong,
      outlineVariant: border,
    );

    final textTheme = _textTheme(brightness, text);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      pageTransitionsTheme: _transitions,
      splashFactory: InkRipple.splashFactory,
      splashColor: AppColors.orange.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      hoverColor: text.withValues(alpha: 0.04),
      visualDensity: VisualDensity.standard,
      dividerColor: border,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: text,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: borderStrong,
          disabledForegroundColor: muted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.orange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? text : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? text : muted, size: 24);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: AppColors.orange.withValues(alpha: 0.14),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, color: text),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          height: 1.4,
          color: textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF2A2D35) : const Color(0xFF1C1D22),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.orange : border,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.orange,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: text,
        unselectedLabelColor: textSecondary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: textSecondary,
          selectedBackgroundColor: AppColors.orange.withValues(alpha: 0.14),
          selectedForegroundColor: AppColors.orange,
          side: BorderSide(color: borderStrong),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }
}
