import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_pricing.dart';

void main() {
  group('DeliveryPricing.serverQuoteAmount', () {
    test('prefers pricing_quote.total over estimated_cost', () {
      final delivery = {
        'estimated_cost': 50.0,
        'metadata': {
          'pricing_quote': {
            'total': 82.2,
            'zone': {'id': 'addis', 'name': 'Addis', 'version': 1},
          },
        },
      };
      expect(DeliveryPricing.serverQuoteAmount(delivery), 82.2);
    });

    test('falls back to estimated_cost when quote total missing', () {
      final delivery = {'estimated_cost': 50.0};
      expect(DeliveryPricing.serverQuoteAmount(delivery), 50.0);
    });

    test('falls back to payment.amount', () {
      final delivery = {
        'payment': {'amount': 99.5},
      };
      expect(DeliveryPricing.serverQuoteAmount(delivery), 99.5);
    });
  });

  group('DeliveryPricing.fromMetadata', () {
    test('parses fee breakdown fields', () {
      final pricing = DeliveryPricing.fromMetadata({
        'pricing_engine': 'zone_v1',
        'pricing_quote': {
          'total': 82.2,
          'base_fee': 50.0,
          'distance_fee': 29.7,
          'time_fee': 2.5,
          'billable_distance_km': 1.98,
          'estimated_duration_minutes': 5,
          'route_basis': 'optimal_google_driving_route',
          'zone': {'id': 'addis-ababa', 'name': 'Addis Ababa', 'version': 1},
        },
      });
      expect(pricing?.total, 82.2);
      expect(pricing?.baseFee, 50.0);
      expect(pricing?.hasFeeBreakdown, isTrue);
      expect(pricing?.zone?.name, 'Addis Ababa');
    });
  });

  group('pickupOutsideZoneMessage', () {
    test('returns message for pickup_outside_configured_zone', () {
      final message = pickupOutsideZoneMessage({
        'reason': 'pickup_outside_configured_zone',
        'message': 'Pickup location is outside all configured delivery zones.',
      });
      expect(message, contains('outside'));
    });
  });
}
