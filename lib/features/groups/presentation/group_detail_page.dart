import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/groups/domain/sms_recipient.dart';
import 'package:sms_sender_app/features/groups/presentation/group_actions.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/status_chip.dart';

/// Full list of the numbers of one group with per-number status.
class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(
      groupsControllerProvider.select((s) => s.groupById(groupId)),
    );
    final isActive = ref.watch(
      groupsControllerProvider.select((s) => s.activeGroupId == groupId),
    );
    final isBusy = ref.watch(groupsControllerProvider.select((s) => s.isBusy));

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Группа')),
        body: const Center(child: Text('Группа удалена')),
      );
    }

    final c = group.counters;
    final status = group.statusFor(isActive: isActive);
    final actions = GroupActions(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
        actions: [
          IconButton(
            tooltip: 'Сбросить статусы',
            icon: const Icon(Icons.restart_alt),
            onPressed: isBusy || (c.sent == 0 && c.failed == 0)
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${group.rangeLabel} · ${c.total} номеров',
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
                        color: status.color,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Отправлено ${c.sent} / ${c.total}'),
                        Text('Осталось ${c.remaining}'),
                        Text(
                          'Ошибок ${c.failed}',
                          style: TextStyle(
                            color: c.failed > 0 ? Colors.red : null,
                          ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          )
                        : recipient.name.isNotEmpty
                            ? Text(recipient.name)
                            : null,
                    trailing: Text(
                      '№ ${group.startNumber + index}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
            onPressed: !isBusy && c.remaining > 0
                ? () => actions.sendGroup(group)
                : null,
            icon: const Icon(Icons.send),
            label: Text(
              c.sent > 0 && c.remaining > 0
                  ? 'Продолжить отправку (${c.remaining})'
                  : 'Отправить группу (${c.remaining})',
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
    return switch (status) {
      RecipientStatus.pending =>
        const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      RecipientStatus.sending => const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      RecipientStatus.sent =>
        const Icon(Icons.check_circle, color: Colors.green),
      RecipientStatus.failed => const Icon(Icons.error, color: Colors.red),
    };
  }
}
