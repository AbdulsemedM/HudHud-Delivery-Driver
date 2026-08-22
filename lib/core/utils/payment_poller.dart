import 'dart:async';

import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/models/payment_status_result.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

typedef PaymentStatusCallback = void Function(PaymentStatusResult result);
typedef PaymentFatalCallback = void Function(AppException error);

/// Polls payment status until terminal state or timeout.
class PaymentPoller {
  PaymentPoller({required ApiService api}) : _api = api;

  final ApiService _api;
  Timer? _timer;
  bool _stopped = false;
  int? _paymentId;
  PaymentStatusCallback? _onUpdate;
  PaymentFatalCallback? _onFatal;
  DateTime? _deadline;

  static const defaultInterval = Duration(seconds: 4);
  static const defaultMaxDuration = Duration(minutes: 3);

  void start({
    required int paymentId,
    required PaymentStatusCallback onUpdate,
    PaymentFatalCallback? onFatal,
    Duration interval = defaultInterval,
    Duration maxDuration = defaultMaxDuration,
  }) {
    stop();
    _stopped = false;
    _paymentId = paymentId;
    _onUpdate = onUpdate;
    _onFatal = onFatal;
    _deadline = DateTime.now().add(maxDuration);

    unawaited(pollOnce());
    _timer = Timer.periodic(interval, (_) => unawaited(pollOnce()));
  }

  /// Immediate poll (e.g. when the user returns from a payment app).
  Future<void> pollOnce() async {
    final paymentId = _paymentId;
    final onUpdate = _onUpdate;
    if (_stopped || paymentId == null || onUpdate == null) return;
    if (_deadline != null && DateTime.now().isAfter(_deadline!)) {
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
    } on AppException catch (e) {
      if (_stopped) return;
      if (e.code == PaymentMethodCodes.qpayTransactionReferenceMissing) {
        stop();
        _onFatal?.call(e);
        return;
      }
      // Keep polling on transient errors (including QPAY_STATUS_UNAVAILABLE).
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
