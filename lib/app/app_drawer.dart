import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/app_shell.dart';
import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/app/theme_settings_controller.dart';
import 'package:sms_sender_app/features/contacts/add_contact_page.dart';
import 'package:sms_sender_app/features/devices/devices_page.dart';
import 'package:sms_sender_app/features/history/presentation/server_messages_page.dart';

/// Burger menu: sections, secondary screens and the theme switch.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(appTabProvider);
    final settings = ref.watch(themeSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    void go(AppTab target) {
      ref.read(appTabProvider.notifier).select(target);
      Navigator.pop(context);
    }

    void push(Widget page) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const _DrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final t in AppTab.values)
                    ListTile(
                      leading: Icon(tab == t ? t.selectedIcon : t.icon),
                      title: Text(t.label),
                      selected: tab == t,
                      selectedTileColor: scheme.primaryContainer,
                      selectedColor: scheme.onPrimaryContainer,
                      onTap: () => go(t),
                    ),
                  const Divider(height: 20),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    title: const Text('Добавить номер'),
                    subtitle: const Text('Вручную, из контактов или Excel'),
                    onTap: () => push(const AddContactPage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.devices_outlined),
                    title: const Text('Устройства и баланс'),
                    subtitle: const Text('SIM, баланс, цена SMS, другие телефоны'),
                    onTap: () => push(const DevicesPage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('Тексты на сервере'),
                    subtitle: const Text('Сохранённые тексты сообщений'),
                    onTap: () => push(const ServerMessagesPage()),
                  ),
                  const Divider(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      'Дизайн',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final style in AppStyle.values)
                    ListTile(
                      dense: true,
                      leading: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.tokens(style, brightness).accent,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                      ),
                      title: Text(style.label),
                      subtitle: Text(style.description),
                      trailing: settings.style == style
                          ? Icon(Icons.check_circle, color: scheme.primary)
                          : null,
                      selected: settings.style == style,
                      onTap: () => ref
                          .read(themeSettingsProvider.notifier)
                          .selectStyle(style),
                    ),
                  const Divider(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Тема оформления',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Авто', maxLines: 1),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Светлая', maxLines: 1),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Тёмная', maxLines: 1),
                        ),
                      ],
                      selected: {settings.mode},
                      onSelectionChanged: (selection) => ref
                          .read(themeSettingsProvider.notifier)
                          .selectMode(selection.first),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'elite-elektronika · SMS-рассылка · v1.0.0',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/elite_logo.jpg',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'elite',
                        style: TextStyle(
                          color: AppTheme.brandRed,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: '-elektronika',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SMS-рассылка клиентам',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
