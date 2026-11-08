import 'package:flutter/material.dart';

/// Delivery-home strip for food / gift orders assigned to the driver.
/// Text is passed in (already translated).
class AssignedOrdersBanner extends StatelessWidget {
  const AssignedOrdersBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.hasGift,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool hasGift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('assigned-orders-banner'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                hasGift ? Icons.card_giftcard : Icons.delivery_dining,
                color: const Color(0xFFF55905),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}
