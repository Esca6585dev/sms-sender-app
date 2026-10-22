import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/app_shell.dart' show ShellMenuButton;
import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';
import 'package:sms_sender_app/features/history/presentation/campaign_detail_page.dart';
import 'package:sms_sender_app/features/history/presentation/server_messages_page.dart';
import 'package:sms_sender_app/features/history/presentation/widgets/campaign_card.dart';
import 'package:sms_sender_app/l10n/strings.dart';

enum _HistoryAction { serverTexts, clear }

/// Every recorded send run, grouped by day, newest first.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final state = ref.watch(campaignLogProvider);
    final rows = _buildRows(state.campaigns);

    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: Text(s.historyTitle),
        actions: [
          PopupMenuButton<_HistoryAction>(
            tooltip: s.more,
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _HistoryAction.serverTexts,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(s.drawerServerTexts),
                ),
              ),
              PopupMenuItem(
                value: _HistoryAction.clear,
                enabled: !state.isEmpty,
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(s.clearHistory),
                ),
              ),
            ],
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.isEmpty
              ? const _EmptyHistory()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: rows.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _HistoryTotals(stats: state.stats());
                    }
                    final row = rows[index - 1];
                    if (row.header != null) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                        child: Text(
                          row.header!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final summary = row.summary!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CampaignCard(
                        summary: summary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CampaignDetailPage(campaignId: summary.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  List<_Row> _buildRows(List<CampaignSummary> campaigns) {
    final rows = <_Row>[];
    String? currentDay;
    for (final c in campaigns) {
      final day = DateFormatting.relativeDate(c.startedAt);
      if (day != currentDay) {
        currentDay = day;
        rows.add(_Row.header(day));
      }
      rows.add(_Row.campaign(c));
    }
    return rows;
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _HistoryAction action,
  ) async {
    final s = S.of(context);
    switch (action) {
      case _HistoryAction.serverTexts:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ServerMessagesPage()),
        );
      case _HistoryAction.clear:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.clearHistoryTitle),
            content: Text(s.clearHistoryBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.clear),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(campaignLogProvider.notifier).clear();
        }
    }
  }
}

class _Row {
  const _Row.header(this.header) : summary = null;

  const _Row.campaign(this.summary) : header = null;

  final String? header;
  final CampaignSummary? summary;
}

class _HistoryTotals extends StatelessWidget {
  const _HistoryTotals({required this.stats});

  final CampaignStats stats;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _Total(s.campaignsLabel, '${stats.totalCampaigns}', t.accent),
            _Total(s.sentLabel, '${stats.totalSent}', t.success),
            _Total(
              s.errorsLabel,
              '${stats.totalFailed}',
              stats.totalFailed > 0 ? t.danger : scheme.onSurfaceVariant,
            ),
            _Total(s.todayLabel, '${stats.sentToday}', t.warning),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              s.historyEmptyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              s.historyEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
