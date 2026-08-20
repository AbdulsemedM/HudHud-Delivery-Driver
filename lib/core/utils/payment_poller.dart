import 'dart:async';

import 'package:hudhud_delivery_driver/core/models/payment_status_result.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';

typedef PaymentStatusCallback = void Function(PaymentStatusResult result);

/// Polls payment status until terminal state or timeout.
class PaymentPoller {
  PaymentPoller({required ApiService api}) : _api = api;

  final ApiService _api;
  Timer? _timer;
  bool _stopped = false;

  static const defaultInterval = Duration(seconds: 4);
  static const defaultMaxDuration = Duration(minutes: 3);

  void start({
    required int paymentId,
    required PaymentStatusCallback onUpdate,
    Duration interval = defaultInterval,
    Duration maxDuration = defaultMaxDuration,
  }) {
    stop();
    _stopped = false;
    final deadline = DateTime.now().add(maxDuration);

    Future<void> poll() async {
      if (_stopped) return;
      if (DateTime.now().isAfter(deadline)) {
        stop();
        return;
      }
      try {
        final result = await _api.getPaymentStatus(paymentId);
        if (_stopped) return;
        onUpdate(result);
        if (result.isCompleted || result.isTerminalFailure) {
          stop();
        }
      } catch (_) {
        // Keep polling on transient errors until deadline.
      }
    }

    poll();
    _timer = Timer.periodic(interval, (_) => poll());
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }
}
