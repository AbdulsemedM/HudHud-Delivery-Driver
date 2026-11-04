import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

/// Admin hold on money leaving driver wallets: `423 {code: WITHDRAWALS_ON_HOLD}`.
class WithdrawalHoldNotice {
  WithdrawalHoldNotice._();

  static const String code = 'WITHDRAWALS_ON_HOLD';
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
        title: const Text('Withdrawals on hold'),
        content: const Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (context.mounted) context.pushNamed(AppRouter.supportChat);
            },
            child: const Text('Contact support'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
