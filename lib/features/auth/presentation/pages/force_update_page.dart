import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/app_update_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

/// Non-dismissible screen that blocks the app until the user opens the store.
class ForceUpdatePage extends StatefulWidget {
  const ForceUpdatePage({
    super.key,
    required this.requirement,
  });

  final AppUpdateRequirement requirement;

  @override
  State<ForceUpdatePage> createState() => _ForceUpdatePageState();
}

class _ForceUpdatePageState extends State<ForceUpdatePage> {
  bool _opening = false;

  Future<void> _openStore() async {
    if (_opening) return;
    setState(() => _opening = true);
    final opened =
        await getIt<AppUpdateService>().openStore(widget.requirement.storeUrl);
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('update.open_store_failed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),
                const Icon(
                  Icons.system_update_alt_rounded,
                  size: 72,
                  color: AuthColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'update.title'.tr(),
                  style: AppTextStyles.headline2.copyWith(
                    color: AuthColors.title,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'update.message'.tr(
                    namedArgs: {
                      'current': widget.requirement.currentVersion,
                      'latest': widget.requirement.storeVersion,
                    },
                  ),
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
                    onPressed: _opening ? null : _openStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuthColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _opening
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'update.cta'.tr(),
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: Text('update.exit_app'.tr()),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
