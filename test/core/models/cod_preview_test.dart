import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/cod_preview.dart';

void main() {
  group('CodPreview', () {
    test('maps extended COD fields from delivery payload', () {
      final cod = CodPreview.fromDelivery({
        'cod_acceptance': {
          'can_accept': false,
          'current_balance': 100.0,
          'held_collateral': 80.0,
          'available_balance': 20.0,
          'required_amount': 75.0,
          'deficit': 55.0,
          'sufficient': false,
          'reason': 'Insufficient available balance for COD order',
        },
      });

      expect(cod, isNotNull);
      expect(cod!.canAccept, isFalse);
      expect(cod.currentBalance, 100.0);
      expect(cod.heldCollateral, 80.0);
      expect(cod.availableBalance, 20.0);
      expect(cod.requiredAmount, 75.0);
      expect(cod.deficit, 55.0);
      expect(cod.hasCodDetails, isTrue);
      expect(cod.blockedMessage, contains('Top up'));
    });
  });
}
