/// Notification event names from the HudHud push notification spec.
/// Live wallet events use lowercase snake_case; taxonomy uses UPPER_SNAKE.
/// Always normalize with [normalizeEvent] before routing.
class NotificationEvents {
  NotificationEvents._();

  // Wallet — live
  static const walletLow = 'wallet_low';
  static const insufficientBalance = 'insufficient_balance';
  static const commissionDeducted = 'commission_deducted';
  static const earningCredited = 'earning_credited';
  static const settlementRequired = 'settlement_required';

  // Rider jobs — next server priority
  static const newOrder = 'new_order';
  static const nearbyJobAvailable = 'nearby_job_available';
  static const proximityDeliveryOffer = 'proximity_delivery_offer';
  static const acceptTimerWarning = 'accept_timer_warning';
  static const jobAssigned = 'job_assigned';
  static const customerCancelled = 'customer_cancelled';
  static const pickupReminder = 'pickup_reminder';
  static const batchOpportunity = 'batch_opportunity';

  static const orderStatusChanged = 'order_status_changed';
  static const pickupAssigned = 'pickup_assigned';
  static const enRoutePickup = 'en_route_pickup';
  static const atPickup = 'at_pickup';
  static const enRouteDropoff = 'en_route_dropoff';
  static const atDropoff = 'at_dropoff';
  static const delivered = 'delivered';
  static const otpRequired = 'otp_required';
  static const screenVerifyDelivery = 'verify_delivery';

  // Phase 10 system dispatch (food orders) — sent as data.type
  static const foodDispatchOffer = 'food_dispatch_offer';
  static const foodDispatchAssigned = 'food_dispatch_assigned';
  static const foodDispatchUnassigned = 'food_dispatch_unassigned';

  static bool isFoodDispatchAssignmentEvent(String event) =>
      event == foodDispatchAssigned || event == foodDispatchUnassigned;

  // Peak quests (Phase 3) — sent as data.type
  static const questProgress = 'quest_progress';
  static const questCompleted = 'quest_completed';

  static const lifecycleStatuses = {
    pickupAssigned,
    enRoutePickup,
    atPickup,
    enRouteDropoff,
    atDropoff,
    delivered,
  };

  // Screen hints
  static const screenWalletTopUp = 'wallet_topup';
  static const screenWalletTransactions = 'wallet_transactions';
  static const screenQuests = 'quests';

  static String normalizeEvent(String? raw) =>
      (raw ?? '').trim().toLowerCase();

  static bool isWalletTopUpEvent(String event) =>
      event == walletLow ||
      event == insufficientBalance ||
      event == settlementRequired;

  static bool isWalletTransactionsEvent(String event) =>
      event == commissionDeducted || event == earningCredited;

  static bool isJobOfferEvent(String event) =>
      event == newOrder ||
      event == nearbyJobAvailable ||
      event == proximityDeliveryOffer ||
      event == acceptTimerWarning ||
      event == batchOpportunity;

  static bool isQuestEvent(String event) =>
      event == questProgress || event == questCompleted;

  static bool isDeliveryLifecycleEvent(String event) =>
      event == orderStatusChanged ||
      event == 'delivery_completed' ||
      event == 'order_rated' ||
      event == 'service_rated' ||
      event == jobAssigned ||
      event == pickupReminder ||
      lifecycleStatuses.contains(event);

  static String? parseDeliveryStatus(Map<String, dynamic> data) {
    for (final key in ['new_status', 'status']) {
      final raw = normalizeEvent(data[key]?.toString());
      if (raw.isNotEmpty) return raw;
    }
    final event = normalizeEvent(data['event']?.toString());
    if (lifecycleStatuses.contains(event)) return event;
    final type = normalizeEvent(data['type']?.toString());
    if (lifecycleStatuses.contains(type)) return type;
    return null;
  }
}
