class DeliveryReference {
  DeliveryReference._();

  static String? awb(Map<String, dynamic> delivery) {
    final external = _nonEmpty(
      delivery['external_order_id'] ??
          delivery['external_reference'] ??
          delivery['awb'],
    );
    if (external != null) {
      const courierPrefix = 'HUDHUD-';
      return external.toUpperCase().startsWith(courierPrefix)
          ? external.substring(courierPrefix.length)
          : external;
    }

    return _nonEmpty(delivery['tracking_number']);
  }

  static String? description(Map<String, dynamic> delivery) {
    return _nonEmpty(delivery['package_description']);
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
