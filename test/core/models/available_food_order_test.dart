import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/available_food_order.dart';

void main() {
  final now = DateTime(2026, 11, 8, 12);

  Map<String, dynamic> row({Map<String, dynamic>? extra}) => {
        'id': 41,
        'order_number': 'ORD-41',
        'status': 'ready_for_pickup',
        'total_amount': '320.00',
        'currency': 'ETB',
        'payment_method': 'cash_on_delivery',
        'pickup_location': 'Bole, Edna Mall',
        'delivery_address': 'CMC, house 12',
        'vendor': {'shop_name': 'Yod Abyssinia', 'address': 'Bole'},
        'pickup_otp_required': true,
        'acceptance_endpoint': '/api/driver/orders/41/accept',
        'cod_acceptance': {'can_accept': true, 'eligible': true},
        ...?extra,
      };

  test('parses the legacy list (bare JSON array)', () {
    final list = AvailableFoodOrder.listFromResponse([row()], receivedAt: now);
    expect(list, hasLength(1));
    final order = list.single;
    expect(order.id, 41);
    expect(order.order.vendorName, 'Yod Abyssinia');
    expect(order.order.totalAmount, 320);
    expect(order.pickupOtpRequired, isTrue);
    expect(order.needsPickupCodeToAccept, isTrue);
    expect(order.viaDispatchOffer, isFalse);
    expect(order.codEligible, isTrue);
    expect(order.codMessage, isNull);
  });

  test('a COD row the rider cannot take keeps the server message', () {
    final order = AvailableFoodOrder.fromJson(row(extra: {
      'cod_acceptance': {
        'can_accept': false,
        'eligible': false,
        'message': 'Not eligible: low wallet balance. Please top up your wallet.',
      },
    }))!;
    expect(order.codEligible, isFalse);
    expect(order.codMessage, contains('low wallet balance'));
  });

  test('a row under system dispatch accepts through the offer', () {
    final order = AvailableFoodOrder.fromJson(
      row(extra: {
        'pickup_otp_required': false,
        'dispatch_offer': {
          'offer_id': 9,
          'order_id': 41,
          'expires_in_seconds': 20,
          'accept_endpoint': '/api/driver/dispatch/offers/9/accept',
        },
      }),
      receivedAt: now,
    )!;
    expect(order.viaDispatchOffer, isTrue);
    expect(order.dispatchOffer!.offerId, 9);
    expect(order.needsPickupCodeToAccept, isFalse);
  });

  test('{data: [...]} and bad rows', () {
    final list = AvailableFoodOrder.listFromResponse({
      'data': [row(), {'id': null}, 'x'],
    });
    expect(list, hasLength(1));
    expect(AvailableFoodOrder.listFromResponse(null), isEmpty);
  });
}
