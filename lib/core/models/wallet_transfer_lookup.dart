import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class WalletTransferLookupResult {
  const WalletTransferLookupResult({
    this.userId,
    this.name,
    this.walletType,
    this.identifierType,
    this.success = false,
    this.message,
  });

  final int? userId;
  final String? name;
  final String? walletType;
  final String? identifierType;
  final bool success;
  final String? message;

  factory WalletTransferLookupResult.fromJson(dynamic raw) {
    if (raw is! Map) return const WalletTransferLookupResult();
    final map = Map<String, dynamic>.from(raw);
    final recipient = map['recipient'] is Map
        ? Map<String, dynamic>.from(map['recipient'] as Map)
        : map['data'] is Map && (map['data'] as Map)['recipient'] is Map
            ? Map<String, dynamic>.from(
                (map['data'] as Map)['recipient'] as Map,
              )
            : <String, dynamic>{};

    return WalletTransferLookupResult(
      success: JsonParse.toBool(map['success'], defaultValue: recipient.isNotEmpty),
      message: map['message']?.toString(),
      userId: JsonParse.toInt(recipient['user_id']),
      name: recipient['name']?.toString(),
      walletType: recipient['wallet_type']?.toString(),
      identifierType: recipient['identifier_type']?.toString(),
    );
  }
}
