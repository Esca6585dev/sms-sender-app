import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sms_sender_app/l10n/strings.dart';

/// UI language, persisted across restarts. Default: Russian.
class LanguageController extends Notifier<AppLanguage> {
  static const String storageKey = 'app_language';

  bool _disposed = false;

  @override
  AppLanguage build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _restore();
    return AppLanguage.ru;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(storageKey);
      if (stored == null || _disposed) return;
      state = AppLanguage.fromName(stored);
    } catch (_) {
      // Keep the default.
    }
  }

  Future<void> select(AppLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, language.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}

final languageProvider =
    NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);
