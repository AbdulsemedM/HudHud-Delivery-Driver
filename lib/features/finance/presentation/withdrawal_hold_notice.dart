import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

/// Admin hold on money leaving driver wallets: `423 {code: WITHDRAWALS_ON_HOLD}`
/// on cash-out, and (when the API sends it) `withdrawals_on_hold: true` on
/// GET /wallet so the notice shows before the rider tries.
class WithdrawalHoldNotice {
  WithdrawalHoldNotice._();

  static const String code = 'WITHDRAWALS_ON_HOLD';

  /// English fallback (tests / no localization context).
  static const String message =
      'Withdrawals are temporarily on hold. Please contact HudHud support.';

  static bool matches(Object error) {
    if (error is! AppException) return false;
    if (error.code == code) return true;
    final details = error.details;
    return details is Map && details['code']?.toString() == code;
  }

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('wallet.withdrawals_on_hold_title'.tr()),
        content: Text('errors.withdrawals_on_hold'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (context.mounted) context.pushNamed(AppRouter.supportChat);
            },
            child: Text('wallet.contact_support'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.done'.tr()),
          ),
        ],
      ),
    );
  }

  /// Inline notice for the wallet card.
  static Widget banner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'errors.withdrawals_on_hold'.tr(),
              style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
