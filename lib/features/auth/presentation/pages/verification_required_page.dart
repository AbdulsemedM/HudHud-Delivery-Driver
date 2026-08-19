import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/auth/logout_helper.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
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
    this.requirePhoneVerification = false,
    this.showEmailVerification = true,
  });

  final String? email;
  final String? phone;
  final bool emailVerified;
  final bool phoneVerified;
  final VoidCallback onContinue;
  final bool requirePhoneVerification;
  final bool showEmailVerification;

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

  bool get _canContinue {
    if (widget.requirePhoneVerification) return _phoneVerified;
    return true;
  }

  String get _headline {
    if (widget.requirePhoneVerification && !_phoneVerified) {
      return 'Verify Your Phone';
    }
    if (_allVerified) return 'All Verified!';
    return 'Verify Your Account';
  }

  String get _subtitle {
    if (widget.requirePhoneVerification && !_phoneVerified) {
      return 'You must verify your phone number before using the app.';
    }
    if (_allVerified) {
      return 'Your email and phone are verified. You\'re all set.';
    }
    return 'Please verify your email and phone number to secure your account.';
  }

  String get _continueLabel {
    if (!_canContinue) return 'Verify Phone to Continue';
    if (_allVerified || (widget.requirePhoneVerification && _phoneVerified)) {
      return 'Continue';
    }
    return 'Skip for Now';
  }

  Future<void> _syncVerificationFromProfile() async {
    final refresh = await getIt<ApiService>().refreshVerificationStatus();
    if (!mounted || refresh['success'] != true) return;
    setState(() {
      _emailVerified = refresh['emailVerified'] == true;
      _phoneVerified = refresh['phoneVerified'] == true;
    });
  }

  Future<void> _verifyEmail() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VerifyEmailPage(email: widget.email)),
    );
    if (result == true && mounted) {
      await _syncVerificationFromProfile();
    }
  }

  Future<void> _verifyPhone() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VerifyPhoneNumberPage(phone: widget.phone)),
    );
    if (result == true && mounted) {
      await _syncVerificationFromProfile();
    }
  }

  Future<void> _logOut() async {
    await LogoutHelper.logout();
    if (!mounted) return;
    context.goNamed(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.requirePhoneVerification || _phoneVerified,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 48),

                Icon(
                  _phoneVerified && (widget.requirePhoneVerification || _allVerified)
                      ? Icons.verified
                      : Icons.shield_outlined,
                  size: 72,
                  color: _phoneVerified && (widget.requirePhoneVerification || _allVerified)
                      ? Colors.green
                      : AuthColors.primary,
                ),
                const SizedBox(height: 24),

                Text(
                  _headline,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AuthColors.title,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 36),

                if (widget.showEmailVerification) ...[
                  _buildVerificationCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: widget.email ?? 'Not set',
                    verified: _emailVerified,
                    onVerify: _verifyEmail,
                  ),
                  const SizedBox(height: 14),
                ],

                _buildVerificationCard(
                  icon: Icons.phone_outlined,
                  title: 'Phone Number',
                  subtitle: widget.phone ?? 'Not set',
                  verified: _phoneVerified,
                  onVerify: _verifyPhone,
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canContinue ? widget.onContinue : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canContinue
                          ? (_allVerified || _phoneVerified
                              ? Colors.green
                              : AuthColors.primary)
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _continueLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                if (!_canContinue) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Phone verification is required to continue',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ] else if (!widget.requirePhoneVerification && !_allVerified) ...[
                  const SizedBox(height: 8),
                  Text(
                    'You can verify later from your profile',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],

                if (widget.requirePhoneVerification && !_phoneVerified) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _logOut,
                    child: Text(
                      'Log out',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],

                const SizedBox(height: 28),
              ],
            ),
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
