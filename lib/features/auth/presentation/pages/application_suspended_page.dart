import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/auth/logout_helper.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

class ApplicationSuspendedPage extends StatefulWidget {
  const ApplicationSuspendedPage({super.key});

  @override
  State<ApplicationSuspendedPage> createState() =>
      _ApplicationSuspendedPageState();
}

class _ApplicationSuspendedPageState extends State<ApplicationSuspendedPage> {
  String? _reason;

  @override
  void initState() {
    super.initState();
    getIt<SecureStorageService>().getStatusReason().then((value) {
      if (mounted) setState(() => _reason = value);
    });
  }

  Future<void> _logout() async {
    await LogoutHelper.logout();
    if (!mounted) return;
    context.goNamed(AppRouter.login);
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
              const Spacer(),
              Icon(Icons.block, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 24),
              Text(
                'Account suspended',
                style: AppTextStyles.headline2.copyWith(
                  color: AuthColors.title,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _reason == null || _reason!.isEmpty
                    ? 'Your driver account has been suspended. Contact support if you believe this is a mistake.'
                    : _reason!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AuthColors.hint,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              TextButton(
                onPressed: _logout,
                child: const Text('Sign out'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
