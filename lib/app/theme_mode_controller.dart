import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / system theme choice, persisted across restarts.
class ThemeModeController extends Notifier<ThemeMode> {
  static const String storageKey = 'theme_mode';

  bool _disposed = false;

  @override
  ThemeMode build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(storageKey);
      if (stored == null || _disposed) return;
      state = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Keep the default; a missing preference is not an error.
    }
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, mode.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
