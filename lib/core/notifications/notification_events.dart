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
  static const acceptTimerWarning = 'accept_timer_warning';
  static const jobAssigned = 'job_assigned';
  static const customerCancelled = 'customer_cancelled';
  static const pickupReminder = 'pickup_reminder';
  static const batchOpportunity = 'batch_opportunity';

  // Screen hints
  static const screenWalletTopUp = 'wallet_topup';
  static const screenWalletTransactions = 'wallet_transactions';

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
      event == acceptTimerWarning ||
      event == batchOpportunity;
}
