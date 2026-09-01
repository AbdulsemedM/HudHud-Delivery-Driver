import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/image_upload_utils.dart';
import 'package:hudhud_delivery_driver/features/auth/data/models/driver_registration_data.dart';

void main() {
  group('looksLikeHtml', () {
    test('returns true for nginx 413 HTML snippet', () {
      expect(
        looksLikeHtml(
          '<html>\n<head><title>413 Request Entity Too Large</title></head>',
        ),
        isTrue,
      );
    });

    test('returns false for normal API messages', () {
      expect(
        looksLikeHtml('The email has already been taken.'),
        isFalse,
      );
    });
  });

  group('DriverRegistrationData.photoValidationError', () {
    test('rejects files over 1 MB', () {
      final dir = Directory.systemTemp.createTempSync('photo_validation_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      final file = File('${dir.path}/large.jpg');
      file.writeAsBytesSync(List.filled(maxProfilePhotoBytes + 1, 0));

      expect(
        DriverRegistrationData.photoValidationError(file),
        'Photo size must not exceed 1 MB.',
      );
    });

    test('accepts files under 1 MB', () {
      final dir = Directory.systemTemp.createTempSync('photo_validation_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      final file = File('${dir.path}/small.jpg');
      file.writeAsBytesSync(List.filled(1024, 0));

      expect(DriverRegistrationData.photoValidationError(file), isNull);
    });
  });
}
