import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/notifications/job_offer_alert_sound_service.dart';
import 'package:hudhud_delivery_driver/core/notifications/job_offer_alert_store.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_events.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JobOfferAlertSoundService.shouldAlertForData', () {
    test('returns true for new_order', () {
      expect(
        JobOfferAlertSoundService.shouldAlertForData({
          'event': NotificationEvents.newOrder,
          'title': 'New order',
        }),
        isTrue,
      );
    });

    /// THE ONE THAT WAS MISSING. `notifyNearbyDrivers()` dispatches
    /// AvailableOrderNotification, whose payload is `type: available_order` -
    /// and that was not a job-offer event, so a rider sitting online with the
    /// app open got no alert when an order arrived. It fell through to a
    /// single default notification sound. `new_order` was on the list, but
    /// nothing sends that for food dispatch.
    ///
    /// Asserted through `type`, not `event`, because that is the key the
    /// server actually sends.
    test('returns true for available_order, which is what the server sends',
        () {
      expect(
        JobOfferAlertSoundService.shouldAlertForData({
          'type': 'available_order',
          'title': 'New order available',
        }),
        isTrue,
      );
    });

    test('returns true for proximity_delivery_offer', () {
      expect(
        JobOfferAlertSoundService.shouldAlertForData({
          'event': NotificationEvents.proximityDeliveryOffer,
          'title': 'Nearby delivery',
        }),
        isTrue,
      );
    });

    test('returns false for wallet_low', () {
      expect(
        JobOfferAlertSoundService.shouldAlertForData({
          'event': NotificationEvents.walletLow,
          'title': 'Low balance',
        }),
        isFalse,
      );
    });

    test('returns false for otp_required', () {
      expect(
        JobOfferAlertSoundService.shouldAlertForData({
          'event': NotificationEvents.otpRequired,
          'title': 'OTP required',
        }),
        isFalse,
      );
    });
  });

  group('JobOfferAlertSoundService.shouldAlertForMessage', () {
    test('returns true for job offer messages', () {
      expect(
        JobOfferAlertSoundService.shouldAlertForMessage(
          RemoteMessage(data: {'event': NotificationEvents.nearbyJobAvailable}),
        ),
        isTrue,
      );
    });
  });

  group('JobOfferAlertSoundService.acknowledge', () {
    test('clears pending store flag', () async {
      SharedPreferences.setMockInitialValues({'job_offer_alert_pending': true});
      final store = JobOfferAlertStore(
        preferences: await SharedPreferences.getInstance(),
      );
      final service = JobOfferAlertSoundService(
        store: store,
        logger: AppLogger(),
      );

      expect(await store.isPending(), isTrue);

      await service.acknowledge();

      expect(await store.isPending(), isFalse);
      expect(service.isPlaying, isFalse);
    });
  });
}
