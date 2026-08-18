import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

const String financeNotAvailableText = 'Not available yet';

String formatFinanceAmount(double? amount, String currency) {
  if (amount == null) return financeNotAvailableText;
  return AppCurrency.format(amount, currency: currency);
}

String formatFinancePercent(double? value) {
  if (value == null) return financeNotAvailableText;
  return '${value.toStringAsFixed(2)}%';
}

