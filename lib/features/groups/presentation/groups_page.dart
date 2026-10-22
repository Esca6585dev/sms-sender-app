import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/app_shell.dart' show ShellMenuButton;
import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/application/groups_state.dart';
import 'package:sms_sender_app/features/groups/domain/group_source.dart';
import 'package:sms_sender_app/features/groups/presentation/group_actions.dart';
import 'package:sms_sender_app/features/groups/presentation/group_detail_page.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/group_card.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/groups_summary_panel.dart';
import 'package:sms_sender_app/l10n/strings.dart';
import 'package:sms_sender_app/shared/providers/app_providers.dart';
import 'package:sms_sender_app/shared/widgets/message_composer.dart';

enum _PageAction { resetAll, clearAll }

enum _ImportMode { append, replace }

/// Excel groups: import, per-group send/reset, queue, global progress and the
/// shared message composer. Everything scrolls as one list.
class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  static const GroupSource _source = GroupSource.excel;

  bool _errorDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    ref.listen<String?>(
      groupsControllerProvider(_source).select((st) => st.errorMessage),
      (previous, next) {
        if (next != null && next != previous) _showError(next);
      },
    );

    final state = ref.watch(groupsControllerProvider(_source));
    final messageController = ref.watch(messageControllerProvider);
    final delayMs = ref.watch(sendDelayProvider);
    final balance = ref.watch(balanceProvider);
    final parts = SmsMessageInfo.analyze(messageController.text).parts;
    final partsForCost = parts == 0 ? 1 : parts;
    final actions = GroupActions(context, ref, source: _source);
    final notifier = ref.read(groupsControllerProvider(_source).notifier);

    return Scaffold(
      appBar: state.hasSelection
          ? AppBar(
              leading: IconButton(
                tooltip: s.clearSelection,
                icon: const Icon(Icons.close),
                onPressed: notifier.clearSelection,
              ),
              title: Text(s.selected(state.selectedIds.length)),
              actions: [
                IconButton(
                  tooltip: s.selectAll,
                  icon: const Icon(Icons.select_all),
                  onPressed: notifier.selectAllPending,
                ),
                IconButton(
                  tooltip: s.sendSelected,
                  icon: const Icon(Icons.send),
                  onPressed: state.isImporting ? null : actions.sendSelected,
                ),
              ],
            )
          : AppBar(
              leading: const ShellMenuButton(),
              title: Text(s.groupsTitle),
              actions: [
                IconButton(
                  tooltip: s.importExcel,
                  icon: const Icon(Icons.upload_file),
                  onPressed: state.isBusy ? null : _importExcel,
                ),
                PopupMenuButton<_PageAction>(
                  enabled: !state.isBusy && !state.isEmpty,
                  tooltip: s.reset,
                  onSelected: (action) => _onPageAction(action, actions),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _PageAction.resetAll,
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.restart_alt),
                        title: Text(s.resetAllStatuses),
                      ),
                    ),
                    PopupMenuItem(
                      value: _PageAction.clearAll,
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.delete_sweep,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(s.deleteAllGroups),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: MessageComposer(
                      controller: messageController,
                      enabled: !state.isSending,
                    ),
                  ),
                ),
              ),
            ),
            if (state.isImporting)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 6),
                      Text(
                        s.importing,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!state.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: GroupsSummaryPanel(
                    state: state,
                    delayMs: delayMs,
                    onDelayChanged: (ms) =>
                        ref.read(sendDelayProvider.notifier).select(ms),
                    onSendAll: actions.sendAll,
                    onStop: actions.stop,
                    onResumeNow: actions.resumeNow,
                    balance: balance,
                    onCheckBalance: () =>
                        ref.read(balanceProvider.notifier).checkViaSms(),
                    onDequeue: (id) {
                      final group = state.groupById(id);
                      if (group != null) actions.dequeue(group);
                    },
                  ),
                ),
              ),
            _buildBody(state, actions, balance, partsForCost),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    GroupsState state,
    GroupActions actions,
    BalanceState balance,
    int partsForCost,
  ) {
    if (state.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyGroups(onImport: state.isBusy ? null : _importExcel),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
      sliver: SliverList.builder(
        itemCount: state.groups.length,
        itemBuilder: (context, index) {
          final group = state.groups[index];
          final c = group.counters;
          return GroupCard(
            key: ValueKey(group.id),
            group: group,
            isActive: state.activeGroupId == group.id,
            actionsEnabled: !state.isImporting,
            queuePosition: state.queuePosition(group.id),
            selectionMode: state.hasSelection,
            selected: state.isSelected(group.id),
            onToggleSelected: () => ref
                .read(groupsControllerProvider(_source).notifier)
                .toggleSelected(group.id),
            onDequeue: () => actions.dequeue(group),
            onRename: () => actions.rename(group),
            costLabel: c.remaining > 0
                ? '≈ ${formatManat(balance.cost(c.remaining, partsForCost))}'
                : null,
            onSend: () => actions.sendGroup(group),
            onReset: () => actions.resetGroup(group),
            onRemove: () => actions.removeGroup(group),
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    GroupDetailPage(groupId: group.id, source: _source),
              ),
            ),
          );
        },
      ),
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
    final s = S.of(context);
    final state = ref.read(groupsControllerProvider(_source));
    var replace = false;

    if (!state.isEmpty) {
      final choice = await showDialog<_ImportMode>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(s.groupsExist),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, _ImportMode.append),
              child: ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(s.importAppend),
                subtitle: Text(s.importAppendHint),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, _ImportMode.replace),
              child: ListTile(
                leading: Icon(
                  Icons.refresh,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(s.importReplace),
                subtitle: Text(s.importReplaceHint),
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
      _snack('${s.fileReadError}: $error');
      return;
    }
    if (!mounted) return;

    try {
      final summary = await ref
          .read(groupsControllerProvider(_source).notifier)
          .importFromBytes(bytes, replace: replace);
      _snack(summary.describe());
    } catch (error) {
      _snack(s.importError(error));
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
      final s = S.of(context);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Theme.of(ctx).colorScheme.error),
              const SizedBox(width: 10),
              Expanded(child: Text(s.sendStopped)),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.understood),
            ),
          ],
        ),
      );
      _errorDialogOpen = false;
      if (mounted) {
        ref.read(groupsControllerProvider(_source).notifier).dismissError();
      }
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
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_work_outlined, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              s.groupsEmptyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              s.groupsEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: Text(s.importExcel),
            ),
          ],
        ),
      ),
    );
  }
}
