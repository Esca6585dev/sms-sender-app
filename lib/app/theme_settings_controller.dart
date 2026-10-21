import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sms_sender_app/app/theme.dart';

/// Design style + light/dark choice, persisted across restarts.
class ThemeSettings {
  const ThemeSettings({
    this.style = AppStyle.darkNeon,
    this.mode = ThemeMode.system,
  });

  final AppStyle style;
  final ThemeMode mode;

  ThemeSettings copyWith({AppStyle? style, ThemeMode? mode}) =>
      ThemeSettings(style: style ?? this.style, mode: mode ?? this.mode);
}

class ThemeSettingsController extends Notifier<ThemeSettings> {
  static const String styleKey = 'app_style';
  static const String modeKey = 'theme_mode';

  bool _disposed = false;

  @override
  ThemeSettings build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _restore();
    return const ThemeSettings();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      final style = prefs.getString(styleKey);
      final mode = prefs.getString(modeKey);
      state = ThemeSettings(
        style: style == null ? state.style : AppStyle.fromName(style),
        mode: mode == null
            ? state.mode
            : ThemeMode.values.firstWhere(
                (m) => m.name == mode,
                orElse: () => ThemeMode.system,
              ),
      );
    } catch (_) {
      // Defaults stay in place; a missing preference is not an error.
    }
  }

  Future<void> selectStyle(AppStyle style) async {
    state = state.copyWith(style: style);
    await _save(styleKey, style.name);
  }

  Future<void> selectMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _save(modeKey, mode.name);
  }

  Future<void> _save(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsController, ThemeSettings>(
  ThemeSettingsController.new,
);
