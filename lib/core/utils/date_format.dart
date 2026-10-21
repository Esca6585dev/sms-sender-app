/// Small date helpers so the app does not need the `intl` package.
class DateFormatting {
  const DateFormatting._();

  static const List<String> weekdayShort = [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс',
  ];

  static String two(int value) => value.toString().padLeft(2, '0');

  /// `21.10.2026`
  static String date(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';

  /// `14:05`
  static String time(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

  /// `21.10.2026 14:05`
  static String dateTime(DateTime d) => '${date(d)} ${time(d)}';

  /// `Сегодня`, `Вчера` or the date.
  static String relativeDate(DateTime d, {DateTime? now}) {
    final today = _dayOf(now ?? DateTime.now());
    final day = _dayOf(d);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return date(d);
  }

  /// `2 мин 10 сек`
  static String duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    if (minutes == 0) return '$seconds сек';
    return '$minutes мин $seconds сек';
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}
