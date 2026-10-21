import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/app_shell.dart' show ShellMenuButton;
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';
import 'package:sms_sender_app/features/history/presentation/campaign_detail_page.dart';
import 'package:sms_sender_app/features/history/presentation/widgets/campaign_card.dart';
import 'package:sms_sender_app/shared/widgets/stat_tile.dart';

/// Totals, a 7-day chart, a breakdown by source and the latest runs.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(campaignLogProvider);
    final groups = ref.watch(groupsControllerProvider);
    final stats = log.stats();
    final scheme = Theme.of(context).colorScheme;
    final recent = log.campaigns.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text('Статистика'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Сегодня',
                  value: '${stats.sentToday}',
                  subtitle: 'рассылок: ${stats.campaignsToday}',
                  icon: Icons.today_outlined,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'За 7 дней',
                  value: '${stats.sentLast7Days}',
                  icon: Icons.date_range_outlined,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Всего отправлено',
                  value: '${stats.totalSent}',
                  subtitle: 'успешно ${(stats.successRate * 100).round()}%',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Ошибок',
                  value: '${stats.totalFailed}',
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Рассылок',
                  value: '${stats.totalCampaigns}',
                  icon: Icons.campaign_outlined,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Номеров в группах',
                  value: '${groups.totals.total}',
                  subtitle: 'групп: ${groups.groups.length}',
                  icon: Icons.group_work_outlined,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionTitle('Последние 7 дней'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: _WeekChart(stats: stats),
            ),
          ),
          const SizedBox(height: 14),
          _SectionTitle('По источникам'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: stats.totalSent == 0
                  ? Text(
                      'Пока нет отправленных SMS',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    )
                  : Column(
                      children: [
                        for (final source in CampaignSource.values)
                          if ((stats.sentBySource[source] ?? 0) > 0)
                            _SourceRow(
                              source: source,
                              sent: stats.sentBySource[source]!,
                              total: stats.totalSent,
                            ),
                      ],
                    ),
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionTitle('Последние рассылки'),
            for (final c in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CampaignCard(
                  summary: c,
                  showDate: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CampaignDetailPage(campaignId: c.id),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.stats});

  final CampaignStats stats;

  static const double _maxBarHeight = 110;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = stats.maxDaySent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in stats.last7Days)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${day.sent}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: day.sent > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: max == 0 ? 4 : 4 + _maxBarHeight * day.sent / max,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: day.sent > 0
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormatting.weekdayShort[day.day.weekday - 1],
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.sent,
    required this.total,
  });

  final CampaignSource source;
  final int sent;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(source.icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(source.label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : sent / total,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$sent',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
