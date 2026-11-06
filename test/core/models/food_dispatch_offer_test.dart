import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/food_dispatch_offer.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

void main() {
  final received = DateTime(2026, 11, 6, 10, 0, 0);

  // Shape of GET /api/driver/dispatch/offers/current → data
  // (FoodDispatchService::presentOffer).
  const apiOffer = {
    'id': 9,
    'offer_id': 9,
    'order_id': 41,
    'order_number': 'ORD-20261106-41',
    'state': 'open',
    'offered_at': '2026-11-06T07:00:00+00:00',
    'expires_at': '2026-11-06T07:00:30+00:00',
    'expires_in_seconds': 28,
    'timeout_seconds': 30,
    'restaurant': {
      'name': 'Hiddo Restaurant',
      'address': 'Road 1, Hargeisa',
      'latitude': 9.56,
      'longitude': '44.065',
    },
    'pickup_distance_km': 0.6,
    'dropoff_area': 'Jigjiga Yar',
    'earnings_estimate': 1.2,
    'currency': 'usd',
    'payment_method': 'cash_on_delivery',
    'is_cash': true,
    'is_gift': false,
    'items_count': 3,
    'waiting_for_food': true,
    'accept_endpoint': '/api/driver/dispatch/offers/9/accept',
  };

  group('FoodDispatchOffer', () {
    test('parses the API offer and anchors the countdown on the device clock', () {
      final offer = FoodDispatchOffer.fromJson(apiOffer, receivedAt: received)!;
      expect(offer.offerId, 9);
      expect(offer.orderId, 41);
      expect(offer.displayNumber, 'ORD-20261106-41');
      expect(offer.restaurantName, 'Hiddo Restaurant');
      expect(offer.restaurantAddress, 'Road 1, Hargeisa');
      expect(offer.restaurantLongitude, 44.065);
      expect(offer.pickupDistanceKm, 0.6);
      expect(offer.dropoffArea, 'Jigjiga Yar');
      expect(offer.earningsEstimate, 1.2);
      expect(offer.currency, 'USD');
      expect(offer.isCash, isTrue);
      expect(offer.isGift, isFalse);
      expect(offer.itemsCount, 3);
      expect(offer.waitingForFood, isTrue);
      // expires_in_seconds wins over a (possibly skewed) absolute expires_at.
      expect(offer.deadline, received.add(const Duration(seconds: 28)));
      expect(offer.secondsLeft(received), 28);
      expect(offer.remainingFraction(received), closeTo(28 / 30, 0.001));
    });

    test('counts down to zero and never below', () {
      final offer = FoodDispatchOffer.fromJson(apiOffer, receivedAt: received)!;
      expect(offer.secondsLeft(received.add(const Duration(milliseconds: 27500))), 1);
      expect(offer.isExpired(received.add(const Duration(seconds: 27))), isFalse);
      expect(offer.secondsLeft(received.add(const Duration(seconds: 28))), 0);
      expect(offer.isExpired(received.add(const Duration(seconds: 40))), isTrue);
      expect(offer.remainingFraction(received.add(const Duration(seconds: 40))), 0);
    });

    test('parses the FCM data payload (all strings)', () {
      final data = <String, dynamic>{
        'type': 'food_dispatch_offer',
        'offer_id': '9',
        'order_id': '41',
        'order_number': '',
        'expires_at': '2026-11-06T07:00:30+00:00',
        'expires_in_seconds': '30',
        'timeout_seconds': '30',
        'restaurant_name': 'Bole Burger',
        'pickup_location': 'Bole Rd',
        'pickup_latitude': '9.0',
        'pickup_longitude': '',
        'pickup_distance_km': '1.4',
        'dropoff_area': 'Bole Atlas',
        'earnings_estimate': '33.6',
        'currency': 'ETB',
        'payment_method': 'wallet',
        'is_gift': '1',
        'screen': 'food_dispatch_offer',
      };
      final offer = FoodDispatchOffer.fromPushData(data, receivedAt: received)!;
      expect(offer.restaurantName, 'Bole Burger');
      expect(offer.restaurantAddress, 'Bole Rd');
      expect(offer.restaurantLatitude, 9.0);
      expect(offer.restaurantLongitude, isNull);
      expect(offer.displayNumber, '#41');
      expect(offer.isGift, isTrue);
      expect(offer.isCash, isFalse);
      expect(offer.secondsLeft(received), 30);
      expect(FoodDispatchOffer.isOfferPush(data), isTrue);
      expect(FoodDispatchOffer.fromPushData({'type': 'order_status_update'}), isNull);
    });

    test('rejects rows without ids', () {
      expect(FoodDispatchOffer.fromJson(null), isNull);
      expect(FoodDispatchOffer.fromJson({'offer_id': 3}), isNull);
      expect(FoodDispatchOffer.fromJson({'order_id': 3}), isNull);
    });
  });

  group('FoodDispatchPoll', () {
    test('parses an offer and the server poll interval', () {
      final poll = FoodDispatchPoll.fromResponse({
        'success': true,
        'data': apiOffer,
        'auto_dispatch': true,
        'market': 'hargeisa',
        'poll_after_seconds': 5,
      }, receivedAt: received);
      expect(poll.offer?.offerId, 9);
      expect(poll.autoDispatch, isTrue);
      expect(poll.market, 'hargeisa');
      expect(poll.pollAfterSeconds, 5);
    });

    test('no offer, clamps silly intervals, tolerates junk', () {
      final poll = FoodDispatchPoll.fromResponse({
        'data': null,
        'auto_dispatch': false,
        'poll_after_seconds': 9999,
      });
      expect(poll.offer, isNull);
      expect(poll.autoDispatch, isFalse);
      expect(poll.pollAfterSeconds, 120);
      expect(FoodDispatchPoll.fromResponse('x').pollAfterSeconds, 15);
    });
  });

  group('FoodOfferErrors.classify', () {
    ConflictException conflict(String code) =>
        ConflictException('x', code: code, details: {'code': code});

    test('maps API codes to rider-facing errors', () {
      expect(FoodOfferErrors.classify(conflict('DISPATCH_OFFER_EXPIRED')), FoodOfferError.expired);
      expect(FoodOfferErrors.classify(conflict('DISPATCH_OFFER_CLOSED')), FoodOfferError.gone);
      expect(FoodOfferErrors.classify(conflict('ORDER_ALREADY_ASSIGNED')), FoodOfferError.gone);
      expect(FoodOfferErrors.classify(conflict('LOW_WALLET_BALANCE')), FoodOfferError.lowBalance);
      expect(FoodOfferErrors.classify(conflict('DRIVER_ACTIVE_JOB_CONFLICT')), FoodOfferError.activeJob);
      expect(
        FoodOfferErrors.classify(ForbiddenException('x', details: {'code': 'DRIVER_CITY_MISMATCH'})),
        FoodOfferError.otherCity,
      );
      expect(FoodOfferErrors.classify(StateError('boom')), FoodOfferError.other);
      expect(FoodOfferErrors.messageKey(FoodOfferError.otherCity), 'dispatch_offer.error_other_city');
    });
  });

  group('FoodOfferTracker', () {
    FoodDispatchOffer offer(int id, {int inSeconds = 30}) => FoodDispatchOffer.fromJson(
          {'offer_id': id, 'order_id': 100 + id, 'expires_in_seconds': inSeconds},
          receivedAt: received,
        )!;

    test('shows each offer once and never two at a time', () {
      final tracker = FoodOfferTracker();
      final first = offer(1);
      expect(tracker.shouldShow(first, received), isTrue);
      tracker.markShowing(first);
      expect(tracker.showingOfferId, 1);
      expect(tracker.shouldShow(offer(2), received), isFalse, reason: 'one on screen');
      expect(tracker.shouldShow(first, received), isFalse);

      tracker.markClosed(1);
      expect(tracker.showingOfferId, isNull);
      expect(tracker.shouldShow(first, received), isFalse, reason: 'already handled');
      expect(tracker.shouldShow(offer(2), received), isTrue);
    });

    test('skips expired offers and null', () {
      final tracker = FoodOfferTracker();
      expect(tracker.shouldShow(null, received), isFalse);
      expect(tracker.shouldShow(offer(3, inSeconds: 0), received), isFalse);
      tracker.reset();
      expect(tracker.shouldShow(offer(4), received), isTrue);
    });
  });
}
