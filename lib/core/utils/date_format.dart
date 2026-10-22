import 'package:sms_sender_app/l10n/strings.dart';

/// Small date helpers so the app does not need the `intl` package.
class DateFormatting {
  const DateFormatting._();

  static List<String> get weekdayShort => S.current.weekdaysShort;

  static String two(int value) => value.toString().padLeft(2, '0');

  /// `21.10.2026`
  static String date(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';

  /// `14:05`
  static String time(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

  /// `21.10.2026 14:05`
  static String dateTime(DateTime d) => '${date(d)} ${time(d)}';

  /// Today / yesterday (localised) or the date.
  static String relativeDate(DateTime d, {DateTime? now}) {
    final today = _dayOf(now ?? DateTime.now());
    final day = _dayOf(d);
    final diff = today.difference(day).inDays;
    if (diff == 0) return S.current.today;
    if (diff == 1) return S.current.yesterday;
    return date(d);
  }

  /// `2 min 10 s` (localised units).
  static String duration(Duration value) =>
      S.current.minutesSeconds(value.inMinutes, value.inSeconds % 60);

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}
