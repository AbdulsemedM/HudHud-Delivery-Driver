import 'package:flutter/material.dart';

/// Driver acceptance limit status from financial-preview / account-standing APIs.
enum LimitStatus {
  withinLimit,
  nearLimit,
  atLimit,
  overdue,
  blocked,
  unknown;

  static LimitStatus fromApi(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'within_limit':
        return LimitStatus.withinLimit;
      case 'near_limit':
        return LimitStatus.nearLimit;
      case 'at_limit':
        return LimitStatus.atLimit;
      case 'overdue':
        return LimitStatus.overdue;
      case 'blocked':
        return LimitStatus.blocked;
      default:
        return LimitStatus.unknown;
    }
  }

  /// Whether Accept should be disabled based on limit status alone.
  bool get blocksAcceptance =>
      this == LimitStatus.overdue || this == LimitStatus.blocked;

  /// Amber warning banner for finance screens.
  bool get showWarning => this == LimitStatus.nearLimit;

  /// Red critical banner for finance screens.
  bool get showCritical =>
      this == LimitStatus.atLimit ||
      this == LimitStatus.overdue ||
      this == LimitStatus.blocked;

  bool get showFinanceAlert => showWarning || showCritical;

  Color get financeBackgroundColor {
    if (showCritical) return Colors.red.shade50;
    if (showWarning) return Colors.amber.shade50;
    if (this == LimitStatus.withinLimit) return Colors.green.shade50;
    return Colors.grey.shade50;
  }

  Color get financeForegroundColor {
    if (showCritical) return Colors.red.shade900;
    if (showWarning) return Colors.amber.shade900;
    if (this == LimitStatus.withinLimit) return Colors.green.shade900;
    return Colors.grey.shade800;
  }

  Color get financeBorderColor {
    if (showCritical) return Colors.red.shade200;
    if (showWarning) return Colors.amber.shade200;
    if (this == LimitStatus.withinLimit) return Colors.green.shade200;
    return Colors.grey.shade200;
  }

  String get displayLabel {
    switch (this) {
      case LimitStatus.withinLimit:
        return 'Good standing';
      case LimitStatus.nearLimit:
        return 'Approaching limit';
      case LimitStatus.atLimit:
        return 'At limit';
      case LimitStatus.overdue:
        return 'Action required';
      case LimitStatus.blocked:
        return 'Blocked';
      case LimitStatus.unknown:
        return '—';
    }
  }
}
