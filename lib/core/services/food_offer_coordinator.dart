import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/models/food_dispatch_offer.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/assigned_orders_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/food_offer_page.dart';

/// Phase 10 system dispatch: shows the full-screen food-order offer.
///
/// - Polls `GET /api/driver/dispatch/offers/current` while the app is in
///   the foreground and a driver / courier is signed in, at the interval the
///   API asks for (5 s with an offer, 15 s online, 30 s offline, 60 s when
///   system dispatch is off for the driver's city).
/// - An FCM push `type: food_dispatch_offer` (foreground or tapped) polls
///   at once; the API, not the push, decides what is shown.
/// - Each offer opens once ([FoodOfferTracker]); never on top of another.
class FoodOfferCoordinator with WidgetsBindingObserver {
  FoodOfferCoordinator({
    required ApiService api,
    required SecureStorageService storage,
    FoodOfferTracker? tracker,
  })  : _api = api,
        _storage = storage,
        _tracker = tracker ?? FoodOfferTracker();

  final ApiService _api;
  final SecureStorageService _storage;
  final FoodOfferTracker _tracker;

  Timer? _timer;
  bool _attached = false;
  bool _polling = false;
  bool _foreground = true;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule(const Duration(seconds: 3));
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      unawaited(pollNow());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _timer?.cancel();
    }
  }

  /// FCM data message (foreground) or notification tap.
  Future<void> handlePush(Map<String, dynamic> data) async {
    if (!FoodDispatchOffer.isOfferPush(data)) return;
    await pollNow();
  }

  /// `food_dispatch_assigned` / `food_dispatch_unassigned` (ops action).
  void openAssignedOrders() {
    final navigator = AppRouter.rootNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const AssignedOrdersPage()),
    );
  }

  Future<void> pollNow() async {
    if (_polling) return;
    _polling = true;
    var next = const Duration(seconds: 30);
    try {
      if (!await _isSignedInDriver()) {
        next = const Duration(seconds: 60);
        return;
      }
      final poll = await _api.getCurrentFoodDispatchOffer();
      next = Duration(seconds: poll.pollAfterSeconds);
      final offer = poll.offer;
      if (offer != null && _tracker.shouldShow(offer, DateTime.now())) {
        _show(offer);
      }
    } catch (_) {
      // Network blips: try again later; an unanswered offer simply expires.
    } finally {
      _polling = false;
      if (_attached && _foreground) _schedule(next);
    }
  }

  Future<bool> _isSignedInDriver() async {
    if (!await _storage.hasToken()) return false;
    final type = await _storage.getUserType();
    return UserTypeConstants.isDriver(type) ||
        UserTypeConstants.isCourier(type);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(pollNow()));
  }

  void _show(FoodDispatchOffer offer) {
    final navigator = AppRouter.rootNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    _tracker.markShowing(offer);
    navigator
        .push<bool>(
          MaterialPageRoute<bool>(
            fullscreenDialog: true,
            builder: (_) => FoodOfferPage(offer: offer),
          ),
        )
        .whenComplete(() {
      _tracker.markClosed(offer.offerId);
      // After a decline / expiry the next offer may already be waiting.
      if (_attached && _foreground) _schedule(const Duration(seconds: 2));
    });
  }
}
