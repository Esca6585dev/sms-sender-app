import 'package:flutter/material.dart';

import 'package:sms_sender_app/app/theme.dart';

/// Raw colours of one style in one brightness. Consumed by [AppTheme.build].
class StylePalette {
  const StylePalette({
    required this.bg,
    required this.card,
    required this.alt,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.navBg,
    required this.navActive,
    required this.navInactive,
    this.cta,
    this.onCta,
    this.hero,
    this.onHero = Colors.white,
  });

  final Color bg;
  final Color card;
  final Color alt;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color navBg;
  final Color navActive;
  final Color navInactive;
  final Color? cta;
  final Color? onCta;
  final Color? hero;
  final Color onHero;
}

StylePalette paletteFor(AppStyle style, Brightness b) {
  final dark = b == Brightness.dark;
  switch (style) {
    case AppStyle.softGlass:
      return dark
          ? const StylePalette(
              bg: Color(0xFF12142A),
              card: Color(0xFF1E2140),
              alt: Color(0xFF2A2E52),
              border: Color(0xFF363A62),
              text: Color(0xFFECEEFF),
              muted: Color(0xFFA3A8C8),
              accent: Color(0xFF8B85FF),
              onAccent: Color(0xFF12142A),
              navBg: Color(0xFF1E2140),
              navActive: Color(0xFF8B85FF),
              navInactive: Color(0xFFA3A8C8),
            )
          : const StylePalette(
              bg: Color(0xFFEEF0FB),
              card: Color(0xFFFFFFFF),
              alt: Color(0xFFE3E6F6),
              border: Color(0xFFFFFFFF),
              text: Color(0xFF1B1F3B),
              muted: Color(0xFF5B6079),
              accent: Color(0xFF4F46E5),
              onAccent: Color(0xFFFFFFFF),
              navBg: Color(0xFFFFFFFF),
              navActive: Color(0xFF4F46E5),
              navInactive: Color(0xFF5B6079),
            );
    case AppStyle.boldBrand:
      return dark
          ? const StylePalette(
              bg: Color(0xFF0F1420),
              card: Color(0xFF1A2133),
              alt: Color(0xFF222A40),
              border: Color(0xFF2A3350),
              text: Color(0xFFEEF1FA),
              muted: Color(0xFFA6ADC8),
              accent: Color(0xFFFF5A54),
              onAccent: Color(0xFF0F1420),
              navBg: Color(0xFF141B2E),
              navActive: Color(0xFFFF8A80),
              navInactive: Color(0xFFAEB4D1),
              hero: Color(0xFF141B2E),
            )
          : const StylePalette(
              bg: Color(0xFFF3F4F9),
              card: Color(0xFFFFFFFF),
              alt: Color(0xFFF3F4F9),
              border: Color(0xFFE3E5EE),
              text: Color(0xFF141A33),
              muted: Color(0xFF5A6075),
              accent: Color(0xFFE53935),
              onAccent: Color(0xFFFFFFFF),
              navBg: Color(0xFF1B2340),
              navActive: Color(0xFFFF8A80),
              navInactive: Color(0xFFAEB4D1),
              hero: Color(0xFF1B2340),
            );
    case AppStyle.cleanMono:
      return dark
          ? const StylePalette(
              bg: Color(0xFF0B0B0F),
              card: Color(0xFF0B0B0F),
              alt: Color(0xFF17171C),
              border: Color(0xFF26262E),
              text: Color(0xFFF4F4F6),
              muted: Color(0xFF9EA0AE),
              accent: Color(0xFF6B93FF),
              onAccent: Color(0xFF0B0B0F),
              cta: Color(0xFFF4F4F6),
              onCta: Color(0xFF0B0B0F),
              navBg: Color(0xFF0B0B0F),
              navActive: Color(0xFF6B93FF),
              navInactive: Color(0xFF9EA0AE),
            )
          : const StylePalette(
              bg: Color(0xFFFFFFFF),
              card: Color(0xFFFFFFFF),
              alt: Color(0xFFF5F5F7),
              border: Color(0xFFE6E6EA),
              text: Color(0xFF0B0B0F),
              muted: Color(0xFF5C5E6B),
              accent: Color(0xFF2F6BFF),
              onAccent: Color(0xFFFFFFFF),
              cta: Color(0xFF0B0B0F),
              onCta: Color(0xFFFFFFFF),
              navBg: Color(0xFFFFFFFF),
              navActive: Color(0xFF2F6BFF),
              navInactive: Color(0xFF5C5E6B),
            );
    case AppStyle.darkNeon:
      return dark
          ? const StylePalette(
              bg: Color(0xFF0F1218),
              card: Color(0xFF171C26),
              alt: Color(0xFF1F2532),
              border: Color(0xFF252B38),
              text: Color(0xFFF2F4F8),
              muted: Color(0xFF9AA3B5),
              accent: Color(0xFF2DE2B0),
              onAccent: Color(0xFF0F1218),
              navBg: Color(0xFF11151D),
              navActive: Color(0xFF2DE2B0),
              navInactive: Color(0xFF9AA3B5),
            )
          : const StylePalette(
              bg: Color(0xFFF3F6F8),
              card: Color(0xFFFFFFFF),
              alt: Color(0xFFEAF0F3),
              border: Color(0xFFDCE3EA),
              text: Color(0xFF0F1218),
              muted: Color(0xFF5A6473),
              accent: Color(0xFF0B8A68),
              onAccent: Color(0xFFFFFFFF),
              navBg: Color(0xFFFFFFFF),
              navActive: Color(0xFF0B8A68),
              navInactive: Color(0xFF5A6473),
            );
  }
}
