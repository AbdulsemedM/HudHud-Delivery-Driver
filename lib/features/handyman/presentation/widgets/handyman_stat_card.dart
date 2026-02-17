import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

class HandymanStatCard extends StatelessWidget {
  const HandymanStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AuthColors.title,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AuthColors.hint,
            ),
          ),
        ],
      ),
    );
  }
}
