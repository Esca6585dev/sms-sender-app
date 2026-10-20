import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sender_app/features/groups/data/excel_contacts_parser.dart';

Uint8List buildWorkbook(List<List<dynamic>> rows) {
  final book = xl.Excel.createExcel();
  final sheet = book.tables.keys.first;
  for (final row in rows) {
    book.appendRow(sheet, row);
  }
  return Uint8List.fromList(book.encode()!);
}

void main() {
  group('ExcelContactsParser', () {
    test('reads name/phone from columns C/D, normalises and de-duplicates', () {
      final bytes = buildWorkbook([
        ['ID', 'Дата', 'Имя', 'Телефон'],
        [1, '2024-01-01', 'Aman', '+993 65 12 34 56'],
        [2, '2024-01-02', 'Jeren', 99365123457],
        [3, '2024-01-03', 'Dup', '99365123456'],
        [4, '2024-01-04', 'Bad', 'abc'],
        [5, '2024-01-05', 'Dbl', 99365123459.0],
        [6, '2024-01-06', 'Trunk', '8 65 12 34 60'],
      ]);

      final result = ExcelContactsParser.parseBytes(bytes);

      expect(result.totalRows, 7);
      expect(result.recipients.map((r) => r.phone), [
        '+99365123456',
        '+99365123457',
        '+99365123459',
        '+99365123460',
      ]);
      expect(result.recipients.map((r) => r.name), [
        'Aman',
        'Jeren',
        'Dbl',
        'Trunk',
      ]);
      expect(result.invalidCount, 2); // header + "abc"
      expect(result.duplicateCount, 1);
      expect(result.emptyCount, 0);
    });

    test('falls back to column detection for a two-column file', () {
      final bytes = buildWorkbook([
        ['Maya', '865123458'],
        ['+99365123461', 'Berdi'],
        ['', ''],
        ['no phone here', 'really'],
      ]);

      final result = ExcelContactsParser.parseBytes(bytes);

      expect(result.recipients.length, 2);
      expect(result.recipients[0].phone, '+99365123458');
      expect(result.recipients[0].name, 'Maya');
      expect(result.recipients[1].phone, '+99365123461');
      expect(result.recipients[1].name, 'Berdi');
      expect(result.invalidCount, 1);
      expect(result.emptyCount, result.totalRows - 3);
    });

    test('never mistakes a date for a phone number', () {
      final bytes = buildWorkbook([
        ['2024-01-01', '01.01.2024', 'Nobody'],
      ]);

      final result = ExcelContactsParser.parseBytes(bytes);

      expect(result.recipients, isEmpty);
      expect(result.invalidCount, 1);
    });

    test('strict column mode ignores other columns', () {
      final bytes = buildWorkbook([
        ['Maya', '865123458'],
      ]);

      final result = const ExcelContactsParser(detectColumns: false)
          .parse(bytes);

      expect(result.recipients, isEmpty);
      expect(result.invalidCount, 1);
    });
  });
}
