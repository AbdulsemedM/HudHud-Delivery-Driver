import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/driver_food_order.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/phone_launcher.dart';

void main() {
  // Shape of GET /api/driver/orders/active after
  // GiftOrderService::presentForDriver (the payer is replaced).
  const giftRow = {
    'id': 41,
    'order_number': 'ORD-20261105-41',
    'status': 'in_transit',
    'next_action': 'complete',
    'is_gift': true,
    'recipient': {'name': 'Amina Yusuf', 'phone': '+252634123456'},
    'customer': {'id': null, 'name': 'Amina Yusuf', 'phone': '+252634123456'},
    'vendor': {'id': 9, 'name': 'Hiddo Restaurant'},
    'pickup_location': 'Road 1, Hargeisa',
    'delivery_address': 'Jigjiga Yar, Hargeisa',
    'delivery_latitude': '9.5600',
    'delivery_longitude': 44.06,
    'total_amount': '10.50',
    'currency': 'usd',
    'payment_method': 'waafi',
    'delivery_otp_required': true,
  };

  group('DriverFoodOrder', () {
    test('a gift shows the recipient as the contact', () {
      final order = DriverFoodOrder.fromJson(giftRow)!;
      expect(order.id, 41);
      expect(order.isGift, isTrue);
      expect(order.contactName, 'Amina Yusuf');
      expect(order.contactPhone, '+252634123456');
      expect(order.vendorName, 'Hiddo Restaurant');
      expect(order.deliveryAddress, 'Jigjiga Yar, Hargeisa');
      expect(order.deliveryLatitude, 9.56);
      expect(order.totalAmount, 10.5);
      expect(order.currency, 'USD');
      expect(order.deliveryOtpRequired, isTrue);
      expect(order.canComplete, isTrue);
      expect(order.canStart, isFalse);
    });

    test('a normal order uses the customer and derives the next step', () {
      final order = DriverFoodOrder.fromJson({
        'id': '7',
        'status': 'accepted',
        'customer': {'name': 'Abel', 'phone': '0911223344'},
        'delivery_location': 'Bole',
      })!;
      expect(order.isGift, isFalse);
      expect(order.contactName, 'Abel');
      expect(order.deliveryAddress, 'Bole');
      expect(order.deliveryOtpRequired, isFalse);
      expect(order.canStart, isTrue);
      expect(order.canComplete, isFalse);
      expect(order.displayNumber, '#7');

      final started = order.withStatus('in_transit', newNextAction: 'complete');
      expect(started.canComplete, isTrue);
      expect(started.contactName, 'Abel');
    });

    test('parses the {success, data, count} envelope and skips bad rows', () {
      final orders = DriverFoodOrder.listFromResponse({
        'success': true,
        'data': [giftRow, 'nope', {'id': 0}],
        'count': 3,
      });
      expect(orders, hasLength(1));
      expect(DriverFoodOrder.listFromResponse(null), isEmpty);
      expect(DriverFoodOrder.listFromResponse([giftRow]), hasLength(1));
    });
  });

  group('Phase 10 system-dispatched orders (assigned before pickup)', () {
    test('preparing / ready orders can be started and carry the pickup-code flag', () {
      final order = DriverFoodOrder.fromJson({
        'id': 55,
        'status': 'preparing',
        'next_action': 'start',
        'pickup_otp_required': true,
        'waiting_for_food': true,
        'currency': 'ETB',
      })!;
      expect(order.canStart, isTrue);
      expect(order.canComplete, isFalse);
      expect(order.pickupOtpRequired, isTrue);
      expect(order.waitingForFood, isTrue);

      // Without the server hint the status alone decides.
      expect(DriverFoodOrder.fromJson({'id': 56, 'status': 'ready_for_pickup'})!.canStart, isTrue);
      expect(DriverFoodOrder.fromJson({'id': 57, 'status': 'preparing'})!.canStart, isTrue);
      expect(DriverFoodOrder.fromJson({'id': 58, 'status': 'in_transit'})!.canStart, isFalse);

      final started = order.withStatus('in_transit', newNextAction: 'complete');
      expect(started.pickupOtpRequired, isFalse);
      expect(started.waitingForFood, isFalse);
      expect(started.canComplete, isTrue);

      final ready = order.withStatus('ready_for_pickup', newNextAction: 'start');
      expect(ready.pickupOtpRequired, isTrue);
      expect(ready.waitingForFood, isFalse);
    });

    test('old payloads default the new flags to false', () {
      final order = DriverFoodOrder.fromJson(giftRow)!;
      expect(order.pickupOtpRequired, isFalse);
      expect(order.waitingForFood, isFalse);
    });

    test('FoodPickupCode recognises the 422 INVALID_PICKUP_OTP', () {
      expect(
        FoodPickupCode.isInvalid(BadRequestException(
          'Invalid pickup OTP.',
          code: '422',
          details: {'success': false, 'code': 'INVALID_PICKUP_OTP'},
        )),
        isTrue,
      );
      expect(FoodPickupCode.isInvalid(BadRequestException('x', code: 'INVALID_PICKUP_OTP')), isTrue);
      expect(FoodPickupCode.isInvalid(BadRequestException('x', code: 'INVALID_DELIVERY_OTP')), isFalse);
      expect(FoodPickupCode.isInvalid(StateError('x')), isFalse);
    });
  });

  group('GiftDeliveryCode.classify (DriverController::completeDelivery)', () {
    final invalid = BadRequestException(
      'Ask the recipient for the 4-digit delivery code.',
      code: 'INVALID_DELIVERY_OTP',
      details: {'success': false, 'code': 'INVALID_DELIVERY_OTP'},
    );
    final locked = TooManyRequestsException(
      'Too many wrong codes. Try again later or contact support.',
      code: 'DELIVERY_OTP_LOCKED',
      details: {'success': false, 'code': 'DELIVERY_OTP_LOCKED'},
    );

    test('no code sent → the code is required', () {
      expect(
        GiftDeliveryCode.classify(invalid, codeWasSent: false),
        GiftDeliveryCodeError.required,
      );
    });

    test('code sent → wrong code', () {
      expect(
        GiftDeliveryCode.classify(invalid, codeWasSent: true),
        GiftDeliveryCodeError.invalid,
      );
    });

    test('429 DELIVERY_OTP_LOCKED → locked', () {
      expect(
        GiftDeliveryCode.classify(locked, codeWasSent: true),
        GiftDeliveryCodeError.locked,
      );
    });

    test('other errors are not about the code', () {
      expect(
        GiftDeliveryCode.classify(
          ConflictException('Order is not in transit.',
              code: 'INVALID_ORDER_TRANSITION'),
          codeWasSent: true,
        ),
        isNull,
      );
      expect(
        GiftDeliveryCode.classify(StateError('x'), codeWasSent: false),
        isNull,
      );
      // A plain throttle 429 without the API code is not a code lock.
      expect(
        GiftDeliveryCode.classify(
          TooManyRequestsException('Too many requests'),
          codeWasSent: true,
        ),
        isNull,
      );
    });

    test('well-formed codes are exactly 4 digits', () {
      expect(GiftDeliveryCode.isWellFormed('0427'), isTrue);
      expect(GiftDeliveryCode.isWellFormed(' 0427 '), isTrue);
      expect(GiftDeliveryCode.isWellFormed('427'), isFalse);
      expect(GiftDeliveryCode.isWellFormed('04a7'), isFalse);
      expect(GiftDeliveryCode.isWellFormed(null), isFalse);
    });
  });

  group('PhoneLauncher.telPath', () {
    test('keeps + for Somaliland gift recipients', () {
      expect(PhoneLauncher.telPath('+252634123456'), '+252634123456');
      expect(PhoneLauncher.telPath('252634123456'), '+252634123456');
      expect(PhoneLauncher.telPath('00252634123456'), '+252634123456');
    });

    test('Ethiopian numbers are unchanged', () {
      expect(PhoneLauncher.telPath('0911223344'), '+251911223344');
      expect(PhoneLauncher.telPath(null), isNull);
      expect(PhoneLauncher.telPath('8000'), '8000');
    });
  });
}
