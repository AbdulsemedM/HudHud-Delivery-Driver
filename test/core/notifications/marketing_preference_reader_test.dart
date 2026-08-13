import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/notifications/marketing_preference_reader.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';

void main() {
  group('MarketingPreferenceReader', () {
    late MarketingPreferenceReader reader;

    setUp(() {
      reader = MarketingPreferenceReader(SecureStorageService());
    });

    test('returns true when marketing_notifications_enabled is true', () {
      expect(
        reader.readFromMap({
          'user': {'marketing_notifications_enabled': true},
        }),
        isTrue,
      );
    });

    test('returns false when preference is absent', () {
      expect(reader.readFromMap({'user': {'name': 'Test'}}), isFalse);
    });

    test('reads nested notification_preferences.marketing', () {
      expect(
        reader.readFromMap({
          'notification_preferences': {'marketing': true},
        }),
        isTrue,
      );
    });
  });
}
