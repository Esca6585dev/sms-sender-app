import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/core/device/device_bridge.dart';
import 'package:sms_sender_app/database.dart' as database;
import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/groups/data/groups_repository.dart';
import 'package:sms_sender_app/features/groups/domain/group_source.dart';
import 'package:sms_sender_app/features/groups/domain/sms_recipient.dart';
import 'package:sms_sender_app/features/send/send_page.dart';

import 'fakes.dart';

void main() {
  group('SMS limit pause', () {
    test('a refused send pauses, retries the same number and continues',
        () async {
      final sender = FakeSmsSender()..throwUntilSent = 3;
      final parser = FakeExcelParser();
      final bridge = NoopDeviceBridge();
      final container = makeContainer(
        repository: InMemoryGroupsRepository(),
        sender: sender,
        parser: parser,
        bridge: bridge,
        batchSize: 10,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(10);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;

      final run = notifier.sendGroup(group.id, message: 'Salam');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(container.read(excelGroups).isPaused, isTrue);
      await run;

      final state = container.read(excelGroups);
      expect(state.isPaused, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.groups.first.counters.sent, 10);
      expect(state.groups.first.counters.failed, 0);
      expect(sender.sent.length, 10);
      expect(bridge.log.where((e) => e.startsWith('update:')), isNotEmpty);
    });

    test('resumeNow ends the pause early', () async {
      final sender = FakeSmsSender()..throwUntilSent = 1;
      final parser = FakeExcelParser();
      final container = makeContainer(
        repository: InMemoryGroupsRepository(),
        sender: sender,
        parser: parser,
        batchSize: 10,
        limitWaits: const [Duration(seconds: 30)],
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(3);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;

      final run = notifier.sendGroup(group.id, message: 'Salam');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(container.read(excelGroups).isPaused, isTrue);
      notifier.resumeNow();
      await run.timeout(const Duration(seconds: 5));

      expect(container.read(excelGroups).groups.first.counters.sent, 3);
    });

    test('stop during a pause ends the run without errors', () async {
      final sender = FakeSmsSender()..throwUntilSent = 1;
      final parser = FakeExcelParser();
      final container = makeContainer(
        repository: InMemoryGroupsRepository(),
        sender: sender,
        parser: parser,
        batchSize: 10,
        limitWaits: const [Duration(seconds: 30)],
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(3);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;

      final run = notifier.sendGroup(group.id, message: 'Salam');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      notifier.stop();
      await run.timeout(const Duration(seconds: 5));

      final state = container.read(excelGroups);
      expect(state.isSending, isFalse);
      expect(state.isPaused, isFalse);
      expect(state.groups.first.counters.sent, 0);
      expect(state.groups.first.counters.pending, 3);
      expect(sender.sent, isEmpty);
    });

    test('after the whole wait schedule the number fails and the run stops',
        () async {
      final sender = FakeSmsSender()..throwUntilSent = 100;
      final parser = FakeExcelParser();
      final container = makeContainer(
        repository: InMemoryGroupsRepository(),
        sender: sender,
        parser: parser,
        batchSize: 10,
        limitWaits: const [Duration(milliseconds: 5)],
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(2);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;

      await notifier.sendGroup(group.id, message: 'Salam');

      final state = container.read(excelGroups);
      expect(state.errorMessage, isNotNull);
      expect(state.groups.first.counters.failed, 1);
      expect(state.groups.first.counters.pending, 1);
    });
  });

  group('server groups', () {
    test('importRecipients keeps custom names on replace and marks sent',
        () async {
      final repository = InMemoryGroupsRepository();
      final container = makeContainer(
        repository: repository,
        sender: FakeSmsSender(),
        parser: FakeExcelParser(),
        batchSize: 10,
      );
      final server = groupsControllerProvider(GroupSource.server);
      final notifier = container.read(server.notifier);
      await notifier.ready;

      await notifier.importRecipients(fakeRecipients(25));
      var state = container.read(server);
      expect(state.groups.map((g) => g.total), [10, 10, 5]);
      await notifier.renameGroup(state.groups[1].id, 'VIP');

      final again = [
        for (final r in fakeRecipients(12))
          r.copyWith(status: RecipientStatus.sent),
        ...fakeRecipients(8, offset: 12),
      ];
      final summary =
          await notifier.importRecipients(again, replace: true, keepNames: true);

      state = container.read(server);
      expect(summary.imported, 20);
      expect(state.groups.map((g) => g.total), [10, 10]);
      expect(state.groups[1].title, 'VIP');
      expect(state.totals.sent, 12);
      expect(state.groups[0].counters.remaining, 0);
      expect(state.groups[1].counters.remaining, 8);
      expect(repository.groups.length, 2);
    });

    test('toRecipients normalises, de-duplicates and sorts backend contacts',
        () {
      final contacts = [
        database.Contact(id: 1, title: 'Zara', phone_number: '99365000002', isSent: true),
        database.Contact(id: 2, title: 'Aman', phone_number: '+99365000001', isSent: false),
        database.Contact(id: 3, title: 'Dup', phone_number: '865000001', isSent: false),
        database.Contact(id: 4, title: '', phone_number: '', isSent: false),
      ];

      final asIs = serverContactsToRecipients(contacts, ServerSort.server);
      expect(asIs.map((r) => r.phone), ['+99365000002', '+99365000001']);
      expect(asIs.first.isSent, isTrue);

      final byName = serverContactsToRecipients(contacts, ServerSort.byName);
      expect(byName.map((r) => r.name), ['Aman', 'Zara']);

      final unsentFirst =
          serverContactsToRecipients(contacts, ServerSort.unsentFirst);
      expect(unsentFirst.first.phone, '+99365000001');
    });
  });
}
