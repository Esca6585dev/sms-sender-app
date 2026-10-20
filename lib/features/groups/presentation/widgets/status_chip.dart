import 'package:flutter/material.dart';

import 'package:sms_sender_app/features/groups/domain/sms_group.dart';

/// Russian labels, colours and icons for [GroupStatus].
extension GroupStatusPresentation on GroupStatus {
  String get label => switch (this) {
        GroupStatus.pending => 'Ожидает',
        GroupStatus.inProgress => 'В процессе',
        GroupStatus.paused => 'Приостановлено',
        GroupStatus.partial => 'С ошибками',
        GroupStatus.sent => 'Отправлено',
      };

  Color get color => switch (this) {
        GroupStatus.pending => Colors.blueGrey,
        GroupStatus.inProgress => Colors.indigo,
        GroupStatus.paused => Colors.orange.shade800,
        GroupStatus.partial => Colors.red,
        GroupStatus.sent => Colors.green,
      };

  IconData get icon => switch (this) {
        GroupStatus.pending => Icons.schedule,
        GroupStatus.inProgress => Icons.sync,
        GroupStatus.paused => Icons.pause_circle_outline,
        GroupStatus.partial => Icons.error_outline,
        GroupStatus.sent => Icons.check_circle,
      };
}

/// Small rounded status badge.
class GroupStatusChip extends StatelessWidget {
  const GroupStatusChip({super.key, required this.status});

  final GroupStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
