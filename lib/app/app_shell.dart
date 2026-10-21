import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/app_bottom_bar.dart';
import 'package:sms_sender_app/app/app_drawer.dart';
import 'package:sms_sender_app/features/groups/presentation/groups_page.dart';
import 'package:sms_sender_app/features/history/presentation/history_page.dart';
import 'package:sms_sender_app/features/send/send_page.dart';
import 'package:sms_sender_app/features/stats/stats_page.dart';

/// Top-level sections reachable from the bottom bar and the drawer.
enum AppTab { send, groups, history, stats }

extension AppTabPresentation on AppTab {
  String get label => switch (this) {
        AppTab.send => 'Рассылка',
        AppTab.groups => 'Группы',
        AppTab.history => 'История',
        AppTab.stats => 'Статистика',
      };

  IconData get icon => switch (this) {
        AppTab.send => Icons.send_outlined,
        AppTab.groups => Icons.group_work_outlined,
        AppTab.history => Icons.history_outlined,
        AppTab.stats => Icons.insights_outlined,
      };

  IconData get selectedIcon => switch (this) {
        AppTab.send => Icons.send,
        AppTab.groups => Icons.group_work,
        AppTab.history => Icons.history,
        AppTab.stats => Icons.insights,
      };
}

class AppTabController extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.send;

  void select(AppTab tab) => state = tab;
}

final appTabProvider =
    NotifierProvider<AppTabController, AppTab>(AppTabController.new);

/// Key of the shell scaffold so any page can open the drawer.
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Root screen: drawer + bottom navigation + one page per tab. Pages keep
/// their own app bars (and state) inside an [IndexedStack].
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(appTabProvider);

    return Scaffold(
      key: shellScaffoldKey,
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: tab.index,
        children: const [
          SendPage(),
          GroupsPage(),
          HistoryPage(),
          StatsPage(),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        current: tab,
        onSelected: (selected) =>
            ref.read(appTabProvider.notifier).select(selected),
      ),
    );
  }
}

/// Hamburger button for page app bars; opens the shell drawer.
class ShellMenuButton extends StatelessWidget {
  const ShellMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Меню',
      onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
    );
  }
}
