import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// The trip the backend has measured from the courier's own GPS trail.
///
/// Before this existed the driver app showed the *estimate* as the trip, and
/// posted that estimate back as `actual_distance` / `actual_duration` on
/// completion - so the "actual" values on every finished delivery were the
/// quote, and anything built on them (reports, payouts, disputes) was built
/// on the quote too.
///
/// The backend now totals the location packets the app already sends and
/// serves the result on `driver/services/current-status`, the endpoint the app
/// already polls. That endpoint is cheap on purpose; the detail endpoint is
/// not, which is why this does not live there.
class TripProgress {
  const TripProgress({
    required this.distanceKm,
    required this.durationMinutes,
    required this.source,
    this.startedAt,
    this.points = 0,
  });

  /// Kilometres measured between usable trail points, from pickup onward.
  final double distanceKm;

  /// Whole minutes since pickup, as the server counts them.
  final int durationMinutes;

  /// `gps` when measured, `estimate` when there was too little to measure
  /// with - fewer than three usable points, or no movement at all.
  final String source;

  /// When the trip clock started: the pickup, not the assignment.
  final DateTime? startedAt;

  /// Trail points that survived the accuracy and ordering filters.
  final int points;

  static const String sourceGps = 'gps';
  static const String sourceEstimate = 'estimate';

  bool get isMeasured => source == sourceGps;

  /// Seconds since the trip started, for a display that ticks between polls.
  ///
  /// The server sends whole minutes, which on a five-second poll looks frozen
  /// for eleven polls out of twelve. Counting locally from `startedAt` gives a
  /// clock that moves without asking the network anything.
  int elapsedSecondsAt(DateTime now) {
    final from = startedAt;
    if (from == null) return durationMinutes * 60;
    final seconds = now.difference(from).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  static TripProgress? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;

    final distance = JsonParse.toDouble(map['distance_km']);
    final duration = JsonParse.toInt(map['duration_minutes']);
    if (distance == null && duration == null) return null;

    DateTime? startedAt;
    final startedRaw = map['started_at']?.toString();
    if (startedRaw != null && startedRaw.isNotEmpty) {
      startedAt = DateTime.tryParse(startedRaw)?.toLocal();
    }

    return TripProgress(
      distanceKm: distance ?? 0,
      durationMinutes: duration ?? 0,
      source: map['source']?.toString() ?? sourceEstimate,
      startedAt: startedAt,
      points: JsonParse.toInt(map['points']) ?? 0,
    );
  }

  /// `1:05:09` past an hour, `12:20` below it. A courier reads a clock faster
  /// than "12 minutes 20 seconds", and it visibly moves every second.
  static String formatElapsed(int totalSeconds) {
    final s = totalSeconds < 0 ? 0 : totalSeconds;
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final seconds = s % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
  }
}
