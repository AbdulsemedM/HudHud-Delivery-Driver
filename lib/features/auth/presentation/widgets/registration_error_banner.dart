import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';

/// Inline registration error shown above the submit button.
class RegistrationErrorBanner extends StatelessWidget {
  const RegistrationErrorBanner({
    super.key,
    required this.message,
    this.tone = RegistrationErrorTone.error,
    this.onDismiss,
  });

  final String message;
  final RegistrationErrorTone tone;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      RegistrationErrorTone.error => (
          background: Colors.red.shade50,
          border: Colors.red.shade200,
          icon: Colors.red.shade700,
          text: Colors.red.shade800,
        ),
      RegistrationErrorTone.warning => (
          background: Colors.orange.shade50,
          border: Colors.orange.shade200,
          icon: Colors.orange.shade800,
          text: Colors.orange.shade900,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tone == RegistrationErrorTone.error
                ? Icons.error_outline
                : Icons.warning_amber_rounded,
            color: colors.icon,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: colors.text),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: colors.icon),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}

enum RegistrationErrorTone { error, warning }
