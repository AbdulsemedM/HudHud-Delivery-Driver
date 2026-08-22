import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/qpay_qr_payload.dart';

void main() {
  group('QPayQrPayload', () {
    test('treats payment string as QR value', () {
      final payload = QPayQrPayload.parse('hudhud-qpay-token');
      expect(payload.kind, QPayQrKind.qrValue);
      expect(payload.value, 'hudhud-qpay-token');
    });

    test('parses data URI image', () {
      final payload = QPayQrPayload.parse(
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      expect(payload.kind, QPayQrKind.imageBytes);
      expect(payload.bytes, isNotNull);
    });

    test('parses https image URL', () {
      final payload = QPayQrPayload.parse('https://cdn.example.com/qr.png');
      expect(payload.kind, QPayQrKind.imageUrl);
      expect(payload.url, 'https://cdn.example.com/qr.png');
    });
  });
}
