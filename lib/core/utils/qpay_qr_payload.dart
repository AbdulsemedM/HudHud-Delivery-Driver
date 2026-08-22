import 'dart:convert';
import 'dart:typed_data';

enum QPayQrKind { imageBytes, imageUrl, qrValue }

/// Classifies a provider QR payload without inventing a new payment string.
class QPayQrPayload {
  const QPayQrPayload._({
    required this.kind,
    this.bytes,
    this.url,
    this.value,
  });

  final QPayQrKind kind;
  final Uint8List? bytes;
  final String? url;
  final String? value;

  factory QPayQrPayload.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('data:image')) {
      final comma = trimmed.indexOf(',');
      if (comma > 0 && comma < trimmed.length - 1) {
        try {
          final bytes = base64Decode(trimmed.substring(comma + 1));
          if (bytes.isNotEmpty) {
            return QPayQrPayload._(kind: QPayQrKind.imageBytes, bytes: bytes);
          }
        } catch (_) {}
      }
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return QPayQrPayload._(kind: QPayQrKind.imageUrl, url: trimmed);
    }

    if (_looksLikeBase64Image(trimmed)) {
      try {
        final bytes = base64Decode(trimmed);
        if (bytes.isNotEmpty) {
          return QPayQrPayload._(kind: QPayQrKind.imageBytes, bytes: bytes);
        }
      } catch (_) {}
    }

    return QPayQrPayload._(kind: QPayQrKind.qrValue, value: trimmed);
  }

  static bool _looksLikeBase64Image(String value) {
    if (value.length < 32 || value.contains(' ') || value.contains('\n')) {
      return false;
    }
    return value.startsWith('iVBOR') ||
        value.startsWith('/9j/') ||
        value.startsWith('R0lGOD') ||
        value.startsWith('UklGR');
  }
}
