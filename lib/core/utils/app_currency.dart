/// Display currency and shared numeric formatting for the driver app UI.
class AppCurrency {
  static const String code = 'ETB';
  static const int defaultFractionDigits = 2;

  static String resolve(String? currency) {
    final c = currency?.trim();
    if (c == null || c.isEmpty) return code;
    final upper = c.toUpperCase();
    if (upper == 'USD' || c == r'$') return code;
    return c;
  }

  /// Rounds [value] to [fractionDigits] decimal places for display.
  static String formatDecimal(
    num? value, {
    int fractionDigits = defaultFractionDigits,
  }) {
    if (value == null) return '—';
    return _round(value, fractionDigits);
  }

  /// Formats an amount as `ETB 12.50`. Strips a leading `$` or `USD`.
  static String format(Object? amount, {String? currency}) {
    if (amount == null) return '—';

    if (amount is num) {
      return '${resolve(currency)} ${_round(amount, defaultFractionDigits)}';
    }

    var value = amount.toString().trim();
    if (value.isEmpty || value == '—') return '—';
    value = value.replaceFirst(
      RegExp(r'^(\$|USD)\s*', caseSensitive: false),
      '',
    );

    final etbMatch = RegExp(
      r'^ETB\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (etbMatch != null) {
      final parsed = _tryParse(etbMatch.group(1));
      if (parsed != null) {
        return '${resolve(currency)} ${_round(parsed, defaultFractionDigits)}';
      }
      return value;
    }

    final parsed = _tryParse(value);
    if (parsed != null) {
      return '${resolve(currency)} ${_round(parsed, defaultFractionDigits)}';
    }

    return '${resolve(currency)} $value';
  }

  static double? _tryParse(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static String _round(num value, int fractionDigits) {
    final factor = _pow10(fractionDigits);
    final rounded = (value * factor).roundToDouble() / factor;
    return rounded.toStringAsFixed(fractionDigits);
  }

  static int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}
