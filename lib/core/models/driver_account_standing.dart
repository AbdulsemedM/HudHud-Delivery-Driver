import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class DriverAccountStanding {
  const DriverAccountStanding({
    this.currency = 'ETB',
    this.walletId,
    this.walletType,
    this.walletAutoProvisioned,
    this.walletBalance,
    this.heldCollateral,
    this.activePlatformFeeCommitment,
    this.amountOwedToPlatform,
    this.amountDriverOwesPlatform,
    this.availableAcceptanceLimit,
    this.limitWarningThreshold,
    this.limitBlockThreshold,
    this.limitStatus = LimitStatus.unknown,
    this.riskLevel,
    this.applicationStatus,
    this.canAcceptCod,
    this.standingLabel,
    this.debtStatus,
    this.debtReasonSummary = const [],
    this.debtAsOf,
    this.actions = const [],
    this.foodAndVendorCodCommitments = const [],
    this.packageDeliveryPlatformFeeCommitments = const [],
    this.outstandingSettlements = const [],
    this.calculationBasis = const {},
    this.totalDeliveries,
    this.totalEarnings,
    this.completionRate,
    this.source = FinanceDataSource.primary,
    this.sourceMessage,
  });

  final String currency;
  final int? walletId;
  final String? walletType;
  final bool? walletAutoProvisioned;
  final double? walletBalance;
  final double? heldCollateral;
  final double? activePlatformFeeCommitment;
  final double? amountOwedToPlatform;
  final double? amountDriverOwesPlatform;
  final double? availableAcceptanceLimit;
  final double? limitWarningThreshold;
  final double? limitBlockThreshold;
  final LimitStatus limitStatus;
  final String? riskLevel;
  final String? applicationStatus;
  final bool? canAcceptCod;
  final String? standingLabel;
  final String? debtStatus;
  final List<String> debtReasonSummary;
  final DateTime? debtAsOf;
  final List<String> actions;
  final List<Map<String, dynamic>> foodAndVendorCodCommitments;
  final List<Map<String, dynamic>> packageDeliveryPlatformFeeCommitments;
  final List<Map<String, dynamic>> outstandingSettlements;
  final Map<String, String> calculationBasis;
  final int? totalDeliveries;
  final double? totalEarnings;
  final double? completionRate;
  final FinanceDataSource source;
  final String? sourceMessage;

  int get totalCommitmentCount =>
      foodAndVendorCodCommitments.length +
      packageDeliveryPlatformFeeCommitments.length;

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

  static List<Map<String, dynamic>> _readMapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Map<String, String> _readCalculationBasis(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
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
    final commitments = data['commitments'] is Map
        ? Map<String, dynamic>.from(data['commitments'] as Map)
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

    final actionsRaw = data['recommended_actions'] ??
        account['recommended_actions'] ??
        summary['recommended_actions'] ??
        data['actions'] ??
        account['actions'] ??
        summary['actions'];

    return DriverAccountStanding(
      currency: currency,
      walletId: JsonParse.toInt(wallet['id']),
      walletType: wallet['type']?.toString(),
      walletAutoProvisioned: wallet.containsKey('auto_provisioned')
          ? JsonParse.toBool(wallet['auto_provisioned'])
          : null,
      walletBalance: read(const [
        'wallet_balance',
        'balance',
        'current_balance',
      ]),
      heldCollateral: read(const ['held_collateral', 'collateral_held']),
      activePlatformFeeCommitment: read(const [
        'active_platform_fee_commitment',
      ]),
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
      riskLevel: _readString(data, const ['risk_level']) ??
          _readString(account, const ['risk_level']),
      applicationStatus: _readString(data, const ['application_status']) ??
          _readString(account, const ['application_status']),
      canAcceptCod: data.containsKey('can_accept_cod')
          ? JsonParse.toBool(data['can_accept_cod'])
          : null,
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
        data['as_of'] ??
            account['as_of'] ??
            summary['as_of'] ??
            account['debt_as_of'] ??
            summary['debt_as_of'] ??
            data['debt_as_of'],
      ),
      actions: JsonParse.toStringList(actionsRaw),
      foodAndVendorCodCommitments:
          _readMapList(commitments['food_and_vendor_cod']),
      packageDeliveryPlatformFeeCommitments:
          _readMapList(commitments['package_delivery_platform_fees']),
      outstandingSettlements: _readMapList(data['outstanding_settlements']),
      calculationBasis: _readCalculationBasis(data['calculation_basis']),
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
    int? walletId,
    String? walletType,
    bool? walletAutoProvisioned,
    double? walletBalance,
    double? heldCollateral,
    double? activePlatformFeeCommitment,
    double? amountOwedToPlatform,
    double? amountDriverOwesPlatform,
    double? availableAcceptanceLimit,
    double? limitWarningThreshold,
    double? limitBlockThreshold,
    LimitStatus? limitStatus,
    String? riskLevel,
    String? applicationStatus,
    bool? canAcceptCod,
    String? standingLabel,
    String? debtStatus,
    List<String>? debtReasonSummary,
    DateTime? debtAsOf,
    List<String>? actions,
    List<Map<String, dynamic>>? foodAndVendorCodCommitments,
    List<Map<String, dynamic>>? packageDeliveryPlatformFeeCommitments,
    List<Map<String, dynamic>>? outstandingSettlements,
    Map<String, String>? calculationBasis,
    int? totalDeliveries,
    double? totalEarnings,
    double? completionRate,
    FinanceDataSource? source,
    String? sourceMessage,
  }) {
    return DriverAccountStanding(
      currency: currency ?? this.currency,
      walletId: walletId ?? this.walletId,
      walletType: walletType ?? this.walletType,
      walletAutoProvisioned: walletAutoProvisioned ?? this.walletAutoProvisioned,
      walletBalance: walletBalance ?? this.walletBalance,
      heldCollateral: heldCollateral ?? this.heldCollateral,
      activePlatformFeeCommitment:
          activePlatformFeeCommitment ?? this.activePlatformFeeCommitment,
      amountOwedToPlatform: amountOwedToPlatform ?? this.amountOwedToPlatform,
      amountDriverOwesPlatform:
          amountDriverOwesPlatform ?? this.amountDriverOwesPlatform,
      availableAcceptanceLimit:
          availableAcceptanceLimit ?? this.availableAcceptanceLimit,
      limitWarningThreshold: limitWarningThreshold ?? this.limitWarningThreshold,
      limitBlockThreshold: limitBlockThreshold ?? this.limitBlockThreshold,
      limitStatus: limitStatus ?? this.limitStatus,
      riskLevel: riskLevel ?? this.riskLevel,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      canAcceptCod: canAcceptCod ?? this.canAcceptCod,
      standingLabel: standingLabel ?? this.standingLabel,
      debtStatus: debtStatus ?? this.debtStatus,
      debtReasonSummary: debtReasonSummary ?? this.debtReasonSummary,
      debtAsOf: debtAsOf ?? this.debtAsOf,
      actions: actions ?? this.actions,
      foodAndVendorCodCommitments:
          foodAndVendorCodCommitments ?? this.foodAndVendorCodCommitments,
      packageDeliveryPlatformFeeCommitments:
          packageDeliveryPlatformFeeCommitments ??
              this.packageDeliveryPlatformFeeCommitments,
      outstandingSettlements:
          outstandingSettlements ?? this.outstandingSettlements,
      calculationBasis: calculationBasis ?? this.calculationBasis,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      completionRate: completionRate ?? this.completionRate,
      source: source ?? this.source,
      sourceMessage: sourceMessage ?? this.sourceMessage,
    );
  }
}
