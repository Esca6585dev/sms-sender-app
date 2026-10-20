import 'package:flutter/material.dart';

import 'package:sms_sender_app/features/groups/domain/sms_group.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/status_chip.dart';

enum _CardAction { open, remove }

/// One group in the list: title, range, status, progress, counters,
/// a preview of the numbers and the per-group actions.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    required this.isActive,
    required this.actionsEnabled,
    required this.onSend,
    required this.onReset,
    required this.onOpen,
    required this.onRemove,
  });

  final SmsGroup group;

  /// This group is being sent right now.
  final bool isActive;

  /// `false` while any group is sending or an import runs.
  final bool actionsEnabled;

  final VoidCallback onSend;
  final VoidCallback onReset;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  static const int _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final c = group.counters;
    final status = group.statusFor(isActive: isActive);
    final canSend = actionsEnabled && c.remaining > 0;
    final canReset = actionsEnabled && (c.sent > 0 || c.failed > 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.rangeLabel} · ${c.total} номеров',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GroupStatusChip(status: status),
                  PopupMenuButton<_CardAction>(
                    enabled: actionsEnabled,
                    tooltip: 'Действия',
                    onSelected: (action) {
                      switch (action) {
                        case _CardAction.open:
                          onOpen();
                        case _CardAction.remove:
                          onRemove();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _CardAction.open,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.list),
                          title: Text('Открыть список'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _CardAction.remove,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Удалить группу'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: c.progress,
                  minHeight: 8,
                  color: status.color,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Отправлено ${c.sent} / ${c.total}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${c.percent}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: status.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 14,
                children: [
                  _Counter('Осталось', c.remaining, Colors.orange.shade800),
                  _Counter('Ошибок', c.failed, Colors.red),
                  if (isActive) _Counter('Идёт', c.sending, Colors.indigo),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _preview(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canSend ? onSend : null,
                        icon: Icon(isActive ? Icons.sync : Icons.send, size: 18),
                        label: Text(
                          isActive
                              ? 'Отправляется…'
                              : c.sent > 0
                                  ? 'Продолжить'
                                  : 'Отправить',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: canReset ? onReset : null,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Сброс'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _preview() {
    final shown =
        group.recipients.take(_previewCount).map((r) => r.phone).join(', ');
    final rest = group.total - _previewCount;
    return rest > 0 ? '$shown … ещё $rest' : shown;
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          TextSpan(
            text: '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: value > 0 ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
