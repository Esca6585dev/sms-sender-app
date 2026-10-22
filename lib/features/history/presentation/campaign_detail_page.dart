import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';
import 'package:sms_sender_app/features/history/presentation/widgets/campaign_card.dart';
import 'package:sms_sender_app/l10n/strings.dart';

/// Full record of one send run: message, timing, counters and every number.
class CampaignDetailPage extends ConsumerStatefulWidget {
  const CampaignDetailPage({super.key, required this.campaignId});

  final String campaignId;

  @override
  ConsumerState<CampaignDetailPage> createState() => _CampaignDetailPageState();
}

class _CampaignDetailPageState extends ConsumerState<CampaignDetailPage> {
  late final Future<SmsCampaign?> _campaign;

  @override
  void initState() {
    super.initState();
    _campaign =
        ref.read(campaignLogProvider.notifier).details(widget.campaignId);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FutureBuilder<SmsCampaign?>(
      future: _campaign,
      builder: (context, snapshot) {
        final campaign = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(campaign?.summary.sourceLabel ?? s.campaign),
            actions: [
              if (campaign != null)
                IconButton(
                  tooltip: s.deleteRecord,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(campaign.summary.id),
                ),
            ],
          ),
          body: switch (snapshot.connectionState) {
            ConnectionState.waiting =>
              const Center(child: CircularProgressIndicator()),
            _ => campaign == null
                ? Center(child: Text(s.recordNotFound))
                : _CampaignBody(campaign: campaign),
          },
        );
      },
    );
  }

  Future<void> _delete(String id) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteRecordTitle),
        content: Text(s.deleteRecordBody),
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
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(campaignLogProvider.notifier).delete(id);
    if (mounted) Navigator.pop(context);
  }
}

class _CampaignBody extends StatelessWidget {
  const _CampaignBody({required this.campaign});

  final SmsCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = campaign.summary;
    final info = SmsMessageInfo.analyze(c.message);
    final hasErrors = c.failed > 0;
    final barColor = hasErrors ? t.warning : t.success;
    final encoding =
        info.encoding == SmsEncoding.gsm7 ? s.encodingGsm : s.encodingUnicode;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(c.source.icon, color: t.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${c.source.label} · ${c.sourceLabel}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          Icons.schedule,
                          s.started,
                          DateFormatting.dateTime(c.startedAt),
                        ),
                        _InfoRow(
                          Icons.timer_outlined,
                          s.duration,
                          DateFormatting.duration(c.duration),
                        ),
                        _InfoRow(
                          Icons.sms_outlined,
                          s.partsPerNumber,
                          '${info.parts} ($encoding)',
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: c.successRate,
                            minHeight: 8,
                            color: barColor,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Counter(s.numbersLabel, c.total, scheme.onSurface),
                            _Counter(s.sentLabel, c.sent, t.success),
                            _Counter(
                              s.errorsLabel,
                              c.failed,
                              hasErrors ? t.danger : scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.messageText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          c.message,
                          style: const TextStyle(fontSize: 14, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                  child: Text(
                    s.numbersN(campaign.recipients.length),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverList.builder(
            itemCount: campaign.recipients.length,
            itemBuilder: (context, index) {
              final r = campaign.recipients[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    r.sent ? Icons.check_circle : Icons.error,
                    color: r.sent ? t.success : t.danger,
                  ),
                  title: Text(
                    r.phone,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: r.error != null
                      ? Text(
                          r.error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.danger, fontSize: 12),
                        )
                      : r.name.isNotEmpty
                          ? Text(r.name)
                          : null,
                  trailing: Text(
                    r.sentAt != null ? DateFormatting.time(r.sentAt!) : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
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
    );
  }
}
