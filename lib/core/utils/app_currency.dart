/// Display currency and shared numeric formatting for the driver app UI.
///
/// ETB (Addis Ababa) shows as `ETB 12.50`. USD (Hargeisa drivers, Phase 6)
/// shows as `$12.50` — but only when the API says the currency is USD: a
/// bare `$` inside an amount string with no currency is a legacy placeholder
/// and still renders as ETB.
class AppCurrency {
  static const String code = 'ETB';
  static const String usd = 'USD';
  static const int defaultFractionDigits = 2;

  /// ISO code to display: blank → `ETB`; `USD` / `$` → `USD`; else as sent.
  static String resolve(String? currency) {
    final c = currency?.trim();
    if (c == null || c.isEmpty) return code;
    final upper = c.toUpperCase();
    if (upper == usd || c == r'$') return usd;
    if (upper == code) return code;
    return c;
  }

  static bool isUsd(String? currency) => resolve(currency) == usd;

  /// Text placed before an amount: `$` for USD, else the code and a space.
  static String prefix(String? currency) {
    final resolved = resolve(currency);
    return resolved == usd ? r'$' : '$resolved ';
  }

  /// Rounds [value] to [fractionDigits] decimal places for display.
  static String formatDecimal(
    num? value, {
    int fractionDigits = defaultFractionDigits,
  }) {
    if (value == null) return '—';
    return _round(value, fractionDigits);
  }

  /// Formats an amount as `ETB 12.50` (or `$12.50` when [currency] is USD).
  /// A leading `$` / `USD` in a string amount is stripped.
  static String format(Object? amount, {String? currency}) {
    if (amount == null) return '—';

    if (amount is num) {
      return _withPrefix(amount, currency);
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
        return _withPrefix(parsed, currency);
      }
      return value;
    }

    final parsed = _tryParse(value);
    if (parsed != null) {
      return _withPrefix(parsed, currency);
    }

    return '${prefix(currency)}$value';
  }

  static String _withPrefix(num value, String? currency) {
    final p = prefix(currency);
    if (value < 0 && p == r'$') {
      return '-$p${_round(-value, defaultFractionDigits)}';
    }
    return '$p${_round(value, defaultFractionDigits)}';
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
