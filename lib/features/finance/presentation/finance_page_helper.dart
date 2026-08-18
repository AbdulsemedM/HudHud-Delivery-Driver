import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/auth/logout_helper.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';

/// Shared auth and restriction handling for finance screens.
class FinancePageHelper {
  static Future<bool> handleFetchOutcome(
    BuildContext context,
    FinanceFetchOutcome outcome, {
    String? message,
  }) async {
    if (!context.mounted) return false;
    switch (outcome) {
      case FinanceFetchOutcome.unauthorized:
        await LogoutHelper.logout();
        if (!context.mounted) return false;
        context.goNamed(AppRouter.login);
        return false;
      case FinanceFetchOutcome.forbidden:
        return false;
      default:
        return true;
    }
  }

  static bool isUsingFallbackOrCache(FinanceDataSource source) =>
      source == FinanceDataSource.fallback ||
      source == FinanceDataSource.cached;

  static Widget sourceBanner({
    required FinanceDataSource source,
    String? message,
  }) {
    if (source == FinanceDataSource.primary) {
      return const SizedBox.shrink();
    }
    final isCached = source == FinanceDataSource.cached;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCached ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCached ? Colors.orange.shade100 : Colors.blue.shade100,
        ),
      ),
      child: Text(
        message?.isNotEmpty == true
            ? message!
            : isCached
                ? 'Showing last saved finance data. Pull to retry.'
                : 'Showing fallback finance data from profile.',
        style: TextStyle(
          fontSize: 12,
          color: isCached ? Colors.orange.shade900 : Colors.blue.shade900,
        ),
      ),
    );
  }

  static Widget forbiddenBody({String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message?.isNotEmpty == true
              ? message!
              : 'You do not have access to driver finance data.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
