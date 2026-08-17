/// Deduplicates in-app delivery status events by `delivery_id + status`.
///
/// Server status is authoritative: a newer API status overwrites a cached
/// push, and an older push is ignored after a newer status is known.
class DeliveryNotificationDeduper {
  static const statusOrder = [
    'pickup_assigned',
    'en_route_pickup',
    'at_pickup',
    'en_route_dropoff',
    'at_dropoff',
    'delivered',
  ];

  static const _aliases = {
    'accepted': 'pickup_assigned',
    'assigned': 'pickup_assigned',
    'arrived_pickup': 'at_pickup',
    'pickup_arrived': 'at_pickup',
    'in_transit': 'en_route_dropoff',
    'picked_up': 'en_route_dropoff',
    'out_for_delivery': 'en_route_dropoff',
    'started': 'en_route_dropoff',
    'completed': 'delivered',
    'complete': 'delivered',
    'pending_otp': 'delivered',
  };

  final Map<int, String> _lastStatus = {};
  final Set<String> _seenKeys = {};

  static String normalize(String status) {
    final raw = status.toLowerCase().trim();
    return _aliases[raw] ?? raw;
  }

  /// Returns false for duplicates and out-of-order older statuses.
  bool shouldApply({required int deliveryId, required String status}) {
    final normalized = normalize(status);
    if (normalized.isEmpty) return true;

    final key = '$deliveryId+$normalized';
    if (_seenKeys.contains(key)) return false;

    final previous = _lastStatus[deliveryId];
    if (previous != null && _isOlder(normalized, previous)) return false;

    _seenKeys.add(key);
    _lastStatus[deliveryId] = normalized;
    return true;
  }

  /// Records the authoritative API status so later older pushes are ignored.
  void recordFromApi(int deliveryId, String status) {
    final normalized = normalize(status);
    if (normalized.isEmpty) return;
    _seenKeys.add('$deliveryId+$normalized');
    final previous = _lastStatus[deliveryId];
    if (previous == null || !_isOlder(normalized, previous)) {
      _lastStatus[deliveryId] = normalized;
    }
  }

  bool _isOlder(String candidate, String current) {
    final candidateIndex = statusOrder.indexOf(candidate);
    final currentIndex = statusOrder.indexOf(current);
    if (candidateIndex < 0 || currentIndex < 0) return false;
    return candidateIndex < currentIndex;
  }
}
