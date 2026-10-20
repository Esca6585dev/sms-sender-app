import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/core/sms/sms_message_info.dart';

void main() {
  group('SmsMessageInfo', () {
    test('empty text needs no SMS', () {
      final info = SmsMessageInfo.analyze('');

      expect(info.isEmpty, isTrue);
      expect(info.length, 0);
      expect(info.parts, 0);
      expect(info.isMultipart, isFalse);
      expect(info.capacity, 160);
    });

    test('GSM-7 text up to 160 characters is a single SMS', () {
      final info = SmsMessageInfo.analyze('a' * 160);

      expect(info.encoding, SmsEncoding.gsm7);
      expect(info.length, 160);
      expect(info.parts, 1);
      expect(info.remaining, 0);
    });

    test('GSM-7 text longer than 160 is split into 153-character parts', () {
      expect(SmsMessageInfo.analyze('a' * 161).parts, 2);
      expect(SmsMessageInfo.analyze('a' * 306).parts, 2);
      expect(SmsMessageInfo.analyze('a' * 307).parts, 3);
      expect(SmsMessageInfo.analyze('a' * 1000).parts, 7);

      final info = SmsMessageInfo.analyze('a' * 200);
      expect(info.isMultipart, isTrue);
      expect(info.capacity, 306);
      expect(info.remaining, 106);
    });

    test('GSM extension characters cost two units', () {
      expect(SmsMessageInfo.analyze('€' * 80).parts, 1);
      expect(SmsMessageInfo.analyze('€' * 80).length, 160);
      expect(SmsMessageInfo.analyze('€' * 81).parts, 2);
      expect(SmsMessageInfo.analyze('{}[]').length, 8);
    });

    test('Cyrillic text uses UCS-2 with 70 / 67 limits', () {
      final single = SmsMessageInfo.analyze('Привет' * 10 + 'Приве'); // 65

      expect(single.encoding, SmsEncoding.ucs2);
      expect(single.length, 65);
      expect(single.parts, 1);
      expect(single.capacity, 70);

      expect(SmsMessageInfo.analyze('я' * 70).parts, 1);
      expect(SmsMessageInfo.analyze('я' * 71).parts, 2);
      expect(SmsMessageInfo.analyze('я' * 134).parts, 2);
      expect(SmsMessageInfo.analyze('я' * 135).parts, 3);
    });

    test('Turkmen letters outside GSM-7 switch to UCS-2', () {
      final info = SmsMessageInfo.analyze('Salam, ýagdaýyňyz nähili?');

      expect(info.encoding, SmsEncoding.ucs2);
      expect(info.parts, 1);
    });

    test('plain Latin Turkmen text stays GSM-7', () {
      final info = SmsMessageInfo.analyze('Salam! Sag bol.');

      expect(info.encoding, SmsEncoding.gsm7);
      expect(info.length, 15);
    });
  });
}
