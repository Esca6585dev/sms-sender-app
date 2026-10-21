import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/groups/data/groups_repository.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/data/campaign_repository.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';

import '../groups/fakes.dart';

void main() {
  group('CampaignLogController', () {
    test('records, lists newest first, deletes and clears', () async {
      final repo = InMemoryCampaignRepository();
      final container = makeContainer(
        repository: InMemoryGroupsRepository(),
        sender: FakeSmsSender(),
        parser: FakeExcelParser(),
        campaigns: repo,
      );
      final log = container.read(campaignLogProvider.notifier);
      await log.ready;

      final older = SmsCampaign.fromRun(
        message: 'A',
        source: CampaignSource.all,
        sourceLabel: 'Все номера',
        startedAt: DateTime(2026, 10, 20, 10),
        recipients: fakeRecipients(3)
            .map((r) => CampaignRecipient(phone: r.phone, sent: true))
            .toList(),
      );
      final newer = SmsCampaign.fromRun(
        message: 'B',
        source: CampaignSource.single,
        sourceLabel: '+99365000009',
        startedAt: DateTime(2026, 10, 21, 10),
        recipients: const [CampaignRecipient(phone: '+99365000009', sent: false)],
      );

      await log.record(older);
      await log.record(newer);

      var state = container.read(campaignLogProvider);
      expect(state.campaigns.map((c) => c.message), ['B', 'A']);
      expect(state.stats(DateTime(2026, 10, 21)).totalSent, 3);
      expect((await log.details(older.summary.id))?.recipients.length, 3);

      await log.delete(newer.summary.id);
      state = container.read(campaignLogProvider);
      expect(state.campaigns.map((c) => c.message), ['A']);

      await log.clear();
      expect(container.read(campaignLogProvider).isEmpty, isTrue);
      expect(await repo.loadIndex(), isEmpty);
    });

    test('a group send is recorded as a campaign with every number', () async {
      final repo = InMemoryCampaignRepository();
      final sender = FakeSmsSender();
      final parser = FakeExcelParser();
      final container = makeContainer(
        repository: InMemoryGroupsRepository(),
        sender: sender,
        parser: parser,
        campaigns: repo,
      );
      final groups = container.read(groupsControllerProvider.notifier);
      parser.next = fakeRecipients(30);
      await groups.importFromBytes(emptyBytes);
      final group = container.read(groupsControllerProvider).groups.first;
      sender.failing.add(group.recipients[4].phone);

      await groups.sendGroup(group.id, message: 'Salam');
      await Future<void>.delayed(Duration.zero);

      final log = container.read(campaignLogProvider);
      expect(log.campaigns.length, 1);
      final summary = log.campaigns.first;
      expect(summary.source, CampaignSource.group);
      expect(summary.sourceLabel, contains('Группа 1'));
      expect(summary.total, 30);
      expect(summary.sent, 29);
      expect(summary.failed, 1);

      final details = await container
          .read(campaignLogProvider.notifier)
          .details(summary.id);
      expect(details, isNotNull);
      expect(details!.recipients.where((r) => !r.sent).single.phone,
          group.recipients[4].phone);
    });
  });
}
