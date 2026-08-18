import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class DriverWallet {
  const DriverWallet({
    this.balance,
    this.currency = 'ETB',
    this.heldCollateral,
    this.availableBalance,
  });

  final double? balance;
  final String currency;
  final double? heldCollateral;
  final double? availableBalance;

  static DriverWallet? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final wallet = data['wallet'] is Map
        ? Map<String, dynamic>.from(data['wallet'] as Map)
        : data;

    return DriverWallet(
      balance: JsonParse.toDouble(wallet['balance']),
      currency: wallet['currency']?.toString() ?? 'ETB',
      heldCollateral: JsonParse.toDouble(wallet['held_collateral']),
      availableBalance: JsonParse.toDouble(wallet['available_balance']),
    );
  }
}

class WalletTransaction {
  const WalletTransaction({
    this.id,
    this.amount,
    this.description,
    this.date,
    this.status,
    this.type,
    this.currency = 'ETB',
  });

  final String? id;
  final double? amount;
  final String? description;
  final DateTime? date;
  final String? status;
  final String? type;
  final String currency;

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id']?.toString(),
      amount: JsonParse.toDouble(map['amount']),
      description: map['description']?.toString(),
      date: JsonParse.toDateTime(map['date'] ?? map['created_at']),
      status: map['status']?.toString(),
      type: map['type']?.toString(),
      currency: map['currency']?.toString() ?? 'ETB',
    );
  }

  static List<WalletTransaction> listFromJson(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => WalletTransaction.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (raw is! Map) return const [];
    final map = Map<String, dynamic>.from(raw);
    for (final key in ['data', 'transactions']) {
      final list = map[key];
      if (list is List) {
        return list
            .whereType<Map>()
            .map(
              (e) => WalletTransaction.fromMap(Map<String, dynamic>.from(e)),
            )
            .toList();
      }
    }
    return const [];
  }
}
