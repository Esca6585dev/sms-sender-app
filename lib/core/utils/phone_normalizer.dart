/// Normalises Turkmen phone numbers to the canonical `+993XXXXXXXX` form.
class PhoneNormalizer {
  const PhoneNormalizer._();

  static final RegExp _canonical = RegExp(r'^\+993\d{8}$');
  static final RegExp _nonDigits = RegExp(r'[^0-9]');

  /// Returns the canonical number or `null` when [raw] is not a valid
  /// Turkmen number.
  ///
  /// Accepted inputs: `+993 65 12 34 56`, `99365123456`, `0099365123456`,
  /// `865123456` (national trunk prefix `8`) and plain `65123456`.
  static String? normalize(String raw) {
    var digits = raw.replaceAll(_nonDigits, '');
    if (digits.isEmpty) return null;

    if (digits.length == 13 && digits.startsWith('00993')) {
      digits = digits.substring(5);
    } else if (digits.length == 11 && digits.startsWith('993')) {
      digits = digits.substring(3);
    } else if (digits.length == 9 && digits.startsWith('8')) {
      digits = digits.substring(1);
    }

    if (digits.length != 8) return null;
    return '+993$digits';
  }

  /// `true` when [phone] is already in canonical form.
  static bool isValid(String phone) => _canonical.hasMatch(phone);
}
