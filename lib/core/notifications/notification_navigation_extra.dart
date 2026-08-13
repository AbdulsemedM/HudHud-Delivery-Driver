/// Optional context passed when navigating from a push notification tap.
class NotificationNavigationExtra {
  const NotificationNavigationExtra({
    this.bannerMessage,
    this.showTopUpHint = false,
  });

  final String? bannerMessage;
  final bool showTopUpHint;

  factory NotificationNavigationExtra.fromData(Map<String, dynamic> data) {
    final event = data['event']?.toString().toLowerCase() ?? '';
    final balance = data['balance']?.toString();
    final required = data['required']?.toString();
    final currency = data['currency']?.toString() ?? 'ETB';
    final orderNumber = data['order_number']?.toString();

    String? banner;
    var showTopUp = false;

    switch (event) {
      case 'wallet_low':
        showTopUp = true;
        if (balance != null) {
          banner = 'Wallet balance is low: $currency $balance. Top up to keep accepting cash orders.';
        }
        break;
      case 'insufficient_balance':
        showTopUp = true;
        if (balance != null && required != null) {
          banner =
              'Balance $currency $balance — need $currency $required to accept cash orders.';
        } else if (balance != null) {
          banner = 'Insufficient balance: $currency $balance';
        }
        break;
      case 'settlement_required':
        showTopUp = true;
        if (balance != null) {
          banner = 'Settlement required. Current balance: $currency $balance';
        }
        break;
      case 'commission_deducted':
        final fee = data['fee']?.toString();
        final keeps = data['rider_keeps']?.toString();
        if (fee != null && orderNumber != null) {
          banner = 'Platform fee $currency $fee deducted for $orderNumber.'
              '${keeps != null ? ' You keep $currency $keeps in cash.' : ''}';
        }
        break;
      case 'earning_credited':
        final amount = data['amount']?.toString();
        if (amount != null && orderNumber != null) {
          banner = '$currency $amount credited for $orderNumber.';
        } else if (amount != null) {
          banner = '$currency $amount credited to your wallet.';
        }
        break;
    }

    return NotificationNavigationExtra(
      bannerMessage: banner,
      showTopUpHint: showTopUp,
    );
  }
}
