import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/features/groups/data/excel_contacts_parser.dart';
import 'package:sms_sender_app/features/groups/data/groups_repository.dart';
import 'package:sms_sender_app/features/groups/data/sent_numbers_sync.dart';
import 'package:sms_sender_app/features/groups/domain/group_batcher.dart';
import 'package:sms_sender_app/features/groups/domain/group_source.dart';
import 'package:sms_sender_app/shared/providers/app_providers.dart';

// The device sender lives next to the SIM choice / balance it depends on.
export 'package:sms_sender_app/features/balance/balance_controller.dart'
    show smsSenderProvider;

/// Parses an `.xlsx` file. Injected so tests can skip the real parser.
typedef ExcelParser = Future<ExcelParseResult> Function(Uint8List bytes);

/// Dependencies of the groups feature. Every one of them can be overridden
/// in a `ProviderScope` / `ProviderContainer` for tests.
final groupsRepositoryProvider = Provider.family<GroupsRepository, GroupSource>(
  (ref, source) => SharedPrefsGroupsRepository(storageKey: source.storageKey),
);

/// Runs the Excel parser on a background isolate so a 5 000-row file does
/// not freeze the UI.
final excelParserProvider = Provider<ExcelParser>(
  (ref) => (bytes) => compute(ExcelContactsParser.parseBytes, bytes),
);

final groupBatcherProvider = Provider<GroupBatcher>(
  (ref) => const GroupBatcher(batchSize: GroupBatcher.defaultBatchSize),
);

final sentNumbersSyncProvider = Provider<SentNumbersSync?>(
  (ref) => ApiSentNumbersSync(ref.watch(apiServiceProvider)),
);

/// How long to wait when the phone refuses to send (SMS limit) before the
/// same number is retried: 2, 5, 15 then 30 minutes, repeated.
final limitWaitScheduleProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ],
);

/// Pause between two SMS, in milliseconds.
class SendDelayController extends Notifier<int> {
  static const List<int> options = [0, 500, 1000, 2000];

  @override
  int build() => 500;

  void select(int milliseconds) => state = milliseconds;
}

final sendDelayProvider =
    NotifierProvider<SendDelayController, int>(SendDelayController.new);
