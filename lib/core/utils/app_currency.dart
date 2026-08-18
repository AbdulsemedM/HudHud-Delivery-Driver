/// Display currency for the driver app. Always Ethiopian Birr.
class AppCurrency {
  static const String code = 'ETB';

  static String resolve(String? currency) {
    final c = currency?.trim();
    if (c == null || c.isEmpty) return code;
    final upper = c.toUpperCase();
    if (upper == 'USD' || c == r'$') return code;
    return c;
  }

  /// Formats an amount as `ETB 12.50`. Strips a leading `$` or `USD`.
  static String format(Object? amount, {String? currency}) {
    var value = amount?.toString().trim() ?? '';
    if (value.isEmpty || value == '—') return '—';
    value = value.replaceFirst(RegExp(r'^(\$|USD)\s*', caseSensitive: false), '');
    if (value.toUpperCase().startsWith('ETB')) return value;
    return '${resolve(currency)} $value';
  }
}
