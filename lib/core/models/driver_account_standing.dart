import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
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
    this.totalDeliveries,
    this.totalEarnings,
    this.completionRate,
    this.source = FinanceDataSource.primary,
    this.sourceMessage,
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
  final int? totalDeliveries;
  final double? totalEarnings;
  final double? completionRate;
  final FinanceDataSource source;
  final String? sourceMessage;

  double get displayAmountOwed =>
      amountDriverOwesPlatform ?? amountOwedToPlatform ?? 0;

  String get displayStanding =>
      standingLabel?.trim().isNotEmpty == true
          ? standingLabel!
          : limitStatus.displayLabel;

  static double? _readAmount(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = JsonParse.toDouble(map[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static DriverAccountStanding? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final account = data['account'] is Map
        ? Map<String, dynamic>.from(data['account'] as Map)
        : <String, dynamic>{};
    final summary = data['summary'] is Map
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : <String, dynamic>{};
    final wallet = data['wallet'] is Map
        ? Map<String, dynamic>.from(data['wallet'] as Map)
        : <String, dynamic>{};

    double? read(List<String> keys) =>
        _readAmount(account, keys) ??
        _readAmount(summary, keys) ??
        _readAmount(wallet, keys) ??
        _readAmount(data, keys) ??
        _readAmount(map, keys);

    final currency = _readString(account, const ['currency']) ??
        _readString(summary, const ['currency']) ??
        _readString(wallet, const ['currency', 'wallet_currency']) ??
        _readString(data, const ['currency', 'wallet_currency']) ??
        _readString(map, const ['currency', 'wallet_currency']) ??
        'ETB';

    return DriverAccountStanding(
      currency: currency,
      walletBalance: read(const [
        'wallet_balance',
        'balance',
        'current_balance',
      ]),
      heldCollateral: read(const ['held_collateral', 'collateral_held']),
      amountOwedToPlatform: read(const [
        'amount_owed_to_platform',
        'amount_owed',
      ]),
      amountDriverOwesPlatform: read(const [
        'amount_driver_owes_platform',
        'driver_owes_platform',
      ]),
      availableAcceptanceLimit: read(const [
        'available_acceptance_limit',
        'available_limit',
      ]),
      limitWarningThreshold:
          read(const ['limit_warning_threshold', 'warning_threshold']),
      limitBlockThreshold:
          read(const ['limit_block_threshold', 'block_threshold']),
      limitStatus: LimitStatus.fromApi(
        _readString(account, const ['limit_status']) ??
            _readString(summary, const ['limit_status']) ??
            _readString(data, const ['limit_status']),
      ),
      standingLabel: _readString(account, const ['standing_label']) ??
          _readString(summary, const ['standing_label']) ??
          _readString(data, const ['standing_label']),
      debtStatus: _readString(account, const ['debt_status']) ??
          _readString(summary, const ['debt_status']) ??
          _readString(data, const ['debt_status']),
      debtReasonSummary: JsonParse.toStringList(
        account['debt_reason_summary'] ??
            summary['debt_reason_summary'] ??
            data['debt_reason_summary'],
      ),
      debtAsOf: JsonParse.toDateTime(
        account['debt_as_of'] ?? summary['debt_as_of'] ?? data['debt_as_of'],
      ),
      actions: JsonParse.toStringList(
        account['actions'] ?? summary['actions'] ?? data['actions'],
      ),
      totalDeliveries: JsonParse.toInt(
        data['total_deliveries'] ??
            summary['total_deliveries'] ??
            account['total_deliveries'],
      ),
      totalEarnings: JsonParse.toDouble(
        data['total_earnings'] ??
            summary['total_earnings'] ??
            account['total_earnings'],
      ),
      completionRate: JsonParse.toDouble(
        data['completion_rate'] ??
            summary['completion_rate'] ??
            account['completion_rate'],
      ),
      source: FinanceDataSource.primary,
    );
  }

  DriverAccountStanding copyWith({
    String? currency,
    double? walletBalance,
    double? heldCollateral,
    double? amountOwedToPlatform,
    double? amountDriverOwesPlatform,
    double? availableAcceptanceLimit,
    double? limitWarningThreshold,
    double? limitBlockThreshold,
    LimitStatus? limitStatus,
    String? standingLabel,
    String? debtStatus,
    List<String>? debtReasonSummary,
    DateTime? debtAsOf,
    List<String>? actions,
    int? totalDeliveries,
    double? totalEarnings,
    double? completionRate,
    FinanceDataSource? source,
    String? sourceMessage,
  }) {
    return DriverAccountStanding(
      currency: currency ?? this.currency,
      walletBalance: walletBalance ?? this.walletBalance,
      heldCollateral: heldCollateral ?? this.heldCollateral,
      amountOwedToPlatform: amountOwedToPlatform ?? this.amountOwedToPlatform,
      amountDriverOwesPlatform:
          amountDriverOwesPlatform ?? this.amountDriverOwesPlatform,
      availableAcceptanceLimit:
          availableAcceptanceLimit ?? this.availableAcceptanceLimit,
      limitWarningThreshold: limitWarningThreshold ?? this.limitWarningThreshold,
      limitBlockThreshold: limitBlockThreshold ?? this.limitBlockThreshold,
      limitStatus: limitStatus ?? this.limitStatus,
      standingLabel: standingLabel ?? this.standingLabel,
      debtStatus: debtStatus ?? this.debtStatus,
      debtReasonSummary: debtReasonSummary ?? this.debtReasonSummary,
      debtAsOf: debtAsOf ?? this.debtAsOf,
      actions: actions ?? this.actions,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      completionRate: completionRate ?? this.completionRate,
      source: source ?? this.source,
      sourceMessage: sourceMessage ?? this.sourceMessage,
    );
  }
}
