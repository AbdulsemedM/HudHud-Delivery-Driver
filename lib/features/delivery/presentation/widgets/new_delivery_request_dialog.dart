import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_reference.dart';
import 'package:hudhud_delivery_driver/core/utils/request_time.dart';

/// Pop-up shown on the delivery home when the available-requests poll finds
/// a request the driver has not been shown yet. Pops `true` for "View" (open
/// the available list), `false`/null for "Later".
class NewDeliveryRequestDialog extends StatelessWidget {
  const NewDeliveryRequestDialog({super.key, required this.requests});

  /// The new requests, newest poll order; the first is shown in detail.
  final List<Map<String, dynamic>> requests;

  static const Color _orange = Color(0xFFF55905);

  static Future<bool> show(
    BuildContext context,
    List<Map<String, dynamic>> requests,
  ) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (_) => NewDeliveryRequestDialog(requests: requests),
    );
    return open == true;
  }

  @override
  Widget build(BuildContext context) {
    final first = requests.first;
    final count = requests.length;
    final orderNumber = DeliveryReference.orderNumber(first);
    final pickup = _text(first['pickup_location']);
    final dropoff = _text(first['dropoff_location']);
    final requested = RequestTime.describe(first);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping, color: _orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1
                  ? 'new_request.title_one'.tr()
                  : 'new_request.title_many'
                      .tr(namedArgs: {'count': count.toString()}),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (orderNumber != null)
            Text(
              orderNumber,
              style: TextStyle(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (requested != null) ...[
            const SizedBox(height: 4),
            _timeRow(requested),
          ],
          if (pickup != null) ...[
            const SizedBox(height: 10),
            _placeRow(Icons.radio_button_checked, Colors.green.shade600, pickup),
          ],
          if (dropoff != null) ...[
            const SizedBox(height: 6),
            _placeRow(Icons.location_on, Colors.red.shade600, dropoff),
          ],
          if (count > 1) ...[
            const SizedBox(height: 10),
            Text(
              'new_request.more'.tr(namedArgs: {'count': (count - 1).toString()}),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('new_request.later'.tr()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: Text('new_request.view'.tr()),
        ),
      ],
    );
  }

  static Widget _timeRow(String text) {
    return Row(
      children: [
        Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  static Widget _placeRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  static String? _text(dynamic value) {
    final s = value?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
}
