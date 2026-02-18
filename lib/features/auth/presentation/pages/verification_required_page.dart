import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/verify_email_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/verify_phonenumber_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

/// Shown after login when the user's email and/or phone is not yet verified.
/// [onContinue] is called when the user taps "Continue to App".
class VerificationRequiredPage extends StatefulWidget {
  const VerificationRequiredPage({
    super.key,
    required this.email,
    required this.phone,
    required this.emailVerified,
    required this.phoneVerified,
    required this.onContinue,
  });

  final String? email;
  final String? phone;
  final bool emailVerified;
  final bool phoneVerified;
  final VoidCallback onContinue;

  @override
  State<VerificationRequiredPage> createState() => _VerificationRequiredPageState();
}

class _VerificationRequiredPageState extends State<VerificationRequiredPage> {
  late bool _emailVerified;
  late bool _phoneVerified;

  @override
  void initState() {
    super.initState();
    _emailVerified = widget.emailVerified;
    _phoneVerified = widget.phoneVerified;
  }

  bool get _allVerified => _emailVerified && _phoneVerified;

  Future<void> _verifyEmail() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VerifyEmailPage(email: widget.email)),
    );
    if (result == true && mounted) {
      setState(() => _emailVerified = true);
    }
  }

  Future<void> _verifyPhone() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VerifyPhoneNumberPage(phone: widget.phone)),
    );
    if (result == true && mounted) {
      setState(() => _phoneVerified = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),

              Icon(
                _allVerified ? Icons.verified : Icons.shield_outlined,
                size: 72,
                color: _allVerified ? Colors.green : AuthColors.primary,
              ),
              const SizedBox(height: 24),

              Text(
                _allVerified ? 'All Verified!' : 'Verify Your Account',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AuthColors.title),
              ),
              const SizedBox(height: 8),
              Text(
                _allVerified
                    ? 'Your email and phone are verified. You\'re all set.'
                    : 'Please verify your email and phone number to secure your account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              ),

              const SizedBox(height: 36),

              // Email verification card
              _buildVerificationCard(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: widget.email ?? 'Not set',
                verified: _emailVerified,
                onVerify: _verifyEmail,
              ),

              const SizedBox(height: 14),

              // Phone verification card
              _buildVerificationCard(
                icon: Icons.phone_outlined,
                title: 'Phone Number',
                subtitle: widget.phone ?? 'Not set',
                verified: _phoneVerified,
                onVerify: _verifyPhone,
              ),

              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allVerified ? Colors.green : AuthColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _allVerified ? 'Continue' : 'Skip for Now',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              if (!_allVerified) ...[
                const SizedBox(height: 8),
                Text(
                  'You can verify later from your profile',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool verified,
    required VoidCallback onVerify,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: verified ? Colors.green.withOpacity(0.05) : Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: verified ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: verified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              verified ? Icons.check_circle : icon,
              color: verified ? Colors.green : Colors.orange.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AuthColors.title),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (verified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
              ),
            )
          else
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: onVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Verify', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}
