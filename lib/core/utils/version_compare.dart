/// Semver-ish comparison for store / app versions (`1.2.3`, `1.2.3+10`, etc.).
class VersionCompare {
  VersionCompare._();

  /// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
  static int compare(String a, String b) {
    final aParts = _parts(a);
    final bParts = _parts(b);
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < len; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  static bool isOlderThan(String current, String store) =>
      compare(current, store) < 0;

  static List<int> _parts(String version) {
    final cleaned = version.split('+').first.split('-').first.trim();
    if (cleaned.isEmpty) return const [0];
    return cleaned
        .split('.')
        .map((p) => int.tryParse(RegExp(r'\d+').firstMatch(p)?.group(0) ?? '') ?? 0)
        .toList();
  }
}
