import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';

void main() {
  group('ApplicationStatus.fromLoginResponse', () {
    test('prefers top-level application_status', () {
      expect(
        ApplicationStatus.fromLoginResponse({
          'application_status': 'pending',
          'user': {
            'application_status': 'accepted',
            'status': 'active',
          },
        }),
        ApplicationStatus.pending,
      );
    });

    test('uses user.application_status when top-level is missing', () {
      expect(
        ApplicationStatus.fromLoginResponse({
          'user': {'application_status': 'suspended'},
        }),
        ApplicationStatus.suspended,
      );
    });

    test('maps legacy user.status active to accepted', () {
      expect(
        ApplicationStatus.fromLoginResponse({
          'user': {'status': 'active'},
        }),
        ApplicationStatus.accepted,
      );
    });

    test('maps pending_verification to pending', () {
      expect(
        ApplicationStatus.fromLoginResponse({
          'user': {'status': 'pending_verification'},
        }),
        ApplicationStatus.pending,
      );
    });

    test('unwraps nested data.application_status', () {
      expect(
        ApplicationStatus.fromLoginResponse({
          'data': {'application_status': 'accepted'},
        }),
        ApplicationStatus.accepted,
      );
    });
  });

  group('ApplicationStatus.canWork', () {
    test('only accepted can work', () {
      expect(ApplicationStatus.canWork(ApplicationStatus.accepted), isTrue);
      expect(ApplicationStatus.canWork(ApplicationStatus.pending), isFalse);
      expect(ApplicationStatus.canWork(ApplicationStatus.suspended), isFalse);
      expect(ApplicationStatus.canWork(null), isFalse);
    });
  });

  group('CodAcceptance', () {
    test('builds top-up copy from deficit', () {
      final cod = CodAcceptance.fromDelivery({
        'cod_acceptance': {
          'can_accept': false,
          'deficit': 23.17,
          'reason': 'Insufficient balance for COD platform fee',
        },
      });
      expect(cod, isNotNull);
      expect(cod!.canAccept, isFalse);
      expect(cod.blockedMessage, 'Top up ETB 23.17 first');
    });

    test('falls back to reason when deficit is missing', () {
      final cod = CodAcceptance.fromDelivery({
        'cod_acceptance': {
          'can_accept': false,
          'reason': 'Insufficient balance for COD platform fee',
        },
      });
      expect(cod!.blockedMessage, 'Insufficient balance for COD platform fee');
    });
  });
}
