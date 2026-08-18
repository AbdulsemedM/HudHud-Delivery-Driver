import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';
import 'package:hudhud_delivery_driver/core/notifications/delivery_home_extra.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/active_delivery_cache.dart';

class ActiveJobConflict {
  static const message =
      'Finish your current job before accepting a new request.';

  static Future<void> show(BuildContext context, ActiveJob? job) {
    getIt<ActiveDeliveryCache>().saveFromActiveJob(job);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (job?.status != null || job?.trackingNumber != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (job?.trackingNumber != null) job!.trackingNumber,
                    if (job?.status != null)
                      job!.status!.replaceAll('_', ' '),
                  ].join(' · '),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: job?.id == null
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          openCurrentJob(context, job!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('View current job'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void openCurrentJob(BuildContext context, ActiveJob job) {
    getIt<ActiveDeliveryCache>().saveFromActiveJob(job);
    switch (job.type) {
      case ActiveJobType.delivery:
        context.goNamed(
          AppRouter.deliveryHome,
          extra: DeliveryHomeExtra(deliveryId: job.id),
        );
        return;
      case ActiveJobType.ride:
      case ActiveJobType.order:
        context.goNamed(AppRouter.rideHome);
        return;
      case ActiveJobType.unknown:
        if (job.id != null) {
          context.goNamed(
            AppRouter.deliveryHome,
            extra: DeliveryHomeExtra(deliveryId: job.id),
          );
        }
        return;
    }
  }

  static Widget banner({
    required ActiveJob? job,
    required VoidCallback onView,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ),
          TextButton(
            onPressed: job?.id == null ? null : onView,
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}
