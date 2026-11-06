import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/notifications/legacy_notification_mapper.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_events.dart';

void main() {
  group('LegacyNotificationMapper.isForgotPasswordOtp', () {
    test('matches event name', () {
      expect(
        LegacyNotificationMapper.isForgotPasswordOtp('forgot_password_otp', {}),
        isTrue,
      );
    });

    test('matches legacy type without skipping OTP entry', () {
      expect(
        LegacyNotificationMapper.isForgotPasswordOtp('', {
          'type': 'PasswordResetOtpNotification',
        }),
        isTrue,
      );
    });

    test('does not match other OTP events', () {
      expect(
        LegacyNotificationMapper.isForgotPasswordOtp('login_otp', {}),
        isFalse,
      );
    });
  });

  group('LegacyNotificationMapper.resolveEvent quests', () {
    test('maps data.type quest_progress', () {
      expect(
        LegacyNotificationMapper.resolveEvent({'type': 'quest_progress'}),
        'quest_progress',
      );
    });

    test('maps data.type quest_completed', () {
      expect(
        LegacyNotificationMapper.resolveEvent({'type': 'quest_completed'}),
        'quest_completed',
      );
    });

    test('maps notification class name', () {
      expect(
        LegacyNotificationMapper.resolveEvent({
          'type': 'QuestCompletedNotification',
        }),
        'quest_completed',
      );
    });
  });

  group('LegacyNotificationMapper.resolveEvent food dispatch (Phase 10)', () {
    test('maps the offer and ops assignment pushes', () {
      expect(
        LegacyNotificationMapper.resolveEvent({'type': 'food_dispatch_offer'}),
        NotificationEvents.foodDispatchOffer,
      );
      expect(
        LegacyNotificationMapper.resolveEvent({'type': 'food_dispatch_assigned'}),
        NotificationEvents.foodDispatchAssigned,
      );
      expect(
        NotificationEvents.isFoodDispatchAssignmentEvent(
          LegacyNotificationMapper.resolveEvent({'type': 'food_dispatch_unassigned'}),
        ),
        isTrue,
      );
      expect(
        NotificationEvents.isJobOfferEvent(NotificationEvents.foodDispatchOffer),
        isFalse,
        reason: 'offers open the offer card, not the available list',
      );
      expect(
        LegacyNotificationMapper.isNonNavigable(
          NotificationEvents.foodDispatchOffer,
          {'type': 'food_dispatch_offer'},
        ),
        isFalse,
      );
    });
  });
}
