import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/models/branch_handoff.dart';

class BranchHandoffCard extends StatelessWidget {
  const BranchHandoffCard({
    super.key,
    required this.handoff,
    required this.isResending,
    required this.resendLimitReached,
    required this.resendSecondsRemaining,
    required this.onResend,
  });

  final BranchHandoff handoff;
  final bool isResending;
  final bool resendLimitReached;
  final int resendSecondsRemaining;
  final VoidCallback onResend;

  bool get _resendDisabled =>
      isResending || resendLimitReached || resendSecondsRemaining > 0;

  String get _buttonLabel {
    if (resendLimitReached) return 'Resend limit reached';
    if (resendSecondsRemaining > 0) {
      return 'Resend in ${resendSecondsRemaining}s';
    }
    return 'Resend OTP SMS';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Branch handoff required',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (handoff.branchName != null) ...[
            const SizedBox(height: 8),
            Text(
              handoff.branchName!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            ),
          ],
          if (handoff.otp != null) ...[
            const SizedBox(height: 10),
            SelectableText(
              handoff.otp!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Give this code only to the authorized teller. Wait for confirmation before leaving.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resendDisabled ? null : onResend,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white60,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: isResending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sms_outlined, size: 18),
              label: Text(_buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
