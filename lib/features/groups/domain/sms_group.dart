import 'sms_recipient.dart';

/// Aggregated state of a group, derived from its recipients.
enum GroupStatus {
  /// Nothing sent yet.
  pending,

  /// This group is being sent right now.
  inProgress,

  /// Some numbers sent, some still pending (stopped by the operator).
  paused,

  /// Finished, but at least one number failed.
  partial,

  /// Every number was sent successfully.
  sent,
}

/// Counters for a group (or for all groups when summed).
class GroupCounters {
  const GroupCounters({
    required this.total,
    required this.sent,
    required this.failed,
    required this.sending,
  });

  static const GroupCounters zero =
      GroupCounters(total: 0, sent: 0, failed: 0, sending: 0);

  factory GroupCounters.of(Iterable<SmsRecipient> recipients) {
    var total = 0;
    var sent = 0;
    var failed = 0;
    var sending = 0;
    for (final r in recipients) {
      total++;
      switch (r.status) {
        case RecipientStatus.sent:
          sent++;
        case RecipientStatus.failed:
          failed++;
        case RecipientStatus.sending:
          sending++;
        case RecipientStatus.pending:
          break;
      }
    }
    return GroupCounters(
      total: total,
      sent: sent,
      failed: failed,
      sending: sending,
    );
  }

  final int total;
  final int sent;
  final int failed;
  final int sending;

  int get pending => total - sent - failed - sending;

  /// Numbers that still need an SMS (pending + failed + sending).
  int get remaining => total - sent;

  double get progress => total == 0 ? 0 : sent / total;

  int get percent => (progress * 100).round();

  GroupCounters operator +(GroupCounters other) => GroupCounters(
        total: total + other.total,
        sent: sent + other.sent,
        failed: failed + other.failed,
        sending: sending + other.sending,
      );
}

/// A batch of (at most) 100 recipients created from an Excel import.
///
/// Immutable: every change produces a new instance via [copyWith],
/// [updateRecipient] or [reset].
class SmsGroup {
  SmsGroup({
    required this.id,
    required this.index,
    required this.startNumber,
    required List<SmsRecipient> recipients,
  })  : recipients = List<SmsRecipient>.unmodifiable(recipients),
        counters = GroupCounters.of(recipients);

  factory SmsGroup.fromJson(Map<String, dynamic> json) => SmsGroup(
        id: json['id'] as String,
        index: json['index'] as int,
        startNumber: json['startNumber'] as int? ?? 1,
        recipients: ((json['recipients'] as List?) ?? const [])
            .map((e) => SmsRecipient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;

  /// 1-based ordinal: "Группа 1", "Группа 2"…
  final int index;

  /// 1-based position of the first recipient in the imported list.
  final int startNumber;

  final List<SmsRecipient> recipients;

  /// Counters computed once per instance (the instance is immutable).
  final GroupCounters counters;

  int get total => recipients.length;

  int get endNumber => startNumber + recipients.length - 1;

  String get title => 'Группа $index';

  String get rangeLabel => '№ $startNumber–$endNumber';

  GroupStatus statusFor({required bool isActive}) {
    if (isActive) return GroupStatus.inProgress;
    final c = counters;
    if (c.total > 0 && c.sent == c.total) return GroupStatus.sent;
    if (c.sent == 0 && c.failed == 0) return GroupStatus.pending;
    if (c.pending == 0 && c.sending == 0) return GroupStatus.partial;
    return GroupStatus.paused;
  }

  SmsGroup copyWith({List<SmsRecipient>? recipients}) => SmsGroup(
        id: id,
        index: index,
        startNumber: startNumber,
        recipients: recipients ?? this.recipients,
      );

  SmsGroup updateRecipient(
    int position,
    SmsRecipient Function(SmsRecipient current) update,
  ) {
    final list = List<SmsRecipient>.of(recipients);
    list[position] = update(list[position]);
    return copyWith(recipients: list);
  }

  /// All recipients back to pending; numbers are kept.
  SmsGroup reset() =>
      copyWith(recipients: [for (final r in recipients) r.reset()]);

  Map<String, dynamic> toJson() => {
        'id': id,
        'index': index,
        'startNumber': startNumber,
        'recipients': [for (final r in recipients) r.toJson()],
      };

  @override
  String toString() =>
      'SmsGroup($title, $rangeLabel, sent ${counters.sent}/${counters.total})';
}
