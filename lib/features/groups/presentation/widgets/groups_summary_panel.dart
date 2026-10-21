import 'package:flutter/material.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/application/groups_state.dart';

/// Totals over all groups, balance line, send queue, delay selector and the
/// global send/stop buttons.
class GroupsSummaryPanel extends StatelessWidget {
  const GroupsSummaryPanel({
    super.key,
    required this.state,
    required this.delayMs,
    required this.onDelayChanged,
    required this.onSendAll,
    required this.onStop,
    this.balance,
    this.onCheckBalance,
    this.onDequeue,
  });

  final GroupsState state;
  final int delayMs;
  final ValueChanged<int> onDelayChanged;
  final VoidCallback onSendAll;
  final VoidCallback onStop;
  final BalanceState? balance;
  final VoidCallback? onCheckBalance;
  final ValueChanged<String>? onDequeue;

  static String delayLabel(int ms) => switch (ms) {
        0 => 'Без задержки',
        500 => '0.5 сек',
        1000 => '1 сек',
        2000 => '2 сек',
        _ => '$ms мс',
      };

  @override
  Widget build(BuildContext context) {
    final totals = state.totals;
    final pendingGroups = state.pendingGroupsCount;
    final active = state.activeGroup;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Групп: ${state.groups.length}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Номеров: ${totals.total}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: totals.progress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Stat('Отправлено', totals.sent, Colors.green),
                _Stat('Осталось', totals.remaining, Colors.orange.shade800),
                _Stat('Ошибок', totals.failed, Colors.red),
              ],
            ),
            if (active != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Отправка: ${active.title} · '
                  '${active.counters.sent} / ${active.counters.total}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppStyleTokens.of(context).accent,
                  ),
                ),
              ),
            if (state.queue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Очередь:', style: TextStyle(fontSize: 12)),
                    for (var i = 0; i < state.queue.length; i++)
                      InputChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${i + 1}. ${state.groupById(state.queue[i])?.title ?? '?'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: onDequeue == null
                            ? null
                            : () => onDequeue!(state.queue[i]),
                      ),
                  ],
                ),
              ),
            if (balance != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        balance!.balance == null
                            ? 'Баланс неизвестен'
                            : 'Баланс ${formatManat(balance!.balance!)}'
                                '${balance!.affordableSms != null ? ' · ≈ ${balance!.affordableSms} SMS' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (onCheckBalance != null)
                      TextButton(
                        onPressed: balance!.isChecking ? null : onCheckBalance,
                        child: Text(balance!.isChecking ? 'Ждём…' : 'Проверить'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Задержка:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final ms in SendDelayController.options)
                        ChoiceChip(
                          label: Text(
                            delayLabel(ms),
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: delayMs == ms,
                          visualDensity: VisualDensity.compact,
                          onSelected: state.isSending
                              ? null
                              : (_) => onDelayChanged(ms),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.isImporting || pendingGroups == 0
                        ? null
                        : onSendAll,
                    icon: Icon(state.isSending ? Icons.playlist_add : Icons.send),
                    label: Text(
                      state.isSending
                          ? 'Все в очередь ($pendingGroups)'
                          : 'Отправить все ($pendingGroups)',
                    ),
                  ),
                ),
                if (state.isSending) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: state.stopRequested ? null : onStop,
                    icon: const Icon(Icons.stop_circle),
                    label: Text(state.stopRequested ? 'Останавливаем…' : 'Стоп'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: value > 0 ? color : Colors.grey,
          ),
        ),
      ],
    );
  }
}
