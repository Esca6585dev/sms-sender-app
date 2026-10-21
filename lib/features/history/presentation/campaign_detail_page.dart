import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';
import 'package:sms_sender_app/features/history/presentation/widgets/campaign_card.dart';

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
    return FutureBuilder<SmsCampaign?>(
      future: _campaign,
      builder: (context, snapshot) {
        final campaign = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(campaign?.summary.sourceLabel ?? 'Рассылка'),
            actions: [
              if (campaign != null)
                IconButton(
                  tooltip: 'Удалить запись',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(campaign.summary.id),
                ),
            ],
          ),
          body: switch (snapshot.connectionState) {
            ConnectionState.waiting =>
              const Center(child: CircularProgressIndicator()),
            _ => campaign == null
                ? const Center(child: Text('Запись не найдена'))
                : _CampaignBody(campaign: campaign),
          },
        );
      },
    );
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text('Запись об этой рассылке будет удалена из истории.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
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
    final scheme = Theme.of(context).colorScheme;
    final s = campaign.summary;
    final info = SmsMessageInfo.analyze(s.message);
    final hasErrors = s.failed > 0;
    final barColor = hasErrors ? Colors.orange.shade700 : Colors.green;

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
                            Icon(s.source.icon, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${s.source.label} · ${s.sourceLabel}',
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
                          'Начало',
                          DateFormatting.dateTime(s.startedAt),
                        ),
                        _InfoRow(
                          Icons.timer_outlined,
                          'Длительность',
                          DateFormatting.duration(s.duration),
                        ),
                        _InfoRow(
                          Icons.sms_outlined,
                          'Частей на номер',
                          '${info.parts} (${info.encoding == SmsEncoding.gsm7 ? 'GSM-7' : 'Unicode'})',
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: s.successRate,
                            minHeight: 8,
                            color: barColor,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Counter('Номеров', s.total, scheme.onSurface),
                            _Counter('Отправлено', s.sent, Colors.green),
                            _Counter(
                              'Ошибок',
                              s.failed,
                              hasErrors ? Colors.red : scheme.onSurfaceVariant,
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
                          'Текст сообщения',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          s.message,
                          style: const TextStyle(fontSize: 14, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                  child: Text(
                    'Номера (${campaign.recipients.length})',
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
                    color: r.sent ? Colors.green : Colors.red,
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
                          style: const TextStyle(color: Colors.red, fontSize: 12),
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
