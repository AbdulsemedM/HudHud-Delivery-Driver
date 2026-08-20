import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class PaymentMethod {
  const PaymentMethod({
    required this.code,
    this.name,
    this.description,
    this.icon,
    this.enabled = true,
    this.sortOrder = 0,
  });

  final String code;
  final String? name;
  final String? description;
  final String? icon;
  final bool enabled;
  final int sortOrder;

  factory PaymentMethod.fromJson(Map<String, dynamic> map) {
    return PaymentMethod(
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString(),
      description: map['description']?.toString(),
      icon: map['icon']?.toString(),
      enabled: JsonParse.toBool(map['is_active'], defaultValue: true),
      sortOrder: JsonParse.toInt(map['sort_order']) ?? 0,
    );
  }
}
