import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/core/device/device_bridge.dart';
import 'package:sms_sender_app/core/sms/sms_sender.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/data/excel_contacts_parser.dart';
import 'package:sms_sender_app/features/groups/data/groups_repository.dart';
import 'package:sms_sender_app/features/groups/domain/group_batcher.dart';
import 'package:sms_sender_app/features/groups/domain/sms_recipient.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/data/campaign_repository.dart';

/// Records every send; can fail or throw for chosen numbers.
class FakeSmsSender implements SmsSender {
  final List<String> sent = [];
  final Set<String> failing = {};
  final Set<String> throwing = {};
  Duration latency = Duration.zero;

  @override
  Future<SmsSendResult> send({
    required String phone,
    required String message,
    required bool multipart,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (throwing.contains(phone)) throw SmsSendException('limit reached');
    sent.add(phone);
    if (failing.contains(phone)) return const SmsSendResult.failure('no ack');
    return const SmsSendResult.success();
  }
}

/// Returns whatever [next] holds instead of parsing real Excel bytes.
class FakeExcelParser {
  List<SmsRecipient> next = const [];

  Future<ExcelParseResult> call(Uint8List bytes) async => ExcelParseResult(
        recipients: next,
        totalRows: next.length,
        invalidCount: 0,
        duplicateCount: 0,
        emptyCount: 0,
      );
}

List<SmsRecipient> fakeRecipients(int count, {int offset = 0}) => [
      for (var i = offset; i < offset + count; i++)
        SmsRecipient(
          phone: '+9936${(5000000 + i).toString().padLeft(7, '0')}',
          name: 'Client $i',
        ),
    ];

final Uint8List emptyBytes = Uint8List(0);

ProviderContainer makeContainer({
  required InMemoryGroupsRepository repository,
  required FakeSmsSender sender,
  required FakeExcelParser parser,
  InMemoryCampaignRepository? campaigns,
  NoopDeviceBridge? bridge,
  FakeIncomingSms? incomingSms,
  int batchSize = GroupBatcher.defaultBatchSize,
}) {
  final container = ProviderContainer(
    overrides: [
      groupBatcherProvider.overrideWithValue(GroupBatcher(batchSize: batchSize)),
      groupsRepositoryProvider.overrideWithValue(repository),
      smsSenderProvider.overrideWithValue(sender),
      excelParserProvider.overrideWithValue(parser.call),
      sentNumbersSyncProvider.overrideWithValue(null),
      campaignRepositoryProvider
          .overrideWithValue(campaigns ?? InMemoryCampaignRepository()),
      deviceBridgeProvider.overrideWithValue(bridge ?? NoopDeviceBridge()),
      incomingSmsProvider.overrideWithValue(incomingSms ?? FakeIncomingSms()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
