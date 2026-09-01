import 'package:shared_preferences/shared_preferences.dart';

/// Persists unacknowledged job-offer alert state across isolates.
class JobOfferAlertStore {
  JobOfferAlertStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _pendingKey = 'job_offer_alert_pending';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<bool> isPending() async {
    final prefs = await _prefs;
    return prefs.getBool(_pendingKey) ?? false;
  }

  Future<void> setPending(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_pendingKey, value);
  }

  Future<void> clearPending() => setPending(false);
}
