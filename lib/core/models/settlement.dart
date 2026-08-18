import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class SettlementSummary {
  const SettlementSummary({
    this.currency = 'ETB',
    this.periodFrom,
    this.periodTo,
    this.grossDeliveryRevenue,
    this.grossRideRevenue,
    this.platformCommission,
    this.cancellationFeesOwed,
    this.codCollected,
    this.refundAdjustments,
    this.withdrawals,
    this.previousSettlements,
    this.amountOwedToDriver,
    this.amountDriverOwesPlatform,
    this.netPayable,
    this.asOf,
  });

  final String currency;
  final String? periodFrom;
  final String? periodTo;
  final double? grossDeliveryRevenue;
  final double? grossRideRevenue;
  final double? platformCommission;
  final double? cancellationFeesOwed;
  final double? codCollected;
  final double? refundAdjustments;
  final double? withdrawals;
  final double? previousSettlements;
  final double? amountOwedToDriver;
  final double? amountDriverOwesPlatform;
  final double? netPayable;
  final DateTime? asOf;

  static SettlementSummary? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final summary = map['summary'] is Map
        ? Map<String, dynamic>.from(map['summary'] as Map)
        : map;
    final period = map['period'] is Map
        ? Map<String, dynamic>.from(map['period'] as Map)
        : null;

    return SettlementSummary(
      currency: map['currency']?.toString() ?? 'ETB',
      periodFrom: period?['from']?.toString(),
      periodTo: period?['to']?.toString(),
      grossDeliveryRevenue:
          JsonParse.toDouble(summary['gross_delivery_revenue']),
      grossRideRevenue: JsonParse.toDouble(summary['gross_ride_revenue']),
      platformCommission: JsonParse.toDouble(summary['platform_commission']),
      cancellationFeesOwed:
          JsonParse.toDouble(summary['cancellation_fees_owed']),
      codCollected: JsonParse.toDouble(summary['cod_collected']),
      refundAdjustments: JsonParse.toDouble(summary['refund_adjustments']),
      withdrawals: JsonParse.toDouble(summary['withdrawals']),
      previousSettlements: JsonParse.toDouble(summary['previous_settlements']),
      amountOwedToDriver: JsonParse.toDouble(summary['amount_owed_to_driver']),
      amountDriverOwesPlatform:
          JsonParse.toDouble(summary['amount_driver_owes_platform']),
      netPayable: JsonParse.toDouble(summary['net_payable']),
      asOf: JsonParse.toDateTime(map['as_of']),
    );
  }
}

class SettlementBatch {
  const SettlementBatch({
    required this.id,
    this.periodFrom,
    this.periodTo,
    this.grossEarnings,
    this.commission,
    this.adjustments,
    this.netAmount,
    this.status,
    this.createdAt,
    this.paidAt,
    this.currency = 'ETB',
  });

  final String id;
  final String? periodFrom;
  final String? periodTo;
  final double? grossEarnings;
  final double? commission;
  final double? adjustments;
  final double? netAmount;
  final String? status;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String currency;

  factory SettlementBatch.fromMap(Map<String, dynamic> map) {
    return SettlementBatch(
      id: map['id']?.toString() ?? '',
      periodFrom: map['period_from']?.toString(),
      periodTo: map['period_to']?.toString(),
      grossEarnings: JsonParse.toDouble(map['gross_earnings']),
      commission: JsonParse.toDouble(map['commission']),
      adjustments: JsonParse.toDouble(map['adjustments']),
      netAmount: JsonParse.toDouble(map['net_amount']),
      status: map['status']?.toString(),
      createdAt: JsonParse.toDateTime(map['created_at']),
      paidAt: JsonParse.toDateTime(map['paid_at']),
      currency: map['currency']?.toString() ?? 'ETB',
    );
  }

  static List<SettlementBatch> listFromJson(dynamic raw) {
    if (raw is! Map) return const [];
    final data = raw['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => SettlementBatch.fromMap(Map<String, dynamic>.from(e)))
        .where((b) => b.id.isNotEmpty)
        .toList();
  }

  static SettlementBatch? detailFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final batch = SettlementBatch.fromMap(data);
    return batch.id.isEmpty ? null : batch;
  }
}

class SettlementListMeta {
  const SettlementListMeta({
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 20,
    this.total = 0,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  factory SettlementListMeta.fromJson(dynamic raw) {
    if (raw is! Map) return const SettlementListMeta();
    final meta = raw['meta'];
    if (meta is! Map) return const SettlementListMeta();
    final m = Map<String, dynamic>.from(meta);
    return SettlementListMeta(
      currentPage: JsonParse.toInt(m['current_page']) ?? 1,
      lastPage: JsonParse.toInt(m['last_page']) ?? 1,
      perPage: JsonParse.toInt(m['per_page']) ?? 20,
      total: JsonParse.toInt(m['total']) ?? 0,
    );
  }
}
