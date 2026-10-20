import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;

import 'package:sms_sender_app/core/utils/phone_normalizer.dart';
import 'package:sms_sender_app/features/groups/domain/sms_recipient.dart';

/// Result of parsing one Excel workbook.
class ExcelParseResult {
  const ExcelParseResult({
    required this.recipients,
    required this.totalRows,
    required this.invalidCount,
    required this.duplicateCount,
    required this.emptyCount,
  });

  static const ExcelParseResult empty = ExcelParseResult(
    recipients: [],
    totalRows: 0,
    invalidCount: 0,
    duplicateCount: 0,
    emptyCount: 0,
  );

  /// Unique, valid recipients in file order.
  final List<SmsRecipient> recipients;

  /// Rows in the first sheet (including header and empty rows).
  final int totalRows;

  /// Rows that contained no valid Turkmen phone number (headers included).
  final int invalidCount;

  /// Rows whose number was already seen earlier in the file.
  final int duplicateCount;

  /// Completely blank rows.
  final int emptyCount;

  int get importedCount => recipients.length;
}

/// Reads `name` / `phone` pairs from the first sheet of an `.xlsx` file.
///
/// The configured columns are tried first (the existing export has the name
/// in column C and the phone in column D). When they do not hold a valid
/// number the row is scanned for any cell that looks like a phone, so files
/// with a different layout still import.
class ExcelContactsParser {
  const ExcelContactsParser({
    this.nameColumn = 2,
    this.phoneColumn = 3,
    this.detectColumns = true,
  });

  final int nameColumn;
  final int phoneColumn;
  final bool detectColumns;

  /// Entry point suitable for `compute()`: parses on a background isolate.
  static ExcelParseResult parseBytes(Uint8List bytes) =>
      const ExcelContactsParser().parse(bytes);

  ExcelParseResult parse(List<int> bytes) {
    final workbook = xl.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) return ExcelParseResult.empty;

    final sheet = workbook.tables.values.first;
    final seen = <String>{};
    final recipients = <SmsRecipient>[];
    var invalid = 0;
    var duplicates = 0;
    var empty = 0;

    for (final row in sheet.rows) {
      final cells = [for (final cell in row) _cellText(cell)];
      if (cells.every((c) => c.isEmpty)) {
        empty++;
        continue;
      }

      final picked = _pick(cells);
      if (picked == null) {
        invalid++;
        continue;
      }
      if (!seen.add(picked.phone)) {
        duplicates++;
        continue;
      }
      recipients.add(SmsRecipient(phone: picked.phone, name: picked.name));
    }

    return ExcelParseResult(
      recipients: recipients,
      totalRows: sheet.rows.length,
      invalidCount: invalid,
      duplicateCount: duplicates,
      emptyCount: empty,
    );
  }

  _PickedRow? _pick(List<String> cells) {
    if (cells.length > phoneColumn) {
      final phone = _phoneFromCell(cells[phoneColumn]);
      if (phone != null) {
        final name = cells.length > nameColumn ? cells[nameColumn] : '';
        return _PickedRow(phone, name);
      }
    }

    if (!detectColumns) return null;

    // Fallback: the right-most cell that is a valid phone; the name is the
    // first non-empty cell that is not a phone number.
    for (var i = cells.length - 1; i >= 0; i--) {
      final phone = _phoneFromCell(cells[i]);
      if (phone == null) continue;
      var name = '';
      for (var j = 0; j < cells.length; j++) {
        if (j == i || cells[j].isEmpty) continue;
        if (_phoneFromCell(cells[j]) != null) continue;
        name = cells[j];
        break;
      }
      return _PickedRow(phone, name);
    }
    return null;
  }

  // Only digits, spaces, "+", "-", "(" and ")" may appear in a phone cell.
  static final RegExp _phoneChars = RegExp(r'^[+\d\s()\-]+$');

  // `2024-01-01` / `01.01.2024` have 8 digits and must never become a phone.
  static final RegExp _isoDate = RegExp(r'^\d{4}[-./]\d{1,2}[-./]\d{1,2}$');
  static final RegExp _euDate = RegExp(r'^\d{1,2}[-./]\d{1,2}[-./]\d{4}$');

  static String? _phoneFromCell(String cell) {
    if (cell.isEmpty || !_phoneChars.hasMatch(cell)) return null;
    if (_isoDate.hasMatch(cell) || _euDate.hasMatch(cell)) return null;
    return PhoneNormalizer.normalize(cell);
  }

  /// Excel stores numbers as doubles: `99365123456.0` must become
  /// `99365123456`, not `993651234560` after stripping the dot.
  static String _cellText(xl.Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    if (value is double) {
      if (value == value.truncateToDouble() && value.abs() < 1e15) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    return value.toString().trim();
  }
}

class _PickedRow {
  const _PickedRow(this.phone, this.name);

  final String phone;
  final String name;
}
