import 'package:hudhud_delivery_driver/core/models/cod_preview.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

/// Driver-facing application status from the API (`pending` | `accepted` | `suspended`).
class ApplicationStatus {
  ApplicationStatus._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String suspended = 'suspended';

  static const Set<String> values = {pending, accepted, suspended};

  static bool canWork(String? status) => status == accepted;

  static String? normalize(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (values.contains(value)) return value;
    return fromLegacyUserStatus(value);
  }

  /// Maps internal `users.status` when `application_status` is absent.
  static String? fromLegacyUserStatus(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'active':
      case 'accepted':
        return accepted;
      case 'pending_verification':
      case 'pending':
        return pending;
      case 'suspended':
      case 'deactivated':
        return suspended;
      default:
        return null;
    }
  }

  /// Login payload: top-level `application_status`, then `user.application_status`,
  /// then fallback `user.status`. Also unwraps a nested `data` object.
  static String? fromLoginResponse(dynamic data) {
    if (data is! Map) return null;
    final top = normalize(data['application_status']?.toString());
    if (top != null) return top;
    final nested = data['data'];
    if (nested is Map && !identical(nested, data)) {
      final fromNested = fromLoginResponse(nested);
      if (fromNested != null) return fromNested;
    }
    final user = data['user'];
    if (user is Map) {
      final fromUser = normalize(user['application_status']?.toString());
      if (fromUser != null) return fromUser;
      return fromLegacyUserStatus(user['status']?.toString());
    }
    return null;
  }

  static String? reasonFrom(dynamic data) {
    if (data is! Map) return null;
    final nestedUser = data['user'];
    final nestedData = data['data'];
    final nestedDataUser = nestedData is Map ? nestedData['user'] : null;
    final candidates = [
      data['status_reason'],
      if (nestedUser is Map) nestedUser['status_reason'],
      if (nestedData is Map) nestedData['status_reason'],
      if (nestedDataUser is Map) nestedDataUser['status_reason'],
    ];
    for (final raw in candidates) {
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? fromExceptionDetails(dynamic details) {
    if (details is! Map) return null;
    return normalize(details['application_status']?.toString());
  }
}

/// Pre-accept COD wallet check from available-delivery payloads.
///
/// Prefer [CodPreview] for full field support; this type remains for
/// backward compatibility with existing call sites.
class CodAcceptance {
  const CodAcceptance({
    required this.canAccept,
    this.deficit,
    this.reason,
    this.preview,
  });

  final bool canAccept;
  final Object? deficit;
  final String? reason;
  final CodPreview? preview;

  static CodAcceptance? fromDelivery(Map<String, dynamic> delivery) {
    final cod = CodPreview.fromDelivery(delivery);
    if (cod == null) return null;
    return CodAcceptance(
      canAccept: cod.canAccept,
      deficit: cod.deficit,
      reason: cod.reason,
      preview: cod,
    );
  }

  String get blockedMessage => preview?.blockedMessage ?? _legacyBlockedMessage;

  String get _legacyBlockedMessage {
    if (deficit != null) {
      final formatted = AppCurrency.format(deficit);
      if (formatted != '—') return 'Top up $formatted first';
    }
    final r = reason?.trim();
    if (r != null && r.isNotEmpty) return r;
    return 'Top up your wallet before accepting this cash delivery';
  }
}
