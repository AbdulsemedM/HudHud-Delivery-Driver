import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';

void main() {
  group('EthiopianPhoneNumber.tryNormalize', () {
    test('accepts 09xxxxxxxx', () {
      expect(EthiopianPhoneNumber.tryNormalize('0911234567'), '251911234567');
    });

    test('accepts +2519xxxxxxxx', () {
      expect(EthiopianPhoneNumber.tryNormalize('+251911234567'), '251911234567');
    });

    test('accepts 2519xxxxxxxx', () {
      expect(EthiopianPhoneNumber.tryNormalize('251911234567'), '251911234567');
    });

    test('accepts 9xxxxxxxx without leading 0', () {
      expect(EthiopianPhoneNumber.tryNormalize('911234567'), '251911234567');
    });

    test('strips leftover 0 after country code', () {
      expect(EthiopianPhoneNumber.tryNormalize('2510911234567'), '251911234567');
      expect(
        EthiopianPhoneNumber.tryNormalize('+2510911234567'),
        '251911234567',
      );
    });

    test('strips spaces and dashes', () {
      expect(
        EthiopianPhoneNumber.tryNormalize('09 11 234 567'),
        '251911234567',
      );
      expect(
        EthiopianPhoneNumber.tryNormalize('+251-911-234-567'),
        '251911234567',
      );
    });

    test('rejects invalid numbers', () {
      expect(EthiopianPhoneNumber.tryNormalize(null), isNull);
      expect(EthiopianPhoneNumber.tryNormalize(''), isNull);
      expect(EthiopianPhoneNumber.tryNormalize('0711234567'), isNull);
      expect(EthiopianPhoneNumber.tryNormalize('12345'), isNull);
      expect(EthiopianPhoneNumber.tryNormalize('+1234567891'), isNull);
      expect(EthiopianPhoneNumber.tryNormalize('251811234567'), isNull);
    });
  });

  group('EthiopianPhoneNumber.formValidator', () {
    test('requires a value', () {
      expect(EthiopianPhoneNumber.formValidator(null), 'Required');
      expect(EthiopianPhoneNumber.formValidator('  '), 'Required');
    });

    test('rejects invalid format', () {
      expect(
        EthiopianPhoneNumber.formValidator('0711234567'),
        'Enter a valid Ethiopian phone number',
      );
    });

    test('accepts valid format', () {
      expect(EthiopianPhoneNumber.formValidator('0911234567'), isNull);
    });
  });

  group('EthiopianPhoneNumber.normalizeIdentifier', () {
    test('passes emails through', () {
      expect(
        EthiopianPhoneNumber.normalizeIdentifier('  user@example.com '),
        'user@example.com',
      );
    });

    test('normalizes phone identifiers', () {
      expect(
        EthiopianPhoneNumber.normalizeIdentifier('+251911234567'),
        '251911234567',
      );
    });

    test('returns null for invalid phones', () {
      expect(EthiopianPhoneNumber.normalizeIdentifier('0711234567'), isNull);
    });
  });

  group('EthiopianPhoneNumber.mask', () {
    test('masks canonical number', () {
      expect(
        EthiopianPhoneNumber.mask('0911234567'),
        '2519******67',
      );
    });
  });
}
