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

  group('DriverEligibility 403 body', () {
    test('pending_verification driver blocked from accepting', () {
      final body = {
        'message': 'Your driver application is pending admin review.',
        'application_status': 'pending',
        'status_reason': 'Upload a clear photo of your licence.',
      };
      expect(
        ApplicationStatus.fromExceptionDetails(body),
        ApplicationStatus.pending,
      );
      expect(
        ApplicationStatus.reasonFrom(body),
        'Upload a clear photo of your licence.',
      );
    });

    test('suspended driver with null status_reason', () {
      final body = {
        'message': 'Your driver account is suspended. Contact support.',
        'application_status': 'suspended',
        'status_reason': null,
      };
      expect(
        ApplicationStatus.fromExceptionDetails(body),
        ApplicationStatus.suspended,
      );
      expect(ApplicationStatus.reasonFrom(body), isNull);
    });

    test('plain 403 without application_status is not an eligibility block', () {
      expect(
        ApplicationStatus.fromExceptionDetails(
          {'message': 'Only drivers can perform this action.'},
        ),
        isNull,
      );
    });
  });

  group('ApplicationStatus.fromDriverBlock', () {
    test('maps every driver state', () {
      expect(ApplicationStatus.fromDriverBlock({'state': 'approved'}),
          ApplicationStatus.accepted);
      expect(ApplicationStatus.fromDriverBlock({'state': 'pending_review'}),
          ApplicationStatus.pending);
      expect(ApplicationStatus.fromDriverBlock({'state': 'suspended'}),
          ApplicationStatus.suspended);
      expect(ApplicationStatus.fromDriverBlock({'state': 'onboarding_required'}),
          ApplicationStatus.onboardingRequired);
      expect(ApplicationStatus.fromDriverBlock(null), isNull);
    });
  });

  group('ApplicationStatus.fromStatusResponse', () {
    test('plain pending does not downgrade a stored onboarding_required', () {
      expect(
        ApplicationStatus.fromStatusResponse(
          {'application_status': 'pending'},
          stored: ApplicationStatus.onboardingRequired,
        ),
        ApplicationStatus.onboardingRequired,
      );
      expect(
        ApplicationStatus.fromStatusResponse(
          {'status': 'pending_verification'},
          stored: ApplicationStatus.onboardingRequired,
        ),
        ApplicationStatus.onboardingRequired,
      );
    });

    test('a driver block wins over the stored status', () {
      expect(
        ApplicationStatus.fromStatusResponse(
          {
            'application_status': 'pending',
            'driver': {'state': 'pending_review'},
          },
          stored: ApplicationStatus.onboardingRequired,
        ),
        ApplicationStatus.pending,
      );
    });

    test('accepted and suspended still override onboarding', () {
      expect(
        ApplicationStatus.fromStatusResponse(
          {'application_status': 'accepted'},
          stored: ApplicationStatus.onboardingRequired,
        ),
        ApplicationStatus.accepted,
      );
      expect(
        ApplicationStatus.fromStatusResponse(
          {'application_status': 'suspended'},
          stored: ApplicationStatus.onboardingRequired,
        ),
        ApplicationStatus.suspended,
      );
    });

    test('pending stays pending when nothing says onboarding', () {
      expect(
        ApplicationStatus.fromStatusResponse(
          {'application_status': 'pending'},
          stored: ApplicationStatus.pending,
        ),
        ApplicationStatus.pending,
      );
      expect(ApplicationStatus.fromStatusResponse(null), isNull);
    });
  });
}
