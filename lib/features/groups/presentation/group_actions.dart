import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/domain/sms_group.dart';
import 'package:sms_sender_app/shared/providers/app_providers.dart';

/// User flows shared by the groups list and the group detail page:
/// confirmation dialogs, controller calls and result snackbars.
class GroupActions {
  GroupActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  Future<void> sendGroup(SmsGroup group) async {
    final message = _message();
    if (message == null) return;

    // Captured before the first await: the container outlives this widget,
    // so a long send keeps reporting even if the page is popped meanwhile.
    final container = ProviderScope.containerOf(context, listen: false);
    final info = SmsMessageInfo.analyze(message);
    final remaining = group.counters.remaining;
    final wasSending = container.read(groupsControllerProvider).isSending;
    final confirmed = await _confirm(
      title: wasSending
          ? 'Добавить ${group.title} в очередь?'
          : 'Отправить ${group.title}?',
      message: 'Будет отправлено $remaining SMS${_partsSuffix(info)}.'
          '${_costLine(remaining, info)}',
      confirmLabel: wasSending ? 'В очередь' : 'Отправить',
    );
    if (!confirmed) return;

    final started = await container
        .read(groupsControllerProvider.notifier)
        .sendGroup(group.id, message: message, delay: _delay());
    if (!started) {
      _snack('${group.title} уже в очереди или отправляется');
      return;
    }
    if (wasSending) {
      _snack('${group.title} добавлена в очередь');
      return;
    }

    await _saveHistory(container, message);
    final updated = container.read(groupsControllerProvider).groupById(group.id);
    if (updated != null) {
      _snack(
        '${updated.title}: отправлено ${updated.counters.sent} '
        'из ${updated.counters.total}',
      );
    }
  }

  Future<void> sendAll() async {
    final message = _message();
    if (message == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final state = ref.read(groupsControllerProvider);
    final info = SmsMessageInfo.analyze(message);
    final wasSending = state.isSending;
    final confirmed = await _confirm(
      title: wasSending ? 'Поставить все группы в очередь?' : 'Отправить все группы?',
      message: 'Групп: ${state.pendingGroupsCount}, '
          'SMS: ${state.totals.remaining}${_partsSuffix(info)}.'
          '${_costLine(state.totals.remaining, info)}',
      confirmLabel: wasSending ? 'В очередь' : 'Отправить все',
    );
    if (!confirmed) return;

    final started = await container
        .read(groupsControllerProvider.notifier)
        .sendAllPending(message: message, delay: _delay());
    if (!started) {
      _snack('Нечего отправлять');
      return;
    }
    if (wasSending) {
      _snack('Группы добавлены в очередь');
      return;
    }

    await _saveHistory(container, message);
    final totals = container.read(groupsControllerProvider).totals;
    _snack('Готово: отправлено ${totals.sent} из ${totals.total}');
  }

  /// Sends the ticked groups (queued behind a running send).
  Future<void> sendSelected() async {
    final message = _message();
    if (message == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final state = ref.read(groupsControllerProvider);
    final selected = state.selectedSendable;
    if (selected.isEmpty) {
      _snack('В выбранных группах нечего отправлять');
      return;
    }
    final info = SmsMessageInfo.analyze(message);
    final smsCount = selected.fold<int>(0, (n, g) => n + g.counters.remaining);
    final wasSending = state.isSending;
    final confirmed = await _confirm(
      title: 'Отправить выбранные (${selected.length})?',
      message: '${selected.map((g) => g.title).join(', ')}.\n'
          'SMS: $smsCount${_partsSuffix(info)}.${_costLine(smsCount, info)}',
      confirmLabel: wasSending ? 'В очередь' : 'Отправить',
    );
    if (!confirmed) return;

    final started = await container
        .read(groupsControllerProvider.notifier)
        .sendSelected(message: message, delay: _delay());
    if (!started) {
      _snack('Группы уже в очереди');
      return;
    }
    if (wasSending) {
      _snack('Группы добавлены в очередь');
      return;
    }

    await _saveHistory(container, message);
    final totals = container.read(groupsControllerProvider).totals;
    _snack('Готово: отправлено ${totals.sent} из ${totals.total}');
  }

  void stop() => ref.read(groupsControllerProvider.notifier).stop();

  void dequeue(SmsGroup group) {
    ref.read(groupsControllerProvider.notifier).dequeue(group.id);
    _snack('${group.title} убрана из очереди');
  }

  /// Dialog with the group name; empty restores "Группа A".
  Future<void> rename(SmsGroup group) async {
    final controller = TextEditingController(text: group.name ?? '');
    final result = await showDialog<_RenameResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Название · ${group.defaultTitle}'),
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
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, const _RenameResult(null)),
            child: const Text('По умолчанию'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _RenameResult(controller.text)),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) return;
    await ref
        .read(groupsControllerProvider.notifier)
        .renameGroup(group.id, result.name);
  }

  Future<void> resetGroup(SmsGroup group) async {
    final confirmed = await _confirm(
      title: 'Сбросить ${group.title}?',
      message: 'Статусы отправки будут очищены, номера останутся.',
      confirmLabel: 'Сбросить',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(groupsControllerProvider.notifier).resetGroup(group.id);
    _snack('${group.title} сброшена');
  }

  Future<void> resetAll() async {
    final confirmed = await _confirm(
      title: 'Сбросить все группы?',
      message: 'Статусы отправки всех групп будут очищены, номера останутся.',
      confirmLabel: 'Сбросить',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(groupsControllerProvider.notifier).resetAll();
    _snack('Статусы всех групп сброшены');
  }

  Future<void> removeGroup(SmsGroup group) async {
    final confirmed = await _confirm(
      title: 'Удалить ${group.title}?',
      message: 'Номера группы (${group.total}) будут удалены из списка.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(groupsControllerProvider.notifier).removeGroup(group.id);
    _snack('${group.title} удалена');
  }

  Future<void> clearAll() async {
    final confirmed = await _confirm(
      title: 'Удалить все группы?',
      message: 'Все группы и номера будут удалены. Это действие нельзя отменить.',
      confirmLabel: 'Удалить всё',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(groupsControllerProvider.notifier).clearAll();
    _snack('Все группы удалены');
  }

  // --------------------------------------------------------------- helpers

  String? _message() {
    final text = ref.read(messageControllerProvider).text.trim();
    if (text.isEmpty) {
      _snack('Введите текст сообщения');
      return null;
    }
    return text;
  }

  Duration _delay() => Duration(milliseconds: ref.read(sendDelayProvider));

  static String _partsSuffix(SmsMessageInfo info) =>
      info.isMultipart ? ' (каждое из ${info.parts} частей)' : '';

  /// `\nСтоимость ≈ 1,00 TMT · баланс 12,30 TMT` (+ a warning when short).
  String _costLine(int smsCount, SmsMessageInfo info) {
    final balance = ref.read(balanceProvider);
    final parts = info.parts == 0 ? 1 : info.parts;
    final cost = balance.cost(smsCount, parts);
    final buffer = StringBuffer('\nСтоимость ≈ ${formatManat(cost)}');
    final known = balance.balance;
    if (known != null) {
      buffer.write(' · баланс ${formatManat(known)}');
      if (known < cost) buffer.write('\nБаланса может не хватить!');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
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
