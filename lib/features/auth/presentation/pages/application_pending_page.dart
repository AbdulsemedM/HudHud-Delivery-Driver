import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/auth/logout_helper.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

class ApplicationPendingPage extends StatefulWidget {
  const ApplicationPendingPage({super.key});

  @override
  State<ApplicationPendingPage> createState() => _ApplicationPendingPageState();
}

class _ApplicationPendingPageState extends State<ApplicationPendingPage> {
  bool _checking = false;

  Future<void> _refresh() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final res = await getIt<ApiService>().getDriverApplicationStatus();
      final status = ApplicationStatus.normalize(
            res?['application_status']?.toString(),
          ) ??
          ApplicationStatus.fromLegacyUserStatus(res?['status']?.toString());
      if (status != null) {
        await ApplicationStatusGate.persist(
          status,
          reason: ApplicationStatus.reasonFrom(res),
        );
      }
      if (!mounted) return;
      if (ApplicationStatus.canWork(status)) {
        final mode = await getIt<SecureStorageService>().getDriverMode();
        if (!mounted) return;
        context.goNamed(
          mode == 'delivery' ? AppRouter.deliveryHome : AppRouter.rideHome,
        );
        return;
      }
      final route = ApplicationStatusGate.routeFor(status);
      if (route != null && route != AppRouter.applicationPending) {
        context.goNamed(route);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
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
              Icon(Icons.hourglass_top, size: 64, color: AuthColors.primary),
              const SizedBox(height: 24),
              Text(
                'Application under review',
                style: AppTextStyles.headline2.copyWith(
                  color: AuthColors.title,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You can sign in, but you cannot go online or accept jobs until an administrator approves your application.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AuthColors.hint,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _checking ? null : _refresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuthColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Check status'),
                ),
              ),
              const SizedBox(height: 12),
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
