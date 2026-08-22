import 'dart:async';

import 'package:hudhud_delivery_driver/core/models/collection_payment_result.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';

typedef CollectionStatusCallback = void Function(CollectionPaymentResult result);

/// Polls driver collection-payment-status while a QR / pending screen is open.
class CollectionPoller {
  CollectionPoller({required ApiService api}) : _api = api;

  final ApiService _api;
  Timer? _timer;
  bool _stopped = false;
  int? _deliveryId;
  CollectionStatusCallback? _onUpdate;
  DateTime? _deadline;

  static const defaultInterval = Duration(seconds: 4);
  static const defaultMaxDuration = Duration(minutes: 3);

  void start({
    required int deliveryId,
    required CollectionStatusCallback onUpdate,
    Duration interval = defaultInterval,
    Duration maxDuration = defaultMaxDuration,
  }) {
    stop();
    _stopped = false;
    _deliveryId = deliveryId;
    _onUpdate = onUpdate;
    _deadline = DateTime.now().add(maxDuration);

    unawaited(pollOnce());
    _timer = Timer.periodic(interval, (_) => unawaited(pollOnce()));
  }

  Future<void> pollOnce() async {
    final deliveryId = _deliveryId;
    final onUpdate = _onUpdate;
    if (_stopped || deliveryId == null || onUpdate == null) return;
    if (_deadline != null && DateTime.now().isAfter(_deadline!)) {
      stop();
      return;
    }
    try {
      final result =
          await _api.getDeliveryCollectionPaymentStatus(deliveryId);
      if (_stopped) return;
      onUpdate(result);
      if (result.isSettled || result.isTerminalFailure) {
        stop();
      }
    } catch (_) {
      // Keep polling on transient errors until deadline.
    }
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }
}
