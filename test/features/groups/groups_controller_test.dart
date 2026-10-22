import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/features/groups/data/groups_repository.dart';
import 'package:sms_sender_app/features/groups/domain/group_batcher.dart';
import 'package:sms_sender_app/features/groups/domain/sms_group.dart';

import 'fakes.dart';

void main() {
  late InMemoryGroupsRepository repository;
  late FakeSmsSender sender;
  late FakeExcelParser parser;

  setUp(() {
    repository = InMemoryGroupsRepository();
    sender = FakeSmsSender();
    parser = FakeExcelParser();
  });

  group('GroupsController', () {
    test('restores persisted groups on start', () async {
      final stored = const GroupBatcher().split(fakeRecipients(120));
      repository = InMemoryGroupsRepository(stored);
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );

      await container.read(excelGroups.notifier).ready;

      final state = container.read(excelGroups);
      expect(state.isLoading, isFalse);
      expect(state.groups.length, 2);
      expect(state.totals.total, 120);
    });

    test('import splits 250 numbers into groups of 100 and persists', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      parser.next = fakeRecipients(250);

      final summary = await container
          .read(excelGroups.notifier)
          .importFromBytes(emptyBytes);

      final groups = container.read(excelGroups).groups;
      expect(summary.imported, 250);
      expect(summary.groupsCreated, 3);
      expect(groups.map((g) => g.index), [1, 2, 3]);
      expect(groups.map((g) => g.title), ['Группа A', 'Группа B', 'Группа C']);
      expect(groups.map((g) => g.total), [100, 100, 50]);
      expect(groups.map((g) => g.startNumber), [1, 101, 201]);
      expect(groups.map((g) => g.endNumber), [100, 200, 250]);
      expect(groups.every((g) => g.statusFor(isActive: false) == GroupStatus.pending), isTrue);
      expect(repository.groups.length, 3);
    });

    test('second import appends with continued numbering and skips duplicates',
        () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);

      parser.next = fakeRecipients(150);
      await notifier.importFromBytes(emptyBytes);

      parser.next = fakeRecipients(170); // 150 known + 20 new
      final summary = await notifier.importFromBytes(emptyBytes);

      final groups = container.read(excelGroups).groups;
      expect(summary.imported, 20);
      expect(summary.duplicates, 150);
      expect(summary.groupsCreated, 1);
      expect(groups.map((g) => g.index), [1, 2, 3]);
      expect(groups.last.startNumber, 151);
      expect(groups.last.endNumber, 170);
    });

    test('import with replace discards the old groups', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);

      parser.next = fakeRecipients(150);
      await notifier.importFromBytes(emptyBytes);
      parser.next = fakeRecipients(170);
      await notifier.importFromBytes(emptyBytes, replace: true);

      final groups = container.read(excelGroups).groups;
      expect(groups.map((g) => g.total), [100, 70]);
      expect(groups.map((g) => g.index), [1, 2]);
    });

    test('sendGroup sends every number of that group only', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(120);
      await notifier.importFromBytes(emptyBytes);
      final first = container.read(excelGroups).groups.first;

      final started = await notifier.sendGroup(first.id, message: 'Salam');

      final state = container.read(excelGroups);
      expect(started, isTrue);
      expect(sender.sent.length, 100);
      expect(state.isSending, isFalse);
      expect(state.groups[0].counters.sent, 100);
      expect(state.groups[0].counters.remaining, 0);
      expect(state.groups[0].statusFor(isActive: false), GroupStatus.sent);
      expect(state.groups[1].counters.sent, 0);
      expect(state.groups[1].statusFor(isActive: false), GroupStatus.pending);
      expect(repository.groups[0].counters.sent, 100);
    });

    test('failed numbers are counted and retried by the next send', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(100);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;
      final unlucky = group.recipients[5].phone;
      sender.failing.add(unlucky);

      await notifier.sendGroup(group.id, message: 'Salam');

      var counters = container.read(excelGroups).groups.first.counters;
      expect(counters.sent, 99);
      expect(counters.failed, 1);
      expect(counters.remaining, 1);
      expect(
        container.read(excelGroups).groups.first.statusFor(isActive: false),
        GroupStatus.partial,
      );

      sender.failing.clear();
      await notifier.sendGroup(group.id, message: 'Salam');

      counters = container.read(excelGroups).groups.first.counters;
      expect(sender.sent.length, 101); // 100 + one retry
      expect(sender.sent.last, unlucky);
      expect(counters.sent, 100);
      expect(counters.failed, 0);
    });

    test('a platform error aborts the group and reports it', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(100);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;
      sender.throwing.add(group.recipients[10].phone);

      await notifier.sendGroup(group.id, message: 'Salam');

      final state = container.read(excelGroups);
      final counters = state.groups.first.counters;
      expect(state.errorMessage, contains('limit reached'));
      expect(state.isSending, isFalse);
      expect(sender.sent.length, 10);
      expect(counters.sent, 10);
      expect(counters.failed, 1);
      expect(counters.pending, 89);
      expect(state.groups.first.statusFor(isActive: false), GroupStatus.paused);

      notifier.dismissError();
      expect(container.read(excelGroups).errorMessage, isNull);
    });

    test('stop() ends the loop after the current number', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(100);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;
      sender.latency = const Duration(milliseconds: 5);

      final sending = notifier.sendGroup(group.id, message: 'Salam');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(container.read(excelGroups).activeGroupId, group.id);
      notifier.stop();
      expect(container.read(excelGroups).stopRequested, isTrue);
      await sending;

      final state = container.read(excelGroups);
      expect(state.isSending, isFalse);
      expect(state.stopRequested, isFalse);
      expect(sender.sent.length, greaterThan(0));
      expect(sender.sent.length, lessThan(100));
      expect(state.groups.first.counters.sent, sender.sent.length);
      expect(state.groups.first.statusFor(isActive: false), GroupStatus.paused);
    });

    test('a second send is refused while one is running', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(20);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;
      sender.latency = const Duration(milliseconds: 2);

      final first = notifier.sendGroup(group.id, message: 'Salam');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await notifier.sendGroup(group.id, message: 'Salam');
      await first;

      expect(second, isFalse);
      expect(sender.sent.length, 20);
    });

    test('empty message is refused', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(10);
      await notifier.importFromBytes(emptyBytes);
      final group = container.read(excelGroups).groups.first;

      final started = await notifier.sendGroup(group.id, message: '   ');

      expect(started, isFalse);
      expect(sender.sent, isEmpty);
    });

    test('sendAllPending walks through every unfinished group', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(250);
      await notifier.importFromBytes(emptyBytes);

      await notifier.sendAllPending(message: 'Salam');

      final state = container.read(excelGroups);
      expect(sender.sent.length, 250);
      expect(state.totals.sent, 250);
      expect(state.pendingGroupsCount, 0);
      expect(
        state.groups.every((g) => g.statusFor(isActive: false) == GroupStatus.sent),
        isTrue,
      );
    });

    test('resetGroup and resetAll clear statuses but keep numbers', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(150);
      await notifier.importFromBytes(emptyBytes);
      await notifier.sendAllPending(message: 'Salam');
      final groups = container.read(excelGroups).groups;

      await notifier.resetGroup(groups.first.id);

      var state = container.read(excelGroups);
      expect(state.groups[0].counters.sent, 0);
      expect(state.groups[0].total, 100);
      expect(state.groups[0].statusFor(isActive: false), GroupStatus.pending);
      expect(state.groups[1].counters.sent, 50);

      await notifier.resetAll();

      state = container.read(excelGroups);
      expect(state.totals.sent, 0);
      expect(state.totals.total, 150);
      expect(repository.groups.every((g) => g.counters.sent == 0), isTrue);
    });

    test('removeGroup and clearAll delete groups', () async {
      final container = makeContainer(
        repository: repository,
        sender: sender,
        parser: parser,
      );
      final notifier = container.read(excelGroups.notifier);
      parser.next = fakeRecipients(250);
      await notifier.importFromBytes(emptyBytes);
      final groups = container.read(excelGroups).groups;

      await notifier.removeGroup(groups[1].id);

      expect(
        container.read(excelGroups).groups.map((g) => g.index),
        [1, 3],
      );

      await notifier.clearAll();

      expect(container.read(excelGroups).isEmpty, isTrue);
      expect(repository.groups, isEmpty);
    });
  });
}
