import 'package:flutter/material.dart';

import 'package:sms_sender_app/app/theme_palettes.dart';
import 'package:sms_sender_app/l10n/strings.dart';

/// The four visual styles the operator can pick in the drawer. Every style
/// has a light and a dark variant; the user also chooses light / dark / auto.
enum AppStyle {
  softGlass,
  boldBrand,
  cleanMono,
  darkNeon;

  static AppStyle fromName(String? name) => AppStyle.values
      .firstWhere((s) => s.name == name, orElse: () => AppStyle.darkNeon);
}

extension AppStylePresentation on AppStyle {
  String get label => switch (this) {
        AppStyle.softGlass => 'Soft Glass',
        AppStyle.boldBrand => 'Bold Brand',
        AppStyle.cleanMono => 'Clean Mono',
        AppStyle.darkNeon => 'Dark Neon',
      };

  String get description => switch (this) {
        AppStyle.softGlass => S.current.styleSoftGlass,
        AppStyle.boldBrand => S.current.styleBoldBrand,
        AppStyle.cleanMono => S.current.styleCleanMono,
        AppStyle.darkNeon => S.current.styleDarkNeon,
      };

  /// Bundled Google Fonts (all with Cyrillic glyphs), see pubspec.yaml.
  String get fontFamily => switch (this) {
        AppStyle.softGlass => 'Manrope',
        AppStyle.boldBrand => 'Montserrat',
        AppStyle.cleanMono => 'Inter',
        AppStyle.darkNeon => 'Exo2',
      };

  String get displayFontFamily => switch (this) {
        AppStyle.cleanMono => 'Onest',
        _ => fontFamily,
      };

  double get radius => switch (this) {
        AppStyle.softGlass => 22,
        AppStyle.boldBrand => 16,
        AppStyle.cleanMono => 12,
        AppStyle.darkNeon => 18,
      };
}

/// Style-specific values that Material's ThemeData has no slot for. Widgets
/// read them with `AppStyleTokens.of(context)`.
class AppStyleTokens extends ThemeExtension<AppStyleTokens> {
  const AppStyleTokens({
    required this.style,
    required this.radius,
    required this.accent,
    required this.onAccent,
    required this.cta,
    required this.onCta,
    required this.cardColor,
    required this.cardBorder,
    required this.glass,
    required this.hairlines,
    required this.floatingNav,
    required this.navBackground,
    required this.navActive,
    required this.navInactive,
    required this.navGlow,
    required this.hero,
    required this.onHero,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final AppStyle style;
  final double radius;

  /// Highlight colour (active tab, links, progress).
  final Color accent;
  final Color onAccent;

  /// Primary action colour (FAB, "send all"); equals [accent] except for
  /// Clean Mono where the action is black / white.
  final Color cta;
  final Color onCta;
  final Color cardColor;
  final Color cardBorder;

  /// Translucent cards over a tinted ground (Soft Glass).
  final bool glass;

  /// Rows separated by 1px lines instead of cards (Clean Mono).
  final bool hairlines;

  /// Bottom bar drawn as a floating pill (Soft Glass).
  final bool floatingNav;
  final Color navBackground;
  final Color navActive;
  final Color navInactive;

  /// Glowing dot under the active tab (Dark Neon).
  final bool navGlow;

  /// Dark header block colour (Bold Brand), null for the others.
  final Color? hero;
  final Color onHero;
  final Color success;
  final Color warning;
  final Color danger;

  static AppStyleTokens of(BuildContext context) =>
      Theme.of(context).extension<AppStyleTokens>() ??
      AppTheme.tokens(AppStyle.darkNeon, Theme.of(context).brightness);

  @override
  AppStyleTokens copyWith({Color? accent}) => AppStyleTokens(
        style: style,
        radius: radius,
        accent: accent ?? this.accent,
        onAccent: onAccent,
        cta: cta,
        onCta: onCta,
        cardColor: cardColor,
        cardBorder: cardBorder,
        glass: glass,
        hairlines: hairlines,
        floatingNav: floatingNav,
        navBackground: navBackground,
        navActive: navActive,
        navInactive: navInactive,
        navGlow: navGlow,
        hero: hero,
        onHero: onHero,
        success: success,
        warning: warning,
        danger: danger,
      );

  @override
  AppStyleTokens lerp(ThemeExtension<AppStyleTokens>? other, double t) {
    if (other is! AppStyleTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// Builds Material 3 themes for every [AppStyle] × brightness.
class AppTheme {
  const AppTheme._();

  /// Brand red (the "elite" part of the logo).
  static const Color brandRed = Color(0xFFE53935);

  static ThemeData light([AppStyle style = AppStyle.darkNeon]) =>
      build(style, Brightness.light);

  static ThemeData dark([AppStyle style = AppStyle.darkNeon]) =>
      build(style, Brightness.dark);

  static AppStyleTokens tokens(AppStyle style, Brightness b) {
    final p = paletteFor(style, b);
    final dark = b == Brightness.dark;
    return AppStyleTokens(
      style: style,
      radius: style.radius,
      accent: p.accent,
      onAccent: p.onAccent,
      cta: p.cta ?? p.accent,
      onCta: p.onCta ?? p.onAccent,
      cardColor: style == AppStyle.softGlass
          ? p.card.withValues(alpha: dark ? 0.72 : 0.7)
          : p.card,
      cardBorder: style == AppStyle.softGlass
          ? p.border.withValues(alpha: dark ? 0.6 : 0.9)
          : p.border,
      glass: style == AppStyle.softGlass,
      hairlines: style == AppStyle.cleanMono,
      floatingNav: style == AppStyle.softGlass,
      navBackground: p.navBg,
      navActive: p.navActive,
      navInactive: p.navInactive,
      navGlow: style == AppStyle.darkNeon,
      hero: p.hero,
      onHero: p.onHero,
      success: dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      warning: dark ? const Color(0xFFFFB86B) : const Color(0xFFB45309),
      danger: dark ? const Color(0xFFFF7B7B) : const Color(0xFFC62828),
    );
  }

  static ThemeData build(AppStyle style, Brightness brightness) {
    final p = paletteFor(style, brightness);
    final t = tokens(style, brightness);
    final isDark = brightness == Brightness.dark;
    final r = t.radius;

    final scheme = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
    ).copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accent.withValues(alpha: isDark ? 0.22 : 0.14),
      onPrimaryContainer: isDark ? p.text : p.accent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      surface: p.bg,
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      outline: p.border,
      outlineVariant: p.border,
      surfaceContainerLowest: p.card,
      surfaceContainerLow: p.bg,
      surfaceContainer: p.card,
      surfaceContainerHigh: p.card,
      surfaceContainerHighest: p.alt,
      error: t.danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: style.fontFamily,
    );

    final heroBar = p.hero;
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r),
      side: BorderSide(color: t.cardBorder),
    );
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r - 4));

    return base.copyWith(
      extensions: [t],
      scaffoldBackgroundColor: p.bg,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: heroBar == null ? 2 : 0,
        backgroundColor: heroBar ?? p.bg,
        foregroundColor: heroBar == null ? p.text : p.onHero,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: style.displayFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: heroBar == null ? p.text : p.onHero,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: style == AppStyle.boldBrand && !isDark ? 3 : 0,
        shadowColor: const Color(0xFF1B2340).withValues(alpha: 0.18),
        color: t.cardColor,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.alt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r - 4),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r - 4),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r - 4),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: p.muted),
        labelStyle: TextStyle(color: p.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.cta,
          foregroundColor: t.onCta,
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: buttonShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: p.border),
          shape: buttonShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          shape: buttonShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.cta,
        foregroundColor: t.onCta,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            style == AppStyle.darkNeon || style == AppStyle.cleanMono ? 999 : r,
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: style == AppStyle.softGlass ? p.bg : p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(r)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.alt,
        selectedColor: p.accent.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: p.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: p.border),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: p.muted,
      ),
      dividerTheme: DividerThemeData(color: p.border, space: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.alt,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: p.accent.withValues(alpha: 0.2),
          selectedForegroundColor: p.text,
          foregroundColor: p.muted,
          side: BorderSide(color: p.border),
        ),
      ),
    );
  }
}
