import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class DriverAccountStanding {
  const DriverAccountStanding({
    this.currency = 'ETB',
    this.walletBalance,
    this.heldCollateral,
    this.amountOwedToPlatform,
    this.amountDriverOwesPlatform,
    this.availableAcceptanceLimit,
    this.limitWarningThreshold,
    this.limitBlockThreshold,
    this.limitStatus = LimitStatus.unknown,
    this.standingLabel,
    this.debtStatus,
    this.debtReasonSummary = const [],
    this.debtAsOf,
    this.actions = const [],
  });

  final String currency;
  final double? walletBalance;
  final double? heldCollateral;
  final double? amountOwedToPlatform;
  final double? amountDriverOwesPlatform;
  final double? availableAcceptanceLimit;
  final double? limitWarningThreshold;
  final double? limitBlockThreshold;
  final LimitStatus limitStatus;
  final String? standingLabel;
  final String? debtStatus;
  final List<String> debtReasonSummary;
  final DateTime? debtAsOf;
  final List<String> actions;

  double get displayAmountOwed =>
      amountDriverOwesPlatform ?? amountOwedToPlatform ?? 0;

  String get displayStanding =>
      standingLabel?.trim().isNotEmpty == true
          ? standingLabel!
          : limitStatus.displayLabel;

  static DriverAccountStanding? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;

    return DriverAccountStanding(
      currency: data['currency']?.toString() ?? 'ETB',
      walletBalance: JsonParse.toDouble(data['wallet_balance']),
      heldCollateral: JsonParse.toDouble(data['held_collateral']),
      amountOwedToPlatform:
          JsonParse.toDouble(data['amount_owed_to_platform']),
      amountDriverOwesPlatform:
          JsonParse.toDouble(data['amount_driver_owes_platform']),
      availableAcceptanceLimit:
          JsonParse.toDouble(data['available_acceptance_limit']),
      limitWarningThreshold:
          JsonParse.toDouble(data['limit_warning_threshold']),
      limitBlockThreshold: JsonParse.toDouble(data['limit_block_threshold']),
      limitStatus: LimitStatus.fromApi(data['limit_status']?.toString()),
      standingLabel: data['standing_label']?.toString(),
      debtStatus: data['debt_status']?.toString(),
      debtReasonSummary: JsonParse.toStringList(data['debt_reason_summary']),
      debtAsOf: JsonParse.toDateTime(data['debt_as_of']),
      actions: JsonParse.toStringList(data['actions']),
    );
  }
}
