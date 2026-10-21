import 'package:flutter/material.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/groups/domain/sms_group.dart';
import 'package:sms_sender_app/features/groups/domain/sms_recipient.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/status_chip.dart';

enum _CardAction { open, rename, dequeue, remove }

/// One group in the list: name, range, status, progress, counters, cost,
/// the numbers (collapsed or expanded) and the per-group actions.
class GroupCard extends StatefulWidget {
  const GroupCard({
    super.key,
    required this.group,
    required this.isActive,
    required this.actionsEnabled,
    required this.onSend,
    required this.onReset,
    required this.onOpen,
    required this.onRemove,
    required this.onRename,
    this.queuePosition,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.onDequeue,
    this.costLabel,
  });

  final SmsGroup group;

  /// This group is being sent right now.
  final bool isActive;

  /// `false` while an import runs (sending no longer blocks: groups queue).
  final bool actionsEnabled;
  final VoidCallback onSend;
  final VoidCallback onReset;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  /// 1-based place in the send queue, `null` when not queued.
  final int? queuePosition;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;
  final VoidCallback? onDequeue;

  /// `≈ 1,00 TMT` for the numbers still to send.
  final String? costLabel;

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _expanded = false;

  static const int _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final c = g.counters;
    final status = g.statusFor(isActive: widget.isActive);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final queued = widget.queuePosition != null;
    final canSend =
        widget.actionsEnabled && c.remaining > 0 && !queued && !widget.isActive;
    final canReset =
        widget.actionsEnabled && !widget.isActive && (c.sent > 0 || c.failed > 0);
    final sendLabel = widget.isActive
        ? 'Отправляется…'
        : queued
            ? 'В очереди #${widget.queuePosition}'
            : c.failed > 0 && c.pending == 0
                ? 'Повторить (${c.failed})'
                : c.sent > 0
                    ? 'Продолжить (${c.remaining})'
                    : 'Отправить';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radius),
        side: BorderSide(
          color: widget.selected ? t.accent : t.cardBorder,
          width: widget.selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radius),
        onTap: widget.selectionMode ? widget.onToggleSelected : widget.onOpen,
        onLongPress: widget.onToggleSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.selectionMode)
                    Checkbox(
                      value: widget.selected,
                      onChanged: (_) => widget.onToggleSelected?.call(),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                g.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (queued) ...[
                              const SizedBox(width: 8),
                              _Badge(
                                '#${widget.queuePosition}',
                                color: t.accent,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${g.rangeLabel} · ${c.total} номеров'
                          '${widget.costLabel != null ? ' · ${widget.costLabel}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GroupStatusChip(status: status),
                  PopupMenuButton<_CardAction>(
                    enabled: widget.actionsEnabled,
                    tooltip: 'Действия',
                    onSelected: (action) {
                      switch (action) {
                        case _CardAction.open:
                          widget.onOpen();
                        case _CardAction.rename:
                          widget.onRename();
                        case _CardAction.dequeue:
                          widget.onDequeue?.call();
                        case _CardAction.remove:
                          widget.onRemove();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _CardAction.open,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.list),
                          title: Text('Открыть список'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _CardAction.rename,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Переименовать'),
                        ),
                      ),
                      if (queued)
                        const PopupMenuItem(
                          value: _CardAction.dequeue,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.playlist_remove),
                            title: Text('Убрать из очереди'),
                          ),
                        ),
                      PopupMenuItem(
                        value: _CardAction.remove,
                        enabled: !widget.isActive,
                        child: const ListTile(
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
                  backgroundColor: scheme.surfaceContainerHighest,
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${c.percent}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
                  _Counter('Осталось', c.remaining, t.warning),
                  _Counter('Ошибок', c.failed, t.danger),
                  if (widget.isActive) _Counter('Идёт', c.sending, t.accent),
                ],
              ),
              const SizedBox(height: 6),
              if (_expanded)
                _NumbersList(group: g)
              else
                Text(
                  _preview(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    _expanded ? 'Скрыть номера' : 'Показать номера (${c.total})',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canSend ? widget.onSend : null,
                        icon: Icon(
                          widget.isActive
                              ? Icons.sync
                              : queued
                                  ? Icons.schedule
                                  : Icons.send,
                          size: 18,
                        ),
                        label: Text(sendLabel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: canReset ? widget.onReset : null,
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
    final g = widget.group;
    final shown = g.recipients.take(_previewCount).map((r) => r.phone).join(', ');
    final rest = g.total - _previewCount;
    return rest > 0 ? '$shown … ещё $rest' : shown;
  }
}

class _NumbersList extends StatelessWidget {
  const _NumbersList({required this.group});

  final SmsGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppStyleTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        border: Border.all(color: t.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < group.recipients.length; i++)
            _NumberRow(
              index: group.startNumber + i,
              recipient: group.recipients[i],
              last: i == group.recipients.length - 1,
              borderColor: t.cardBorder,
              mutedColor: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.index,
    required this.recipient,
    required this.last,
    required this.borderColor,
    required this.mutedColor,
  });

  final int index;
  final SmsRecipient recipient;
  final bool last;
  final Color borderColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final t = AppStyleTokens.of(context);
    final (icon, color) = switch (recipient.status) {
      RecipientStatus.pending => (Icons.radio_button_unchecked, mutedColor),
      RecipientStatus.sending => (Icons.sync, t.accent),
      RecipientStatus.sent => (Icons.check_circle, t.success),
      RecipientStatus.failed => (Icons.error, t.danger),
    };
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$index',
              style: TextStyle(fontSize: 11, color: mutedColor),
            ),
          ),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              recipient.phone,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (recipient.name.isNotEmpty)
            Flexible(
              child: Text(
                recipient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            ),
          if (recipient.sentAt != null) ...[
            const SizedBox(width: 8),
            Text(
              DateFormatting.time(recipient.sentAt!),
              style: TextStyle(fontSize: 11, color: mutedColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          TextSpan(
            text: '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: value > 0 ? color : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
