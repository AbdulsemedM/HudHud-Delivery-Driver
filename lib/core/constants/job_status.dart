import 'package:flutter/material.dart';

/// Human labels and badge colors for order / delivery / ride status keys.
///
/// The backend adds statuses over time (e.g. COD food orders may now sit in
/// `confirmed`). Unknown keys must never crash or show raw snake_case, so they
/// fall back to a title-cased label and a neutral color.
class JobStatus {
  JobStatus._();

  static const Map<String, String> _labels = {
    // Food orders
    'pending': 'Pending',
    'paid': 'Paid',
    'confirmed': 'Confirmed',
    'accepted': 'Accepted',
    'processing': 'Processing',
    'preparing': 'Preparing',
    'ready_for_pickup': 'Ready for pickup',
    'in_transit': 'In transit',
    'delayed': 'Delayed',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
    // Parcels
    'assigned': 'Assigned',
    'pickup_assigned': 'Pickup assigned',
    'en_route_pickup': 'Heading to pickup',
    'at_pickup': 'At pickup',
    'picked_up': 'Picked up',
    'en_route_dropoff': 'Heading to drop-off',
    'at_dropoff': 'At drop-off',
    'failed': 'Failed',
    'returned': 'Returned',
    // Rides
    'searching': 'Searching',
    'arriving': 'Arriving',
    'in_progress': 'In progress',
    'completed': 'Completed',
    'no_drivers': 'No drivers',
    'expired': 'Expired',
  };

  static String _key(String? raw) => raw?.trim().toLowerCase() ?? '';

  /// Display label for [raw]; `—` when empty.
  static String label(String? raw) {
    final key = _key(raw);
    if (key.isEmpty || key == '—') return '—';
    final known = _labels[key];
    if (known != null) return known;
    final words = key
        .split(RegExp(r'[_\-\s]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '—';
    final text = words.join(' ');
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Badge color for [raw]; grey for unknown keys.
  static Color color(String? raw) {
    switch (_key(raw)) {
      case 'pending':
      case 'searching':
        return Colors.orange;
      case 'paid':
      case 'confirmed':
      case 'accepted':
      case 'assigned':
      case 'pickup_assigned':
        return Colors.blue;
      case 'processing':
      case 'preparing':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.orange;
      case 'en_route_pickup':
      case 'at_pickup':
      case 'arriving':
      case 'picked_up':
      case 'in_transit':
      case 'en_route_dropoff':
      case 'at_dropoff':
      case 'in_progress':
        return Colors.indigo;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'failed':
      case 'returned':
      case 'no_drivers':
      case 'expired':
        return Colors.red;
      case 'delayed':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}
