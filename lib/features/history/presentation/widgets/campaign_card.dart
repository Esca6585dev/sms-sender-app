import 'package:flutter/material.dart';

import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';

extension CampaignSourceIcon on CampaignSource {
  IconData get icon => switch (this) {
        CampaignSource.group => Icons.group_work_outlined,
        CampaignSource.all => Icons.send_outlined,
        CampaignSource.single => Icons.person_outline,
      };
}

/// One recorded send run in the history list.
class CampaignCard extends StatelessWidget {
  const CampaignCard({
    super.key,
    required this.summary,
    this.onTap,
    this.showDate = false,
  });

  final CampaignSummary summary;
  final VoidCallback? onTap;

  /// Show the full date instead of only the time (used outside day sections).
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = summary;
    final hasErrors = s.failed > 0;
    final barColor = hasErrors ? Colors.orange.shade700 : Colors.green;
    final when = showDate
        ? DateFormatting.dateTime(s.startedAt)
        : DateFormatting.time(s.startedAt);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(s.source.icon, color: scheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.sourceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$when · ${s.total} номеров',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${s.sent} / ${s.total}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: barColor,
                        ),
                      ),
                      if (hasErrors)
                        Text(
                          'ошибок: ${s.failed}',
                          style: const TextStyle(fontSize: 11, color: Colors.red),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: s.successRate,
                  minHeight: 6,
                  color: barColor,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
