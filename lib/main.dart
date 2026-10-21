import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'app/theme.dart';
import 'app/theme_settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'elite SMS',
      theme: AppTheme.build(settings.style, Brightness.light),
      darkTheme: AppTheme.build(settings.style, Brightness.dark),
      themeMode: settings.mode,
      home: const AppShell(),
    );
  }
}
