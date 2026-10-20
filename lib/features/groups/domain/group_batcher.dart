import 'dart:math' as math;

import 'sms_group.dart';
import 'sms_recipient.dart';

/// Splits a flat list of recipients into [SmsGroup]s of exactly [batchSize]
/// numbers (the last group holds the remainder).
class GroupBatcher {
  const GroupBatcher({this.batchSize = defaultBatchSize})
      : assert(batchSize > 0, 'batchSize must be positive');

  static const int defaultBatchSize = 100;

  final int batchSize;

  static final math.Random _random = math.Random();

  /// [firstIndex] and [firstNumber] let a second import continue the
  /// numbering of the groups that already exist.
  List<SmsGroup> split(
    List<SmsRecipient> recipients, {
    int firstIndex = 1,
    int firstNumber = 1,
    String Function(int index)? idFor,
  }) {
    final groups = <SmsGroup>[];
    for (var offset = 0; offset < recipients.length; offset += batchSize) {
      final end = math.min(offset + batchSize, recipients.length);
      final index = firstIndex + groups.length;
      groups.add(
        SmsGroup(
          id: idFor?.call(index) ?? _generateId(index),
          index: index,
          startNumber: firstNumber + offset,
          recipients: recipients.sublist(offset, end),
        ),
      );
    }
    return groups;
  }

  static String _generateId(int index) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(1 << 20);
    return 'g$index-$stamp-$salt';
  }
}
