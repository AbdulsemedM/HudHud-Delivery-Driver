import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_idempotency.dart';

/// Polls stored pending wallet top-up payment IDs on launch and app resume.
class WalletTopUpRecoveryService with WidgetsBindingObserver {
  WalletTopUpRecoveryService({
    required ApiService api,
    required SecureStorageService storage,
  })  : _api = api,
        _storage = storage;

  final ApiService _api;
  final SecureStorageService _storage;
  final List<VoidCallback> _listeners = [];
  bool _attached = false;
  bool _syncing = false;

  bool hasPending = false;
  bool lastSyncSettled = false;

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(syncPendingTopUps());
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncPendingTopUps());
    }
  }

  Future<void> syncPendingTopUps() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final ids = await _storage.getPendingWalletTopUpPaymentIds();
      var settled = false;
      var pending = false;

      for (final id in ids) {
        try {
          final status = await _api.getPaymentStatus(id);
          if (status.isCompleted) {
            await clearPayment(id);
            settled = true;
          } else if (status.isTerminalFailure) {
            await clearPayment(id);
          } else {
            pending = true;
          }
        } catch (_) {
          pending = true;
        }
      }

      hasPending = pending;
      lastSyncSettled = settled;
      _notify();
    } finally {
      _syncing = false;
    }
  }

  Future<void> clearPayment(int paymentId) async {
    await _storage.removePendingWalletTopUpPaymentId(paymentId);
    final remaining = await _storage.getPendingWalletTopUpPaymentIds();
    if (remaining.isEmpty) {
      await _storage.deleteIdempotencyKey(PaymentIdempotency.walletTopUpScope);
      await _storage.deleteIdempotencyKey(
        PaymentIdempotency.walletTopUpFingerprintScope,
      );
    }
  }
}
