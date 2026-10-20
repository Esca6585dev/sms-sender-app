/// Encoding the mobile network will use for a given SMS text.
enum SmsEncoding {
  /// 7-bit GSM 03.38 alphabet (Latin letters, digits, basic punctuation).
  /// 160 characters fit into one SMS, 153 per part when concatenated.
  gsm7,

  /// UCS-2. Chosen as soon as the text contains Cyrillic, Turkmen letters such
  /// as ş/ý/ž/ň, emoji… 70 characters per single SMS, 67 per part.
  ucs2,
}

/// Immutable analysis of a message text: which encoding the network will pick,
/// how long the text is in encoding units and how many SMS parts it needs.
///
/// Pure Dart, no Flutter dependency, so it is cheap to run on every keystroke
/// and trivial to unit-test.
class SmsMessageInfo {
  const SmsMessageInfo._({
    required this.encoding,
    required this.length,
    required this.parts,
  });

  /// Analyses [text] and returns the resulting [SmsMessageInfo].
  factory SmsMessageInfo.analyze(String text) {
    if (text.isEmpty) {
      return const SmsMessageInfo._(
        encoding: SmsEncoding.gsm7,
        length: 0,
        parts: 0,
      );
    }

    var septets = 0;
    var isGsm7 = true;
    for (final rune in text.runes) {
      if (_gsmBasicSet.contains(rune)) {
        septets += 1;
      } else if (_gsmExtensionSet.contains(rune)) {
        // Extension-table characters are sent as ESC + char (2 septets).
        septets += 2;
      } else {
        isGsm7 = false;
        break;
      }
    }

    if (isGsm7) {
      return SmsMessageInfo._(
        encoding: SmsEncoding.gsm7,
        length: septets,
        parts: _partsFor(septets, gsm7SingleLimit, gsm7MultiLimit),
      );
    }

    // UCS-2 is billed per UTF-16 code unit, which is exactly `String.length`.
    final units = text.length;
    return SmsMessageInfo._(
      encoding: SmsEncoding.ucs2,
      length: units,
      parts: _partsFor(units, ucs2SingleLimit, ucs2MultiLimit),
    );
  }

  static const int gsm7SingleLimit = 160;
  static const int gsm7MultiLimit = 153;
  static const int ucs2SingleLimit = 70;
  static const int ucs2MultiLimit = 67;

  /// Encoding the network will use.
  final SmsEncoding encoding;

  /// Length in encoding units (septets for GSM-7, UTF-16 units for UCS-2).
  final int length;

  /// Number of SMS parts that will be sent and billed. `0` for empty text.
  final int parts;

  bool get isEmpty => length == 0;

  /// `true` when the message has to be sent as a concatenated (multipart) SMS.
  bool get isMultipart => parts > 1;

  int get singlePartLimit =>
      encoding == SmsEncoding.gsm7 ? gsm7SingleLimit : ucs2SingleLimit;

  int get multiPartLimit =>
      encoding == SmsEncoding.gsm7 ? gsm7MultiLimit : ucs2MultiLimit;

  /// Maximum number of units that fit into the current number of [parts].
  int get capacity => parts <= 1 ? singlePartLimit : parts * multiPartLimit;

  /// Units left before one more part is needed.
  int get remaining => capacity - length;

  static int _partsFor(int length, int singleLimit, int multiLimit) {
    if (length == 0) return 0;
    if (length <= singleLimit) return 1;
    return (length / multiLimit).ceil();
  }

  // GSM 03.38 basic character table.
  static const String _gsmBasic =
      '@£\$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !"#¤%&\'()*+,-./0123456789:;<=>?'
      '¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà';

  // GSM 03.38 extension table (each costs two septets).
  static const String _gsmExtension = '\f^{}\\[~]|€';

  static final Set<int> _gsmBasicSet = _gsmBasic.runes.toSet();
  static final Set<int> _gsmExtensionSet = _gsmExtension.runes.toSet();

  @override
  String toString() =>
      'SmsMessageInfo(encoding: ${encoding.name}, length: $length, parts: $parts)';
}
