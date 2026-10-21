import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';

CampaignSummary summary({
  required String id,
  required DateTime startedAt,
  required int total,
  required int sent,
  CampaignSource source = CampaignSource.group,
}) =>
    CampaignSummary(
      id: id,
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(minutes: 2)),
      message: 'Salam',
      source: source,
      sourceLabel: 'test',
      total: total,
      sent: sent,
      failed: total - sent,
    );

void main() {
  final now = DateTime(2026, 10, 21, 15, 30);

  group('CampaignStats', () {
    test('empty history gives zeros and a 7-day chart of zeros', () {
      final stats = CampaignStats.from(const [], now);

      expect(stats.totalCampaigns, 0);
      expect(stats.totalSent, 0);
      expect(stats.sentToday, 0);
      expect(stats.last7Days.length, 7);
      expect(stats.last7Days.every((d) => d.sent == 0), isTrue);
      expect(stats.last7Days.first.day, DateTime(2026, 10, 15));
      expect(stats.last7Days.last.day, DateTime(2026, 10, 21));
      expect(stats.maxDaySent, 0);
      expect(stats.successRate, 0);
    });

    test('sums totals, today, last 7 days and sources', () {
      final campaigns = [
        summary(id: 'a', startedAt: DateTime(2026, 10, 21, 9), total: 100, sent: 98),
        summary(
          id: 'b',
          startedAt: DateTime(2026, 10, 21, 12),
          total: 1,
          sent: 1,
          source: CampaignSource.single,
        ),
        summary(id: 'c', startedAt: DateTime(2026, 10, 18), total: 50, sent: 50),
        summary(
          id: 'd',
          startedAt: DateTime(2026, 10, 10),
          total: 200,
          sent: 150,
          source: CampaignSource.all,
        ),
      ];

      final stats = CampaignStats.from(campaigns, now);

      expect(stats.totalCampaigns, 4);
      expect(stats.totalNumbers, 351);
      expect(stats.totalSent, 299);
      expect(stats.totalFailed, 52);
      expect(stats.sentToday, 99);
      expect(stats.campaignsToday, 2);
      expect(stats.sentLast7Days, 149); // a + b + c, not d (11 days ago)
      expect(stats.sentBySource[CampaignSource.group], 148);
      expect(stats.sentBySource[CampaignSource.single], 1);
      expect(stats.sentBySource[CampaignSource.all], 150);
      expect(stats.last7Days.last.sent, 99);
      expect(stats.last7Days[3].day, DateTime(2026, 10, 18));
      expect(stats.last7Days[3].sent, 50);
      expect(stats.maxDaySent, 99);
      expect(stats.successRate, closeTo(299 / 351, 0.0001));
    });
  });

  group('SmsCampaign.fromRun', () {
    test('derives counters from the recipients', () {
      final campaign = SmsCampaign.fromRun(
        message: 'Salam',
        source: CampaignSource.group,
        sourceLabel: 'Группа 1',
        startedAt: now,
        recipients: const [
          CampaignRecipient(phone: '+99365000001', sent: true),
          CampaignRecipient(phone: '+99365000002', sent: false, error: 'x'),
          CampaignRecipient(phone: '+99365000003', sent: true),
        ],
      );

      expect(campaign.summary.total, 3);
      expect(campaign.summary.sent, 2);
      expect(campaign.summary.failed, 1);
      expect(campaign.summary.id, isNotEmpty);

      final roundTrip = SmsCampaign.fromJson(campaign.toJson());
      expect(roundTrip.summary.sent, 2);
      expect(roundTrip.recipients.length, 3);
      expect(roundTrip.recipients[1].error, 'x');
    });
  });
}
