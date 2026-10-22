import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/core/device/device_bridge.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/groups/data/groups_repository.dart';
import 'package:sms_sender_app/features/groups/domain/group_batcher.dart';
import 'package:sms_sender_app/features/groups/domain/sms_group.dart';

import 'fakes.dart';

void main() {
  group('SmsGroup names', () {
    test('letters follow spreadsheet columns', () {
      expect(SmsGroup.letterFor(1), 'A');
      expect(SmsGroup.letterFor(26), 'Z');
      expect(SmsGroup.letterFor(27), 'AA');
      expect(SmsGroup.letterFor(52), 'AZ');
      expect(SmsGroup.letterFor(53), 'BA');
    });

    test('rename, default name and JSON round trip', () {
      final group = const GroupBatcher().split(fakeRecipients(5)).first;
      expect(group.title, 'Группа A');

      final renamed = group.rename('VIP клиенты');
      expect(renamed.title, 'VIP клиенты');
      expect(renamed.defaultTitle, 'Группа A');
      expect(SmsGroup.fromJson(renamed.toJson()).title, 'VIP клиенты');

      expect(renamed.rename('   ').title, 'Группа A');
      expect(renamed.rename(null).name, isNull);
      expect(renamed.reset().title, 'VIP клиенты');
    });
  });

  group('send queue', () {
    test('groups queued while sending are sent afterwards, in order', () async {
      final sender = FakeSmsSender()..latency = const Duration(milliseconds: 3);
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
      parser.next = fakeRecipients(30);
      await notifier.importFromBytes(emptyBytes);
      final groups = container.read(excelGroups).groups;

      final first = notifier.sendGroup(groups[0].id, message: 'Salam');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final queuedC = await notifier.sendGroup(groups[2].id, message: 'Salam');
      final queuedB = await notifier.sendGroup(groups[1].id, message: 'Salam');
      final again = await notifier.sendGroup(groups[2].id, message: 'Salam');

      expect(queuedC, isTrue);
      expect(queuedB, isTrue);
      expect(again, isFalse); // already queued
      var state = container.read(excelGroups);
      expect(state.isSending, isTrue);
      expect(state.queue, [groups[2].id, groups[1].id]);
      expect(state.queuePosition(groups[1].id), 2);

      await first;

      state = container.read(excelGroups);
      expect(state.isSending, isFalse);
      expect(state.queue, isEmpty);
      expect(state.totals.sent, 30);
      expect(sender.sent.sublist(10, 20), groups[2].recipients.map((r) => r.phone));
      expect(sender.sent.sublist(20, 30), groups[1].recipients.map((r) => r.phone));
      expect(bridge.log.first, startsWith('start:'));
      expect(bridge.log.last, 'screen:false');
      expect(bridge.log, contains('stop'));
    });

    test('stop drops the queue and dequeue removes one group', () async {
      final sender = FakeSmsSender()..latency = const Duration(milliseconds: 4);
      final parser = FakeExcelParser();
      final container = makeContainer(
        repository: InMemoryGroupsRepository(),
        sender: sender,
        parser: parser,
        batchSize: 10,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(30);
      await notifier.importFromBytes(emptyBytes);
      final groups = container.read(excelGroups).groups;

      final run = notifier.sendAllPending(message: 'Salam');
      await Future<void>.delayed(const Duration(milliseconds: 8));
      expect(container.read(excelGroups).queue.length, 2);

      notifier.dequeue(groups[1].id);
      expect(container.read(excelGroups).queue, [groups[2].id]);

      notifier.stop();
      await run;

      final state = container.read(excelGroups);
      expect(state.queue, isEmpty);
      expect(state.isSending, isFalse);
      expect(state.groups[1].counters.sent, 0);
      expect(state.groups[2].counters.sent, 0);
      expect(state.groups[0].counters.sent, lessThan(10));
    });

    test('selection: toggle, select all pending, send selected', () async {
      final sender = FakeSmsSender();
      final parser = FakeExcelParser();
      final container = makeContainer(
        repository: InMemoryGroupsRepository(),
        sender: sender,
        parser: parser,
        batchSize: 10,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(30);
      await notifier.importFromBytes(emptyBytes);
      final groups = container.read(excelGroups).groups;

      notifier.toggleSelected(groups[1].id);
      notifier.toggleSelected(groups[2].id);
      notifier.toggleSelected(groups[2].id);
      expect(container.read(excelGroups).selectedIds, {groups[1].id});

      await notifier.sendSelected(message: 'Salam');
      var state = container.read(excelGroups);
      expect(state.hasSelection, isFalse);
      expect(state.groups[1].counters.sent, 10);
      expect(state.groups[0].counters.sent, 0);

      notifier.selectAllPending();
      state = container.read(excelGroups);
      expect(state.selectedIds, {groups[0].id, groups[2].id});

      final bridge = NoopDeviceBridge();
      bridge.requestStop(); // no-op when idle
      notifier.clearSelection();
      expect(container.read(excelGroups).hasSelection, isFalse);
    });

    test('a notification "stop" request stops the running send', () async {
      final sender = FakeSmsSender()..latency = const Duration(milliseconds: 4);
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
      parser.next = fakeRecipients(20);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;

      final run = notifier.sendGroup(group.id, message: 'Salam');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bridge.requestStop();
      await run;

      expect(sender.sent.length, lessThan(10));
      expect(container.read(excelGroups).isSending, isFalse);
    });
  });

  group('BalanceController.parseBalance', () {
    test('reads amounts next to a currency word or the first decimal', () {
      expect(BalanceController.parseBalance('Balans: 12.30 TMT'), 12.30);
      expect(BalanceController.parseBalance('Ваш баланс 5,00 манат'), 5.0);
      expect(BalanceController.parseBalance('Ostatok 0.50. Hoş geldiňiz'), 0.5);
      expect(BalanceController.parseBalance('Balans 7 TMT, 0800'), 7.0);
      expect(BalanceController.parseBalance('no digits here'), isNull);
    });

    test('cost and affordable SMS follow the price', () {
      const state = BalanceState(balance: 1.5);
      expect(state.cost(100, 1), closeTo(1.0, 1e-9));
      expect(state.cost(10, 3), closeTo(0.3, 1e-9));
      expect(state.affordableSms, 150);
      expect(formatManat(12.3), '12,30 TMT');
    });
  });
}
