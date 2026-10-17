import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sender_app/sms_send_coordinator.dart';

void main() {
  group('SmsSendCoordinator', () {
    test('blocks duplicate sends for the same phone while one is in flight', () async {
      final coordinator = SmsSendCoordinator();
      var started = 0;

      final futures = <Future<bool>>[
        coordinator.runPhoneSend('123456', () async {
          started++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return true;
        }),
        coordinator.runPhoneSend('123456', () async {
          started++;
          return true;
        }),
      ];

      final results = await Future.wait(futures);

      expect(results, [true, false]);
      expect(started, 1);
    });

    test('allows a second attempt after the previous one completes', () async {
      final coordinator = SmsSendCoordinator();

      final first = await coordinator.runPhoneSend('654321', () async => true);
      final second = await coordinator.runPhoneSend('654321', () async => true);

      expect(first, true);
      expect(second, true);
    });
  });
}
