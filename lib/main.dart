import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'app/theme.dart';
import 'app/theme_settings_controller.dart';
import 'l10n/language_controller.dart';
import 'l10n/strings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final language = ref.watch(languageProvider);
    // Controllers read S.current; the key below rebuilds every widget when
    // the language changes so no screen keeps stale text.
    S.current = S.forLanguage(language);

    return MaterialApp(
      key: ValueKey(language),
      debugShowCheckedModeBanner: false,
      title: 'elite SMS',
      theme: AppTheme.build(settings.style, Brightness.light),
      darkTheme: AppTheme.build(settings.style, Brightness.dark),
      themeMode: settings.mode,
      locale: language.materialLocale,
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}
