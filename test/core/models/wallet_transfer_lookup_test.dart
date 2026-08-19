import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/wallet_transfer_lookup.dart';

void main() {
  test('parses recipient envelope', () {
    final result = WalletTransferLookupResult.fromJson({
      'success': true,
      'recipient': {
        'user_id': 71,
        'name': 'Abebe Bekele',
        'wallet_type': 'personal',
        'identifier_type': 'phone',
      },
    });

    expect(result.userId, 71);
    expect(result.name, 'Abebe Bekele');
    expect(result.walletType, 'personal');
  });
}
