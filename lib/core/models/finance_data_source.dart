enum FinanceDataSource {
  primary,
  fallback,
  cached,
}

enum FinanceFetchOutcome {
  success,
  unauthorized,
  forbidden,
  unavailable,
  notFound,
  error,
}

class FinanceFetchResult<T> {
  const FinanceFetchResult({
    this.data,
    this.outcome = FinanceFetchOutcome.success,
    this.source = FinanceDataSource.primary,
    this.message,
  });

  final T? data;
  final FinanceFetchOutcome outcome;
  final FinanceDataSource source;
  final String? message;

  bool get isSuccess => outcome == FinanceFetchOutcome.success && data != null;
  bool get isUnauthorized => outcome == FinanceFetchOutcome.unauthorized;
  bool get isForbidden => outcome == FinanceFetchOutcome.forbidden;
  bool get isUnavailable => outcome == FinanceFetchOutcome.unavailable;
}
