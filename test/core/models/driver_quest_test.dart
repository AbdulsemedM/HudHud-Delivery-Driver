import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/driver_quest.dart';

void main() {
  group('DriverQuest.fromJson', () {
    test('parses contract payload', () {
      final quest = DriverQuest.fromJson({
        'id': 1,
        'title': 'Peak hero',
        'description': 'Complete 8 deliveries during peak hours',
        'target': 8,
        'completed_today': 3,
        'reward_amount': 150.00,
        'currency': 'ETB',
        'windows': [
          {
            'days': [1, 2, 3, 4, 5, 6, 7],
            'start': '12:00',
            'end': '14:00',
          },
          {
            'days': [1, 2, 3, 4, 5, 6, 7],
            'start': '18:00',
            'end': '21:00',
          },
        ],
        'active_now': true,
        'rewarded_today': false,
      });

      expect(quest, isNotNull);
      expect(quest!.id, 1);
      expect(quest.title, 'Peak hero');
      expect(quest.target, 8);
      expect(quest.completedToday, 3);
      expect(quest.rewardAmount, 150.0);
      expect(quest.currency, 'ETB');
      expect(quest.windows.length, 2);
      expect(quest.windows.first.days, [1, 2, 3, 4, 5, 6, 7]);
      expect(quest.activeNow, isTrue);
      expect(quest.rewardedToday, isFalse);
      expect(quest.progress, closeTo(0.375, 0.0001));
      expect(quest.progressLabel, '3/8');
      expect(quest.rewardLabel, '150 ETB');
      expect(quest.windowsLabel, '12:00–14:00, 18:00–21:00');
    });

    test('tolerates string numbers and booleans', () {
      final quest = DriverQuest.fromJson({
        'id': '7',
        'title': 'Lunch rush',
        'target': '5',
        'completed_today': '2.0',
        'reward_amount': '75.50',
        'currency': 'USD',
        'windows': [
          {'days': ['1', '2'], 'start': '12:00:00', 'end': '14:00:00'},
        ],
        'active_now': '1',
        'rewarded_today': 'false',
      });

      expect(quest, isNotNull);
      expect(quest!.id, 7);
      expect(quest.target, 5);
      expect(quest.completedToday, 2);
      expect(quest.rewardAmount, 75.5);
      expect(quest.rewardLabel, '75.50 USD');
      expect(quest.windows.single.days, [1, 2]);
      expect(quest.windowsLabel, '12:00–14:00');
      expect(quest.activeNow, isTrue);
      expect(quest.rewardedToday, isFalse);
    });

    test('clamps progress and handles zero target', () {
      final over = DriverQuest.fromJson({
        'title': 'Over',
        'target': 4,
        'completed_today': 9,
      });
      expect(over!.progress, 1.0);

      final zero = DriverQuest.fromJson({
        'title': 'Zero',
        'target': 0,
        'completed_today': 0,
      });
      expect(zero!.progress, 0.0);
      expect(zero.rewardLabel, '');
    });

    test('returns null without a title', () {
      expect(DriverQuest.fromJson({'id': 1, 'target': 8}), isNull);
      expect(DriverQuest.fromJson('nope'), isNull);
      expect(DriverQuest.fromJson(null), isNull);
    });

    test('skips windows without start/end and out-of-range days', () {
      final quest = DriverQuest.fromJson({
        'title': 'Peak hero',
        'windows': [
          {'days': [0, 3, 8], 'start': '9:00', 'end': '10:30'},
          {'days': [1], 'start': '12:00'},
          'garbage',
        ],
      });
      expect(quest!.windows.length, 1);
      expect(quest.windows.single.days, [3]);
      expect(quest.windows.single.label, '09:00–10:30');
    });
  });

  group('DriverQuestList.fromJson', () {
    test('parses envelope with list data', () {
      final list = DriverQuestList.fromJson({
        'success': true,
        'data': [
          {'title': 'Peak hero', 'active_now': false},
          {'title': 'Night owl', 'active_now': true},
          {'no_title': true},
        ],
      });

      expect(list, isNotNull);
      expect(list!.enabled, isTrue);
      expect(list.quests.length, 2);
      expect(list.activeQuest?.title, 'Night owl');
    });

    test('parses bare list', () {
      final list = DriverQuestList.fromJson([
        {'title': 'Peak hero'},
      ]);
      expect(list!.quests.single.title, 'Peak hero');
      expect(list.activeQuest, isNull);
    });

    test('reads enabled:false from data object', () {
      final list = DriverQuestList.fromJson({
        'success': true,
        'data': {'enabled': false, 'quests': []},
      });
      expect(list, isNotNull);
      expect(list!.enabled, isFalse);
      expect(list.quests, isEmpty);
    });

    test('reads enabled:false at top level without a list', () {
      final list = DriverQuestList.fromJson({'success': true, 'enabled': false});
      expect(list!.enabled, isFalse);
    });

    test('active quest ignores already rewarded quests', () {
      final list = DriverQuestList.fromJson({
        'data': [
          {'title': 'Done', 'active_now': true, 'rewarded_today': true},
        ],
      });
      expect(list!.activeQuest, isNull);
    });

    test('returns null for unusable payloads', () {
      expect(DriverQuestList.fromJson({'success': true}), isNull);
      expect(DriverQuestList.fromJson('oops'), isNull);
      expect(DriverQuestList.fromJson(null), isNull);
    });
  });
}
