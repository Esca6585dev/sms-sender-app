import 'package:flutter/material.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/application/groups_state.dart';
import 'package:sms_sender_app/l10n/strings.dart';

/// Totals over all groups, balance line, send queue, SMS-limit pause,
/// delay selector and the global send/stop buttons.
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
    this.onResumeNow,
  });

  final GroupsState state;
  final int delayMs;
  final ValueChanged<int> onDelayChanged;
  final VoidCallback onSendAll;
  final VoidCallback onStop;
  final BalanceState? balance;
  final VoidCallback? onCheckBalance;
  final ValueChanged<String>? onDequeue;
  final VoidCallback? onResumeNow;

  static String delayLabel(S s, int ms) => switch (ms) {
        0 => s.delayNone,
        500 => s.delaySeconds('0.5'),
        1000 => s.delaySeconds('1'),
        2000 => s.delaySeconds('2'),
        _ => '$ms ms',
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final totals = state.totals;
    final pendingGroups = state.pendingGroupsCount;
    final active = state.activeGroup;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${s.groupsCount}: ${state.groups.length}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${s.numbersLabel}: ${totals.total}',
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
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Stat(s.sentLabel, totals.sent, t.success),
                _Stat(s.remainingLabel, totals.remaining, t.warning),
                _Stat(s.failedLabel, totals.failed, t.danger),
              ],
            ),
            if (active != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  s.sendingGroup(
                    active.title,
                    active.counters.sent,
                    active.counters.total,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.accent,
                  ),
                ),
              ),
            if (state.pausedUntil != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                decoration: BoxDecoration(
                  color: t.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top, size: 18, color: t.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.pausedUntil(DateFormatting.time(state.pausedUntil!)),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onResumeNow != null)
                      TextButton(
                        onPressed: onResumeNow,
                        child: Text(s.continueNow),
                      ),
                  ],
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
                    Text(s.queueLabel, style: const TextStyle(fontSize: 12)),
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
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        balance!.balance == null
                            ? s.balanceUnknown
                            : '${s.balanceLine(formatManat(balance!.balance!))}'
                                '${balance!.affordableSms != null ? ' · ${s.approxSms(balance!.affordableSms!)}' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (onCheckBalance != null)
                      TextButton(
                        onPressed: balance!.isChecking ? null : onCheckBalance,
                        child: Text(balance!.isChecking ? s.waiting : s.check),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(s.delayLabel, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final ms in SendDelayController.options)
                        ChoiceChip(
                          label: Text(
                            delayLabel(s, ms),
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
                          ? s.queueAll(pendingGroups)
                          : s.sendAll(pendingGroups),
                    ),
                  ),
                ),
                if (state.isSending) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: state.stopRequested ? null : onStop,
                    icon: const Icon(Icons.stop_circle),
                    label: Text(state.stopRequested ? s.stopping : s.stop),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: value > 0 ? color : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
