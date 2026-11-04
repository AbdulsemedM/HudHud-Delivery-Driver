import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// One peak window of a quest, e.g. days [1..7], 12:00–14:00 (city time).
class QuestWindow {
  const QuestWindow({
    this.days = const [],
    required this.start,
    required this.end,
  });

  /// ISO weekdays, 1 = Monday … 7 = Sunday.
  final List<int> days;
  final String start;
  final String end;

  /// `12:00–14:00`.
  String get label => '$start–$end';

  static QuestWindow? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    final start = _hhmm(map['start']);
    final end = _hhmm(map['end']);
    if (start == null || end == null) return null;
    final days = <int>[];
    final daysRaw = map['days'];
    if (daysRaw is List) {
      for (final d in daysRaw) {
        final day = JsonParse.toInt(d) ?? JsonParse.toDouble(d)?.round();
        if (day != null && day >= 1 && day <= 7) days.add(day);
      }
    }
    return QuestWindow(days: days, start: start, end: end);
  }

  /// Normalises `12:00:00` / `12:00` to `12:00`.
  static String? _hhmm(dynamic raw) {
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
    if (match == null) return s;
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }
}

/// One entry of `GET /api/driver/quests`.
class DriverQuest {
  const DriverQuest({
    this.id,
    required this.title,
    this.description,
    this.target = 0,
    this.completedToday = 0,
    this.rewardAmount,
    this.currency,
    this.windows = const [],
    this.activeNow = false,
    this.rewardedToday = false,
  });

  final int? id;
  final String title;
  final String? description;
  final int target;
  final int completedToday;
  final double? rewardAmount;
  final String? currency;
  final List<QuestWindow> windows;
  final bool activeNow;
  final bool rewardedToday;

  /// 0.0 – 1.0 for a progress bar.
  double get progress {
    if (target <= 0) return rewardedToday ? 1.0 : 0.0;
    final value = completedToday / target;
    if (value < 0) return 0.0;
    if (value > 1) return 1.0;
    return value;
  }

  /// `3/8`.
  String get progressLabel => '$completedToday/$target';

  /// `12:00–14:00, 18:00–21:00` (distinct windows, in API order).
  String get windowsLabel {
    final seen = <String>{};
    final labels = <String>[];
    for (final w in windows) {
      if (seen.add(w.label)) labels.add(w.label);
    }
    return labels.join(', ');
  }

  /// `150 ETB` / `12.50 USD`. Uses the server-provided currency, never a
  /// hardcoded one. Empty when the reward amount is missing.
  String get rewardLabel {
    final amount = rewardAmount;
    if (amount == null) return '';
    final rounded = (amount * 100).roundToDouble() / 100;
    final text = rounded == rounded.truncateToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(2);
    final c = currency?.trim();
    return c == null || c.isEmpty ? text : '$text $c';
  }

  /// Accepts `3`, `3.0`, `"3"` and `"3.0"`.
  static int _count(dynamic raw) =>
      JsonParse.toInt(raw) ?? JsonParse.toDouble(raw)?.round() ?? 0;

  static DriverQuest? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    final title = map['title']?.toString().trim();
    if (title == null || title.isEmpty) return null;
    final windows = <QuestWindow>[];
    final windowsRaw = map['windows'];
    if (windowsRaw is List) {
      for (final item in windowsRaw) {
        final window = QuestWindow.fromJson(item);
        if (window != null) windows.add(window);
      }
    }
    final description = map['description']?.toString().trim();
    final currency = map['currency']?.toString().trim();
    return DriverQuest(
      id: JsonParse.toInt(map['id']),
      title: title,
      description:
          description == null || description.isEmpty ? null : description,
      target: _count(map['target']),
      completedToday: _count(map['completed_today']),
      rewardAmount: JsonParse.toDouble(map['reward_amount']),
      currency: currency == null || currency.isEmpty ? null : currency,
      windows: windows,
      activeNow: JsonParse.toBool(map['active_now']),
      rewardedToday: JsonParse.toBool(map['rewarded_today']),
    );
  }
}

/// Parsed `GET /api/driver/quests` response.
class DriverQuestList {
  const DriverQuestList({this.enabled = true, this.quests = const []});

  /// False when the backend flag `drivers.quests_enabled` is off.
  final bool enabled;
  final List<DriverQuest> quests;

  /// First quest that is in a peak window right now and not yet rewarded.
  DriverQuest? get activeQuest {
    for (final q in quests) {
      if (q.activeNow && !q.rewardedToday) return q;
    }
    return null;
  }

  /// Accepts a bare list, `{data: [...]}`, or
  /// `{data: {enabled, quests: [...]}}`. Returns null for unusable payloads.
  static DriverQuestList? fromJson(dynamic raw) {
    List? items;
    var enabled = true;

    if (raw is List) {
      items = raw;
    } else {
      final map = JsonParse.toMap(raw);
      if (map == null) return null;
      if (map.containsKey('enabled')) {
        enabled = JsonParse.toBool(map['enabled'], defaultValue: true);
      }
      final data = map['data'];
      if (data is List) {
        items = data;
      } else {
        final dataMap = JsonParse.toMap(data) ?? map;
        if (dataMap.containsKey('enabled')) {
          enabled = JsonParse.toBool(dataMap['enabled'], defaultValue: enabled);
        }
        final nested = dataMap['quests'] ?? dataMap['items'];
        if (nested is List) items = nested;
      }
      if (items == null && enabled) return null;
    }

    final quests = <DriverQuest>[];
    for (final item in items ?? const []) {
      final quest = DriverQuest.fromJson(item);
      if (quest != null) quests.add(quest);
    }
    return DriverQuestList(enabled: enabled, quests: quests);
  }
}
