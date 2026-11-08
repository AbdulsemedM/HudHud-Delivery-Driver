import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/models/driver_food_order.dart';

/// 4-digit recipient code entry for a Phase 6 gift delivery.
///
/// Text comes from the caller (already translated) so the card stays a plain
/// widget. [locked] disables entry after the API's DELIVERY_OTP_LOCKED.
class GiftDeliveryCodeCard extends StatelessWidget {
  const GiftDeliveryCodeCard({
    super.key,
    required this.controller,
    required this.title,
    required this.prompt,
    required this.hint,
    required this.submitLabel,
    required this.onSubmit,
    this.errorText,
    this.locked = false,
    this.busy = false,
  });

  static const Color brandOrange = Color(0xFFF55905);

  final TextEditingController controller;
  final String title;
  final String prompt;
  final String hint;
  final String submitLabel;
  final VoidCallback onSubmit;
  final String? errorText;
  final bool locked;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = !locked && !busy;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandOrange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: brandOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prompt,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('gift-delivery-code-field'),
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: GiftDeliveryCode.length,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(GiftDeliveryCode.length),
            ],
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
            ),
            onSubmitted: (_) {
              if (enabled) onSubmit();
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 16, letterSpacing: 0),
              counterText: '',
              errorText: errorText,
              errorMaxLines: 3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const ValueKey('gift-delivery-code-submit'),
              onPressed: enabled ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
