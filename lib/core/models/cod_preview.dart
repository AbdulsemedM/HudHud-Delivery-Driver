import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// Pre-accept COD wallet check from delivery payloads or financial-preview.
class CodPreview {
  const CodPreview({
    required this.canAccept,
    this.currentBalance,
    this.heldCollateral,
    this.availableBalance,
    this.requiredAmount,
    this.deficit,
    this.sufficient,
    this.reason,
  });

  final bool canAccept;
  final double? currentBalance;
  final double? heldCollateral;
  final double? availableBalance;
  final double? requiredAmount;
  final double? deficit;
  final bool? sufficient;
  final String? reason;

  static CodPreview? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    return CodPreview(
      canAccept: JsonParse.toBool(raw['can_accept'], defaultValue: true),
      currentBalance: JsonParse.toDouble(raw['current_balance']),
      heldCollateral: JsonParse.toDouble(raw['held_collateral']),
      availableBalance: JsonParse.toDouble(raw['available_balance']),
      requiredAmount: JsonParse.toDouble(raw['required_amount']),
      deficit: JsonParse.toDouble(raw['deficit'] ?? raw['required_amount']),
      sufficient: raw['sufficient'] == null
          ? null
          : JsonParse.toBool(raw['sufficient']),
      reason: raw['reason']?.toString(),
    );
  }

  static CodPreview? fromDelivery(Map<String, dynamic> delivery) {
    final raw = delivery['cod_acceptance'];
    if (raw is! Map) return null;
    return fromMap(Map<String, dynamic>.from(raw));
  }

  static CodPreview? fromFinancialPreview(Map<String, dynamic> json) {
    final cod = json['cod'];
    if (cod is Map) return fromMap(Map<String, dynamic>.from(cod));
    return null;
  }

  String get blockedMessage {
    if (deficit != null && deficit! > 0) {
      final formatted = AppCurrency.format(deficit);
      if (formatted != '—') return 'Top up $formatted first';
    }
    final r = reason?.trim();
    if (r != null && r.isNotEmpty) return r;
    return 'Top up your wallet before accepting this cash delivery';
  }

  bool get hasCodDetails =>
      currentBalance != null ||
      heldCollateral != null ||
      availableBalance != null ||
      requiredAmount != null;
}
