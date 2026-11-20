import 'package:easy_localization/easy_localization.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// When a customer requested a job, for the "Requested …" line on available
/// delivery / food cards and the new-request pop-up.
///
/// The API is read defensively: `requested_at`, then `created_at`, then
/// `placed_at`. When none is sent the line is simply not shown.
class RequestTime {
  RequestTime._();

  static const List<String> _keys = ['requested_at', 'created_at', 'placed_at'];

  /// Local time the job was requested, or null when the row has none.
  static DateTime? of(Map<String, dynamic>? row) {
    if (row == null) return null;
    for (final key in _keys) {
      final at = JsonParse.toDateTime(row[key]);
      if (at != null) return at.toLocal();
    }
    return null;
  }

  /// Whole minutes since [at]; 0 when [at] is in the future (phone clock
  /// behind the server's).
  static int minutesAgo(DateTime at, DateTime now) {
    final minutes = now.difference(at).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  /// 0 = today, 1 = yesterday, 2+ = older (calendar days, local time).
  static int daysAgo(DateTime at, DateTime now) {
    final a = DateTime(at.year, at.month, at.day);
    final b = DateTime(now.year, now.month, now.day);
    final days = b.difference(a).inDays;
    return days < 0 ? 0 : days;
  }

  /// "Today, 14:05" / "Yesterday, 09:10" / "Nov 18, 14:05".
  static String dateTimeLabel(DateTime at, {DateTime? now}) {
    final clock = DateFormat('HH:mm').format(at);
    switch (daysAgo(at, now ?? DateTime.now())) {
      case 0:
        return 'request_time.today'.tr(namedArgs: {'time': clock});
      case 1:
        return 'request_time.yesterday'.tr(namedArgs: {'time': clock});
      default:
        return '${DateFormat('MMM d').format(at)}, $clock';
    }
  }

  /// "just now" / "5 min ago" / "2 h ago"; null after a day (the date
  /// already says enough).
  static String? agoLabel(DateTime at, {DateTime? now}) {
    final minutes = minutesAgo(at, now ?? DateTime.now());
    if (minutes < 1) return 'request_time.just_now'.tr();
    if (minutes < 60) {
      return 'request_time.minutes_ago'
          .tr(namedArgs: {'count': minutes.toString()});
    }
    if (minutes < 24 * 60) {
      return 'request_time.hours_ago'
          .tr(namedArgs: {'count': (minutes ~/ 60).toString()});
    }
    return null;
  }

  /// "Requested Today, 14:05 · 5 min ago", or null when the row has no time.
  static String? describe(Map<String, dynamic>? row, {DateTime? now}) {
    final at = of(row);
    return at == null ? null : describeAt(at, now: now);
  }

  static String describeAt(DateTime at, {DateTime? now}) {
    final when = dateTimeLabel(at, now: now);
    final ago = agoLabel(at, now: now);
    final text = ago == null ? when : '$when · $ago';
    return 'request_time.requested'.tr(namedArgs: {'when': text});
  }
}
