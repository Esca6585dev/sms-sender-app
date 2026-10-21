import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/app_shell.dart' show ShellMenuButton;
import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/application/groups_state.dart';
import 'package:sms_sender_app/features/groups/presentation/group_actions.dart';
import 'package:sms_sender_app/features/groups/presentation/group_detail_page.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/group_card.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/groups_summary_panel.dart';
import 'package:sms_sender_app/shared/providers/app_providers.dart';
import 'package:sms_sender_app/shared/widgets/message_composer.dart';

enum _PageAction { resetAll, clearAll }

enum _ImportMode { append, replace }

/// List of groups created from an Excel import, with per-group send/reset,
/// global progress and the shared message composer.
class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  bool _errorDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      groupsControllerProvider.select((s) => s.errorMessage),
      (previous, next) {
        if (next != null && next != previous) _showError(next);
      },
    );

    final state = ref.watch(groupsControllerProvider);
    final messageController = ref.watch(messageControllerProvider);
    final delayMs = ref.watch(sendDelayProvider);
    final actions = GroupActions(context, ref);

    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text('Группы рассылки'),
        actions: [
          IconButton(
            tooltip: 'Импорт из Excel',
            icon: const Icon(Icons.upload_file),
            onPressed: state.isBusy ? null : _importExcel,
          ),
          PopupMenuButton<_PageAction>(
            enabled: !state.isBusy && !state.isEmpty,
            tooltip: 'Сброс',
            onSelected: (action) => _onPageAction(action, actions),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _PageAction.resetAll,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.restart_alt),
                  title: Text('Сбросить статусы всех групп'),
                ),
              ),
              PopupMenuItem(
                value: _PageAction.clearAll,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text('Удалить все группы'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: MessageComposer(
                    controller: messageController,
                    enabled: !state.isSending,
                  ),
                ),
              ),
            ),
            if (state.isImporting)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 6),
                    Text('Импорт Excel…', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            if (!state.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: GroupsSummaryPanel(
                  state: state,
                  delayMs: delayMs,
                  onDelayChanged: (ms) =>
                      ref.read(sendDelayProvider.notifier).select(ms),
                  onSendAll: actions.sendAll,
                  onStop: actions.stop,
                ),
              ),
            Expanded(child: _buildBody(state, actions)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(GroupsState state, GroupActions actions) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isEmpty) {
      return _EmptyGroups(onImport: state.isBusy ? null : _importExcel);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      itemCount: state.groups.length,
      itemBuilder: (context, index) {
        final group = state.groups[index];
        return GroupCard(
          key: ValueKey(group.id),
          group: group,
          isActive: state.activeGroupId == group.id,
          actionsEnabled: !state.isBusy,
          onSend: () => actions.sendGroup(group),
          onReset: () => actions.resetGroup(group),
          onRemove: () => actions.removeGroup(group),
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => GroupDetailPage(groupId: group.id),
            ),
          ),
        );
      },
    );
  }

  void _onPageAction(_PageAction action, GroupActions actions) {
    switch (action) {
      case _PageAction.resetAll:
        actions.resetAll();
      case _PageAction.clearAll:
        actions.clearAll();
    }
  }

  Future<void> _importExcel() async {
    final state = ref.read(groupsControllerProvider);
    var replace = false;

    if (!state.isEmpty) {
      final choice = await showDialog<_ImportMode>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Уже есть группы'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, _ImportMode.append),
              child: const ListTile(
                leading: Icon(Icons.playlist_add),
                title: Text('Добавить к существующим'),
                subtitle: Text('Новые группы продолжат нумерацию'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, _ImportMode.replace),
              child: const ListTile(
                leading: Icon(Icons.refresh, color: Colors.red),
                title: Text('Заменить'),
                subtitle: Text('Текущие группы будут удалены'),
              ),
            ),
          ],
        ),
      );
      if (choice == null) return;
      replace = choice == _ImportMode.replace;
    }

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (picked.isEmpty) return;

    final file = picked.first;
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (error) {
      if (!mounted) return;
      _snack('Не удалось прочитать файл: $error');
      return;
    }
    if (!mounted) return;

    try {
      final summary = await ref
          .read(groupsControllerProvider.notifier)
          .importFromBytes(bytes, replace: replace);
      _snack(summary.describe());
    } catch (error) {
      _snack('Ошибка импорта: $error');
    }
  }

  void _showError(String message) {
    if (_errorDialogOpen) return;
    _errorDialogOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _errorDialogOpen = false;
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Expanded(child: Text('Отправка остановлена')),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      _errorDialogOpen = false;
      if (mounted) ref.read(groupsControllerProvider.notifier).dismissError();
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.onImport});

  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_work_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Групп пока нет',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Импортируйте Excel-файл с номерами: они будут автоматически '
              'разбиты на группы по 100.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Импорт из Excel'),
            ),
          ],
        ),
      ),
    );
  }
}
