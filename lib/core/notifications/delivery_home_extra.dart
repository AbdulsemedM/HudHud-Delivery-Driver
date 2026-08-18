/// GoRouter extra when opening delivery home from a push or deep link.
class DeliveryHomeExtra {
  const DeliveryHomeExtra({
    this.deliveryId,
    this.showCancelledMessage = false,
  });

  final int? deliveryId;
  final bool showCancelledMessage;

  static int? parseDeliveryId(Map<String, dynamic> data) {
    for (final key in [
      'delivery_id',
      'package_delivery_id',
      'deliveryId',
      'id',
    ]) {
      final raw = data[key];
      if (raw == null) continue;
      if (raw is int) return raw;
      final parsed = int.tryParse(raw.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }
}
