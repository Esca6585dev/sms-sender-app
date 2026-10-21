import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/features/groups/domain/group_batcher.dart';

import 'fakes.dart';

void main() {
  group('GroupBatcher', () {
    test('1000 numbers become 10 groups of exactly 100', () {
      final groups = const GroupBatcher().split(fakeRecipients(1000));

      expect(groups.length, 10);
      expect(groups.every((g) => g.total == 100), isTrue);
      expect(groups.first.title, 'Группа A');
      expect(groups.last.title, 'Группа J');
      expect(groups.first.rangeLabel, '№ 1–100');
      expect(groups[1].rangeLabel, '№ 101–200');
      expect(groups.last.rangeLabel, '№ 901–1000');
      expect(groups.first.recipients.first.phone, '+99365000000');
      expect(groups[1].recipients.first.phone, '+99365000100');
    });

    test('the last group keeps the remainder', () {
      final groups = const GroupBatcher().split(fakeRecipients(250));

      expect(groups.map((g) => g.total), [100, 100, 50]);
      expect(groups.last.startNumber, 201);
      expect(groups.last.endNumber, 250);
    });

    test('empty input produces no groups', () {
      expect(const GroupBatcher().split(const []), isEmpty);
    });

    test('custom batch size and continued numbering', () {
      final groups = const GroupBatcher(batchSize: 3).split(
        fakeRecipients(7),
        firstIndex: 4,
        firstNumber: 10,
      );

      expect(groups.map((g) => g.index), [4, 5, 6]);
      expect(groups.map((g) => g.total), [3, 3, 1]);
      expect(groups.map((g) => g.startNumber), [10, 13, 16]);
      expect(groups.last.endNumber, 16);
    });

    test('ids are unique', () {
      final groups = const GroupBatcher(batchSize: 1).split(fakeRecipients(50));

      expect(groups.map((g) => g.id).toSet().length, 50);
    });
  });
}
