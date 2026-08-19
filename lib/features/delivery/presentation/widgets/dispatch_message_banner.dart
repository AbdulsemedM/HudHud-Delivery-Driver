import 'package:flutter/material.dart';

class DispatchMessageBanner extends StatelessWidget {
  const DispatchMessageBanner({
    super.key,
    required this.message,
    this.dark = false,
  });

  final String message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : Colors.blueGrey.shade800;
    final bg = dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.blueGrey.shade50;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.near_me_outlined, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, height: 1.35, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
