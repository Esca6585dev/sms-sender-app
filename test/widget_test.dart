import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/core/device/device_bridge.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/data/groups_repository.dart';
import 'package:sms_sender_app/features/groups/domain/group_batcher.dart';
import 'package:sms_sender_app/features/groups/presentation/groups_page.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/data/campaign_repository.dart';

import 'features/groups/fakes.dart';

Widget buildApp(InMemoryGroupsRepository repository) => ProviderScope(
      overrides: [
        groupsRepositoryProvider.overrideWith((ref, source) => repository),
        smsSenderProvider.overrideWithValue(FakeSmsSender()),
        excelParserProvider.overrideWithValue(FakeExcelParser().call),
        sentNumbersSyncProvider.overrideWithValue(null),
        campaignRepositoryProvider.overrideWithValue(InMemoryCampaignRepository()),
        deviceBridgeProvider.overrideWithValue(NoopDeviceBridge()),
        incomingSmsProvider.overrideWithValue(FakeIncomingSms()),
      ],
      child: const MaterialApp(home: GroupsPage()),
    );

void main() {
  setUp(() {
    // Tall phone so several group cards fit on screen.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('GroupsPage shows restored groups with counters', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final groups = const GroupBatcher().split(fakeRecipients(150));
    await tester.pumpWidget(buildApp(InMemoryGroupsRepository(groups)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Группы рассылки'), findsOneWidget);
    expect(find.text('Групп: 2'), findsOneWidget);
    expect(find.text('Номеров: 150'), findsOneWidget);
    expect(find.text('Отправить все (2)'), findsOneWidget);
    expect(find.text('Группа A'), findsOneWidget);
    expect(find.text('Группа B'), findsOneWidget);
    expect(find.text('№ 1–100 · 100 номеров · ≈ 1,00 TMT'), findsOneWidget);
    expect(find.text('№ 101–150 · 50 номеров · ≈ 0,50 TMT'), findsOneWidget);
    expect(find.text('Ожидает'), findsNWidgets(2));
    expect(find.text('0 / 160 · SMS: 0 · GSM-7'), findsOneWidget);
  });

  testWidgets('empty state offers an Excel import', (tester) async {
    await tester.pumpWidget(buildApp(InMemoryGroupsRepository()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Групп пока нет'), findsOneWidget);
    expect(find.text('Импорт из Excel'), findsOneWidget);
  });

  testWidgets('message counter reacts to typing', (tester) async {
    await tester.pumpWidget(buildApp(InMemoryGroupsRepository()));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Привет' * 15); // 90 chars
    await tester.pump();

    expect(find.text('90 / 134 · SMS: 2 · Unicode'), findsOneWidget);
  });
}
