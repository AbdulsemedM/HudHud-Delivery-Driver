import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/models/cod_preview.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class DriverFinancialPreview {
  const DriverFinancialPreview({
    required this.currency,
    this.deliveryId,
    this.pricing = const PricingPreview(),
    this.driverEarning = const DriverEarningPreview(),
    this.account = const DriverAccountPreview(),
    this.cod = const CodPreview(canAccept: true),
    this.acceptance = const AcceptancePreview(),
    this.expiresAt,
  });

  final String currency;
  final int? deliveryId;
  final PricingPreview pricing;
  final DriverEarningPreview driverEarning;
  final DriverAccountPreview account;
  final CodPreview cod;
  final AcceptancePreview acceptance;
  final DateTime? expiresAt;

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  bool get canAccept =>
      acceptance.canAccept &&
      !account.limitStatus.blocksAcceptance &&
      cod.canAccept;

  static DriverFinancialPreview? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;

    final pricingRaw = data['pricing'];
    final earningRaw = data['driver_earning'];
    final accountRaw = data['driver_account'];
    final codRaw = data['cod'];
    final acceptanceRaw = data['acceptance'];

    return DriverFinancialPreview(
      currency: data['currency']?.toString() ?? 'ETB',
      deliveryId: JsonParse.toInt(data['delivery_id']),
      pricing: pricingRaw is Map
          ? PricingPreview.fromMap(Map<String, dynamic>.from(pricingRaw))
          : const PricingPreview(),
      driverEarning: earningRaw is Map
          ? DriverEarningPreview.fromMap(
              Map<String, dynamic>.from(earningRaw),
            )
          : const DriverEarningPreview(),
      account: accountRaw is Map
          ? DriverAccountPreview.fromMap(
              Map<String, dynamic>.from(accountRaw),
            )
          : const DriverAccountPreview(),
      cod: codRaw is Map
          ? CodPreview.fromMap(Map<String, dynamic>.from(codRaw)) ??
              const CodPreview(canAccept: true)
          : const CodPreview(canAccept: true),
      acceptance: acceptanceRaw is Map
          ? AcceptancePreview.fromMap(
              Map<String, dynamic>.from(acceptanceRaw),
            )
          : const AcceptancePreview(),
      expiresAt: JsonParse.toDateTime(data['expires_at']),
    );
  }
}

class PricingPreview {
  const PricingPreview({
    this.customerTotal,
    this.zoneId,
    this.zoneName,
    this.zoneVersion,
    this.routeBasis,
    this.billableDistanceKm,
    this.estimatedDurationMinutes,
  });

  final double? customerTotal;
  final String? zoneId;
  final String? zoneName;
  final int? zoneVersion;
  final String? routeBasis;
  final double? billableDistanceKm;
  final int? estimatedDurationMinutes;

  factory PricingPreview.fromMap(Map<String, dynamic> map) {
    return PricingPreview(
      customerTotal: JsonParse.toDouble(map['customer_total']),
      zoneId: map['zone_id']?.toString(),
      zoneName: map['zone_name']?.toString(),
      zoneVersion: JsonParse.toInt(map['zone_version']),
      routeBasis: map['route_basis']?.toString(),
      billableDistanceKm: JsonParse.toDouble(map['billable_distance_km']),
      estimatedDurationMinutes:
          JsonParse.toInt(map['estimated_duration_minutes']),
    );
  }
}

class DriverEarningPreview {
  const DriverEarningPreview({
    this.grossEarning,
    this.platformCommission,
    this.adjustments,
    this.expectedNetEarning,
    this.isEstimate = true,
    this.calculationBasis,
  });

  final double? grossEarning;
  final double? platformCommission;
  final double? adjustments;
  final double? expectedNetEarning;
  final bool isEstimate;
  final String? calculationBasis;

  factory DriverEarningPreview.fromMap(Map<String, dynamic> map) {
    return DriverEarningPreview(
      grossEarning: JsonParse.toDouble(map['gross_earning']),
      platformCommission: JsonParse.toDouble(map['platform_commission']),
      adjustments: JsonParse.toDouble(map['adjustments']),
      expectedNetEarning: JsonParse.toDouble(map['expected_net_earning']),
      isEstimate: JsonParse.toBool(map['is_estimate'], defaultValue: true),
      calculationBasis: map['calculation_basis']?.toString(),
    );
  }
}

class DriverAccountPreview {
  const DriverAccountPreview({
    this.walletBalance,
    this.heldCollateral,
    this.amountOwedToPlatform,
    this.amountDriverOwesPlatform,
    this.availableAcceptanceLimit,
    this.limitAfterAcceptance,
    this.limitStatus = LimitStatus.unknown,
    this.riskLevel,
    this.limitWarningThreshold,
    this.limitBlockThreshold,
    this.debtReasonSummary = const [],
  });

  final double? walletBalance;
  final double? heldCollateral;
  final double? amountOwedToPlatform;
  final double? amountDriverOwesPlatform;
  final double? availableAcceptanceLimit;
  final double? limitAfterAcceptance;
  final LimitStatus limitStatus;
  final String? riskLevel;
  final double? limitWarningThreshold;
  final double? limitBlockThreshold;
  final List<String> debtReasonSummary;

  double get displayAmountOwed =>
      amountDriverOwesPlatform ?? amountOwedToPlatform ?? 0;

  factory DriverAccountPreview.fromMap(Map<String, dynamic> map) {
    return DriverAccountPreview(
      walletBalance: JsonParse.toDouble(map['wallet_balance']),
      heldCollateral: JsonParse.toDouble(map['held_collateral']),
      amountOwedToPlatform: JsonParse.toDouble(map['amount_owed_to_platform']),
      amountDriverOwesPlatform:
          JsonParse.toDouble(map['amount_driver_owes_platform']),
      availableAcceptanceLimit:
          JsonParse.toDouble(map['available_acceptance_limit']),
      limitAfterAcceptance: JsonParse.toDouble(map['limit_after_acceptance']),
      limitStatus: LimitStatus.fromApi(map['limit_status']?.toString()),
      riskLevel: map['risk_level']?.toString(),
      limitWarningThreshold:
          JsonParse.toDouble(map['limit_warning_threshold']),
      limitBlockThreshold: JsonParse.toDouble(map['limit_block_threshold']),
      debtReasonSummary: JsonParse.toStringList(map['debt_reason_summary']),
    );
  }
}

class AcceptancePreview {
  const AcceptancePreview({
    this.canAccept = true,
    this.blockingReasons = const [],
  });

  final bool canAccept;
  final List<String> blockingReasons;

  factory AcceptancePreview.fromMap(Map<String, dynamic> map) {
    return AcceptancePreview(
      canAccept: JsonParse.toBool(map['can_accept'], defaultValue: true),
      blockingReasons: JsonParse.toStringList(map['blocking_reasons']),
    );
  }
}
