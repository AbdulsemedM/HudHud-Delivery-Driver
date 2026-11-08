/// Outcome of fetching a server-flagged (optional) driver feature.
///
/// [disabled] means the backend flag is off, the route does not exist
/// (404) or the backend answered `FEATURE_DISABLED` — the UI should hide the
/// feature for this session. [failed] is a transient error (network, 5xx,
/// unparseable body) — the UI should keep whatever it already shows.
enum OptionalFeatureStatus { ok, disabled, failed }

class OptionalFeatureResult<T> {
  const OptionalFeatureResult._(this.status, this.data);

  const OptionalFeatureResult.ok(T value)
      : this._(OptionalFeatureStatus.ok, value);

  const OptionalFeatureResult.disabled()
      : this._(OptionalFeatureStatus.disabled, null);

  const OptionalFeatureResult.failed()
      : this._(OptionalFeatureStatus.failed, null);

  final OptionalFeatureStatus status;
  final T? data;

  bool get isOk => status == OptionalFeatureStatus.ok && data != null;
  bool get isDisabled => status == OptionalFeatureStatus.disabled;
  bool get isFailed => status == OptionalFeatureStatus.failed;
}
