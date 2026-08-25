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
  DateTime? _startedAt;
  Duration _interval = defaultInterval;
  Duration? _slowInterval;
  Duration? _fastPhaseDuration;

  static const defaultInterval = Duration(seconds: 4);
  static const defaultMaxDuration = Duration(minutes: 3);

  /// Wallet top-up: every 3s for 30s, then every 10s for up to 5 minutes.
  static const walletFastInterval = Duration(seconds: 3);
  static const walletSlowInterval = Duration(seconds: 10);
  static const walletFastPhase = Duration(seconds: 30);
  static const walletMaxDuration = Duration(minutes: 5);

  void start({
    required int paymentId,
    required PaymentStatusCallback onUpdate,
    PaymentFatalCallback? onFatal,
    Duration interval = defaultInterval,
    Duration maxDuration = defaultMaxDuration,
    Duration? slowInterval,
    Duration? fastPhaseDuration,
  }) {
    stop();
    _stopped = false;
    _paymentId = paymentId;
    _onUpdate = onUpdate;
    _onFatal = onFatal;
    _interval = interval;
    _slowInterval = slowInterval;
    _fastPhaseDuration = fastPhaseDuration;
    _startedAt = DateTime.now();
    _deadline = DateTime.now().add(maxDuration);

    unawaited(pollOnce());
    _scheduleNext();
  }

  void startWalletTopUp({
    required int paymentId,
    required PaymentStatusCallback onUpdate,
    PaymentFatalCallback? onFatal,
  }) {
    start(
      paymentId: paymentId,
      onUpdate: onUpdate,
      onFatal: onFatal,
      interval: walletFastInterval,
      maxDuration: walletMaxDuration,
      slowInterval: walletSlowInterval,
      fastPhaseDuration: walletFastPhase,
    );
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = null;
    if (_stopped) return;
    final elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    final useSlow = _slowInterval != null &&
        _fastPhaseDuration != null &&
        elapsed >= _fastPhaseDuration!;
    final next = useSlow ? _slowInterval! : _interval;
    _timer = Timer(next, () {
      unawaited(_tick());
    });
  }

  Future<void> _tick() async {
    await pollOnce();
    if (!_stopped) _scheduleNext();
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
