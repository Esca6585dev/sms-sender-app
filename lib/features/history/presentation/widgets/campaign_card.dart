import 'package:flutter/material.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';
import 'package:sms_sender_app/l10n/strings.dart';

extension CampaignSourceIcon on CampaignSource {
  IconData get icon => switch (this) {
        CampaignSource.group => Icons.group_work_outlined,
        CampaignSource.serverGroup => Icons.cloud_outlined,
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
    final s = S.of(context);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = summary;
    final hasErrors = c.failed > 0;
    final barColor = hasErrors ? t.warning : t.success;
    final when = showDate
        ? DateFormatting.dateTime(c.startedAt)
        : DateFormatting.time(c.startedAt);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radius),
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
                      color: t.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(c.source.icon, color: t.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.sourceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$when · ${s.numbersCount(c.total)}',
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
                        '${c.sent} / ${c.total}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: barColor,
                        ),
                      ),
                      if (hasErrors)
                        Text(
                          s.errorsN(c.failed),
                          style: TextStyle(fontSize: 11, color: t.danger),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                c.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: c.successRate,
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
