import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/core/sms/sms_message_info.dart';
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
    final confirmed = await _confirm(
      title: 'Отправить ${group.title}?',
      message: 'Будет отправлено $remaining SMS${_partsSuffix(info)}.',
      confirmLabel: 'Отправить',
    );
    if (!confirmed) return;

    final started = await container
        .read(groupsControllerProvider.notifier)
        .sendGroup(group.id, message: message, delay: _delay());
    if (!started) {
      _snack('Отправка уже выполняется');
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
    final confirmed = await _confirm(
      title: 'Отправить все группы?',
      message: 'Групп: ${state.pendingGroupsCount}, '
          'SMS: ${state.totals.remaining}${_partsSuffix(info)}.',
      confirmLabel: 'Отправить все',
    );
    if (!confirmed) return;

    final started = await container
        .read(groupsControllerProvider.notifier)
        .sendAllPending(message: message, delay: _delay());
    if (!started) {
      _snack('Отправка уже выполняется');
      return;
    }

    await _saveHistory(container, message);
    final totals = container.read(groupsControllerProvider).totals;
    _snack('Готово: отправлено ${totals.sent} из ${totals.total}');
  }

  void stop() => ref.read(groupsControllerProvider.notifier).stop();

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
