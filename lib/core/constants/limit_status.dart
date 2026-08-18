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

  bool get showWarning =>
      this == LimitStatus.nearLimit || this == LimitStatus.atLimit;

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
