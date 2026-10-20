import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/core/utils/phone_normalizer.dart';

void main() {
  group('PhoneNormalizer', () {
    test('accepts every common Turkmen format', () {
      expect(PhoneNormalizer.normalize('+99365123456'), '+99365123456');
      expect(PhoneNormalizer.normalize('+993 65 12-34-56'), '+99365123456');
      expect(PhoneNormalizer.normalize('99365123456'), '+99365123456');
      expect(PhoneNormalizer.normalize('0099365123456'), '+99365123456');
      expect(PhoneNormalizer.normalize('865123456'), '+99365123456');
      expect(PhoneNormalizer.normalize('8 (65) 12 34 56'), '+99365123456');
      expect(PhoneNormalizer.normalize('65123456'), '+99365123456');
    });

    test('rejects everything else', () {
      expect(PhoneNormalizer.normalize(''), isNull);
      expect(PhoneNormalizer.normalize('abc'), isNull);
      expect(PhoneNormalizer.normalize('6512345'), isNull);
      expect(PhoneNormalizer.normalize('651234567'), isNull);
      expect(PhoneNormalizer.normalize('+7 999 123 45 67'), isNull);
      expect(PhoneNormalizer.normalize('993651234560'), isNull);
    });

    test('isValid checks the canonical form only', () {
      expect(PhoneNormalizer.isValid('+99365123456'), isTrue);
      expect(PhoneNormalizer.isValid('99365123456'), isFalse);
      expect(PhoneNormalizer.isValid('+9936512345'), isFalse);
    });
  });
}
