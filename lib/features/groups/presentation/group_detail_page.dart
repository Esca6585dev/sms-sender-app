import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/groups/domain/group_source.dart';
import 'package:sms_sender_app/features/groups/domain/sms_recipient.dart';
import 'package:sms_sender_app/features/groups/presentation/group_actions.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/status_chip.dart';
import 'package:sms_sender_app/l10n/strings.dart';

/// Full list of the numbers of one group with per-number status.
class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({
    super.key,
    required this.groupId,
    this.source = GroupSource.excel,
  });

  final String groupId;
  final GroupSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final provider = groupsControllerProvider(source);
    final group = ref.watch(provider.select((st) => st.groupById(groupId)));
    final isActive =
        ref.watch(provider.select((st) => st.activeGroupId == groupId));
    final isImporting = ref.watch(provider.select((st) => st.isImporting));

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.groupDeletedTitle)),
        body: Center(child: Text(s.groupDeletedBody)),
      );
    }

    final c = group.counters;
    final status = group.statusFor(isActive: isActive);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final actions = GroupActions(context, ref, source: source);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
        actions: [
          IconButton(
            tooltip: s.rename,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => actions.rename(group),
          ),
          IconButton(
            tooltip: s.resetStatuses,
            icon: const Icon(Icons.restart_alt),
            onPressed: isImporting || isActive || (c.sent == 0 && c.failed == 0)
                ? null
                : () => actions.resetGroup(group),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${group.rangeLabel} · ${s.numbersCount(c.total)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GroupStatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: c.progress,
                        minHeight: 8,
                        color: status.colorOf(t),
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.sentOf(c.sent, c.total)),
                        Text('${s.remainingLabel} ${c.remaining}'),
                        Text(
                          '${s.failedLabel} ${c.failed}',
                          style: TextStyle(color: c.failed > 0 ? t.danger : null),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              itemCount: group.total,
              itemBuilder: (context, index) {
                final recipient = group.recipients[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: _RecipientStatusIcon(status: recipient.status),
                    title: Text(
                      recipient.phone,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: recipient.error != null
                        ? Text(
                            recipient.error!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.danger, fontSize: 12),
                          )
                        : recipient.name.isNotEmpty
                            ? Text(recipient.name)
                            : null,
                    trailing: Text(
                      '№ ${group.startNumber + index}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: FilledButton.icon(
            onPressed: !isImporting && !isActive && c.remaining > 0
                ? () => actions.sendGroup(group)
                : null,
            icon: const Icon(Icons.send),
            label: Text(
              c.sent > 0 && c.remaining > 0
                  ? s.continueSendingN(c.remaining)
                  : s.sendGroupN(c.remaining),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientStatusIcon extends StatelessWidget {
  const _RecipientStatusIcon({required this.status});

  final RecipientStatus status;

  @override
  Widget build(BuildContext context) {
    final t = AppStyleTokens.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return switch (status) {
      RecipientStatus.pending =>
        Icon(Icons.radio_button_unchecked, color: muted),
      RecipientStatus.sending => const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      RecipientStatus.sent => Icon(Icons.check_circle, color: t.success),
      RecipientStatus.failed => Icon(Icons.error, color: t.danger),
    };
  }
}
