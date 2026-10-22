import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/domain/group_source.dart';
import 'package:sms_sender_app/features/groups/domain/sms_group.dart';
import 'package:sms_sender_app/l10n/strings.dart';
import 'package:sms_sender_app/shared/providers/app_providers.dart';

/// User flows shared by the groups list, the send tab and the group detail
/// page: confirmation dialogs, controller calls and result snackbars.
class GroupActions {
  GroupActions(this.context, this.ref, {this.source = GroupSource.excel});

  final BuildContext context;
  final WidgetRef ref;
  final GroupSource source;

  S get _s => S.of(context);

  Future<void> sendGroup(SmsGroup group) async {
    final message = _message();
    if (message == null) return;

    // Captured before the first await: the container outlives this widget,
    // so a long send keeps reporting even if the page is popped meanwhile.
    final container = ProviderScope.containerOf(context, listen: false);
    final info = SmsMessageInfo.analyze(message);
    final remaining = group.counters.remaining;
    final wasSending = container.read(groupsControllerProvider(source)).isSending;
    final confirmed = await _confirm(
      title: wasSending
          ? _s.queueGroupTitle(group.title)
          : _s.sendGroupTitle(group.title),
      message: '${_s.willSend(remaining)}${_partsSuffix(info)}.'
          '${_costLine(remaining, info)}',
      confirmLabel: wasSending ? _s.toQueue : _s.send,
    );
    if (!confirmed) return;

    final started = await container
        .read(groupsControllerProvider(source).notifier)
        .sendGroup(group.id, message: message, delay: _delay());
    if (!started) {
      _snack(_s.groupAlreadyQueued(group.title));
      return;
    }
    if (wasSending) {
      _snack(_s.groupQueued(group.title));
      return;
    }

    await _saveHistory(container, message);
    final updated =
        container.read(groupsControllerProvider(source)).groupById(group.id);
    if (updated != null) {
      _snack(
        _s.groupSentReport(
          updated.title,
          updated.counters.sent,
          updated.counters.total,
        ),
      );
    }
  }

  Future<void> sendAll() async {
    final message = _message();
    if (message == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final state = ref.read(groupsControllerProvider(source));
    final info = SmsMessageInfo.analyze(message);
    final wasSending = state.isSending;
    final confirmed = await _confirm(
      title: wasSending ? _s.queueAllTitle : _s.sendAllTitle,
      message: '${_s.groupsAndSms(state.pendingGroupsCount, state.totals.remaining)}'
          '${_partsSuffix(info)}.${_costLine(state.totals.remaining, info)}',
      confirmLabel: wasSending ? _s.toQueue : _s.sendAllConfirm,
    );
    if (!confirmed) return;

    final started = await container
        .read(groupsControllerProvider(source).notifier)
        .sendAllPending(message: message, delay: _delay());
    if (!started) {
      _snack(_s.nothingToSend);
      return;
    }
    if (wasSending) {
      _snack(_s.groupsQueued);
      return;
    }

    await _saveHistory(container, message);
    final totals = container.read(groupsControllerProvider(source)).totals;
    _snack(_s.doneReport(totals.sent, totals.total));
  }

  /// Sends the ticked groups (queued behind a running send).
  Future<void> sendSelected() async {
    final message = _message();
    if (message == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final state = ref.read(groupsControllerProvider(source));
    final selected = state.selectedSendable;
    if (selected.isEmpty) {
      _snack(_s.selectedNothing);
      return;
    }
    final info = SmsMessageInfo.analyze(message);
    final smsCount = selected.fold<int>(0, (n, g) => n + g.counters.remaining);
    final wasSending = state.isSending;
    final confirmed = await _confirm(
      title: _s.sendSelectedTitle(selected.length),
      message: '${selected.map((g) => g.title).join(', ')}.\n'
          '${_s.smsLine(smsCount)}${_partsSuffix(info)}.${_costLine(smsCount, info)}',
      confirmLabel: wasSending ? _s.toQueue : _s.send,
    );
    if (!confirmed) return;

    final started = await container
        .read(groupsControllerProvider(source).notifier)
        .sendSelected(message: message, delay: _delay());
    if (!started) {
      _snack(_s.alreadyQueued);
      return;
    }
    if (wasSending) {
      _snack(_s.groupsQueued);
      return;
    }

    await _saveHistory(container, message);
    final totals = container.read(groupsControllerProvider(source)).totals;
    _snack(_s.doneReport(totals.sent, totals.total));
  }

  void stop() => ref.read(groupsControllerProvider(source).notifier).stop();

  void resumeNow() =>
      ref.read(groupsControllerProvider(source).notifier).resumeNow();

  void dequeue(SmsGroup group) {
    ref.read(groupsControllerProvider(source).notifier).dequeue(group.id);
    _snack(_s.removedFromQueue(group.title));
  }

  /// Dialog with the group name; empty restores the default letter name.
  Future<void> rename(SmsGroup group) async {
    final controller = TextEditingController(text: group.name ?? '');
    final result = await showDialog<_RenameResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_s.renameTitle(group.defaultTitle)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: group.defaultTitle),
          onSubmitted: (_) =>
              Navigator.pop(ctx, _RenameResult(controller.text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, const _RenameResult(null)),
            child: Text(_s.byDefault),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _RenameResult(controller.text)),
            child: Text(_s.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) return;
    await ref
        .read(groupsControllerProvider(source).notifier)
        .renameGroup(group.id, result.name);
  }

  Future<void> resetGroup(SmsGroup group) async {
    final confirmed = await _confirm(
      title: _s.resetGroupTitle(group.title),
      message: _s.resetGroupBody,
      confirmLabel: _s.reset,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref
        .read(groupsControllerProvider(source).notifier)
        .resetGroup(group.id);
    _snack(_s.groupResetDone(group.title));
  }

  Future<void> resetAll() async {
    final confirmed = await _confirm(
      title: _s.resetAllTitle,
      message: _s.resetAllBody,
      confirmLabel: _s.reset,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(groupsControllerProvider(source).notifier).resetAll();
    _snack(_s.resetAllDone);
  }

  Future<void> removeGroup(SmsGroup group) async {
    final confirmed = await _confirm(
      title: _s.deleteGroupTitle(group.title),
      message: _s.deleteGroupBody(group.total),
      confirmLabel: _s.delete,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref
        .read(groupsControllerProvider(source).notifier)
        .removeGroup(group.id);
    _snack(_s.groupDeleted(group.title));
  }

  Future<void> clearAll() async {
    final confirmed = await _confirm(
      title: _s.deleteAllGroupsTitle,
      message: _s.deleteAllGroupsBody,
      confirmLabel: _s.deleteAll,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(groupsControllerProvider(source).notifier).clearAll();
    _snack(_s.allGroupsDeleted);
  }

  // --------------------------------------------------------------- helpers

  String? _message() {
    final text = ref.read(messageControllerProvider).text.trim();
    if (text.isEmpty) {
      _snack(_s.enterMessage);
      return null;
    }
    return text;
  }

  Duration _delay() => Duration(milliseconds: ref.read(sendDelayProvider));

  String _partsSuffix(SmsMessageInfo info) =>
      info.isMultipart ? _s.partsSuffix(info.parts) : '';

  /// `\nCost ≈ 1,00 TMT · balance 12,30 TMT` (+ a warning when short).
  String _costLine(int smsCount, SmsMessageInfo info) {
    final balance = ref.read(balanceProvider);
    final parts = info.parts == 0 ? 1 : info.parts;
    final cost = balance.cost(smsCount, parts);
    final buffer = StringBuffer(_s.costLine(formatManat(cost)));
    final known = balance.balance;
    if (known != null) {
      buffer.write(_s.balanceSuffix(formatManat(known)));
      if (known < cost) buffer.write(_s.balanceMayBeShort);
    }
    return buffer.toString();
  }

  Future<void> _saveHistory(ProviderContainer container, String message) async {
    try {
      await container.read(apiServiceProvider).insertMessage(message);
    } catch (error) {
      debugPrint('GroupActions: could not save message history: $error');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_s.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _snack(String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _RenameResult {
  const _RenameResult(this.name);

  final String? name;
}
