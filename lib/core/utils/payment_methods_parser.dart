import 'package:hudhud_delivery_driver/core/models/payment_method.dart';

List<PaymentMethod> parsePaymentMethodsList(
  dynamic raw, {
  Set<String>? allowedCodes,
  bool activeOnly = true,
}) {
  List<dynamic> list;
  if (raw is List) {
    list = raw;
  } else if (raw is Map) {
    final data = raw['data'];
    if (data is List) {
      list = data;
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List;
    } else {
      list = const [];
    }
  } else {
    list = const [];
  }

  final methods = list
      .whereType<Map>()
      .map((e) => PaymentMethod.fromJson(Map<String, dynamic>.from(e)))
      .where((m) => m.code.isNotEmpty)
      .where((m) => !activeOnly || m.enabled)
      .where((m) => m.canUse)
      .where((m) => !m.isQpay || m.canInitiateQpay)
      .toList();

  if (allowedCodes != null) {
  methods.retainWhere((m) => allowedCodes.contains(m.code));
  }

  methods.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return methods;
}
