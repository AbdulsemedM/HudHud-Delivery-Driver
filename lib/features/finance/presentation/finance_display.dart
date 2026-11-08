import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

const String financeNotAvailableText = 'Not available yet';

/// Title shown instead of "Wallet balance" when the balance is negative.
const String walletOwedTitle = 'You owe HudHud';

/// Hint under a negative balance. COD orders debit the vendor + platform
/// share of the cash collected, which can take the wallet below zero.
const String walletOwedHint =
    'This is the vendor and HudHud share of cash you collected on cash-on-delivery orders. Top up your wallet to settle it.';

const String codCashCollectedLabel = 'Cash collected – owed to HudHud';
const String deliveryEarningsLabel = 'Earnings';
const String driverWalletRewardLabel = 'Driver wallet reward';

String formatFinanceAmount(double? amount, String currency) {
  if (amount == null) return financeNotAvailableText;
  return AppCurrency.format(amount, currency: currency);
}

String formatFinancePercent(double? value) {
  if (value == null) return financeNotAvailableText;
  return '${value.toStringAsFixed(2)}%';
}

/// True when the driver owes HudHud (negative wallet balance).
bool isWalletBalanceOwed(double? balance) => balance != null && balance < 0;

/// Amount to display for a wallet balance: the owed amount as a positive
/// number when negative, otherwise the balance itself.
double? walletDisplayAmount(double? balance) {
  if (balance == null) return null;
  return balance < 0 ? -balance : balance;
}

/// "Wallet balance" or "You owe HudHud" depending on the sign.
String walletBalanceTitle(double? balance) =>
    isWalletBalanceOwed(balance) ? walletOwedTitle : 'Wallet balance';

/// `You owe HudHud ETB 120.00` for negative balances, else `ETB 120.00`.
String formatWalletBalance(double? balance, String currency) {
  if (balance == null) return financeNotAvailableText;
  final formatted = AppCurrency.format(
    walletDisplayAmount(balance),
    currency: currency,
  );
  return isWalletBalanceOwed(balance) ? '$walletOwedTitle $formatted' : formatted;
}

/// Row title for a wallet transaction.
String walletTransactionTitle(WalletTransaction tx) {
  switch (tx.kind) {
    case WalletTransactionKind.codCashCollected:
      return codCashCollectedLabel;
    case WalletTransactionKind.deliveryEarnings:
      return deliveryEarningsLabel;
    case WalletTransactionKind.reward:
      return driverWalletRewardLabel;
    case WalletTransactionKind.other:
      final description = tx.description?.trim();
      if (description != null && description.isNotEmpty) return description;
      final type = tx.type?.trim();
      if (type != null && type.isNotEmpty) return type;
      return 'Transaction';
  }
}

/// Short context line (order number / explanation) for a wallet row, or null.
String? walletTransactionDetail(WalletTransaction tx) {
  final order = tx.orderNumber;
  final orderText = order == null ? null : 'Order #$order';
  switch (tx.kind) {
    case WalletTransactionKind.codCashCollected:
      return orderText == null
          ? 'Vendor + platform share of cash collected'
          : '$orderText · vendor + platform share';
    case WalletTransactionKind.deliveryEarnings:
      final isTopUp = tx.description?.toLowerCase().contains('top-up') ?? false;
      if (isTopUp) {
        return orderText == null
            ? 'Delivery discount top-up (COD)'
            : '$orderText · delivery discount top-up (COD)';
      }
      return orderText;
    case WalletTransactionKind.reward:
    case WalletTransactionKind.other:
      return null;
  }
}

/// `+ETB 50.00` for credits, `−ETB 120.00` for debits, unsigned otherwise.
String formatWalletTransactionAmount(WalletTransaction tx) {
  final amount = tx.amount;
  if (amount == null) return financeNotAvailableText;
  final formatted = AppCurrency.format(amount.abs(), currency: tx.currency);
  if (tx.isDebit) return '−$formatted';
  if (tx.isCredit) return '+$formatted';
  return AppCurrency.format(amount, currency: tx.currency);
}
