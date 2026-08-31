import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/biometric_credential_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';

/// Profile toggle to enable or disable biometric login.
class BiometricLoginToggle extends StatefulWidget {
  const BiometricLoginToggle({super.key});

  @override
  State<BiometricLoginToggle> createState() => _BiometricLoginToggleState();
}

class _BiometricLoginToggleState extends State<BiometricLoginToggle> {
  bool _loading = true;
  bool _visible = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bio = getIt<BiometricCredentialService>();
    if (kIsWeb || !await bio.isDeviceSupported()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final enabled = await bio.isBiometricLoginEnabled();
    if (mounted) {
      setState(() {
        _visible = true;
        _enabled = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _onChanged(bool value) async {
    final bio = getIt<BiometricCredentialService>();

    if (!value) {
      await bio.optOut();
      if (mounted) setState(() => _enabled = false);
      return;
    }

    final authenticated = await bio.authenticate(
      localizedReason: 'auth.biometric_auth_reason'.tr(),
    );
    if (!authenticated) return;

    if (await bio.hasCredentialBlob()) {
      await bio.enableBiometricLogin();
      if (mounted) setState(() => _enabled = true);
      return;
    }

    if (!mounted) return;
    final password = await _promptForPassword();
    if (password == null || password.isEmpty) return;

    final storage = getIt<SecureStorageService>();
    final email = await storage.getUserEmail();
    final phone = await storage.getUserPhone();
    String? identifier;
    String fieldType = 'email';
    if (email != null && email.isNotEmpty) {
      identifier = email;
      fieldType = 'email';
    } else if (phone != null && phone.isNotEmpty) {
      identifier = EthiopianPhoneNumber.tryNormalize(phone) ?? phone;
      fieldType = 'phone';
    }

    if (identifier == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('auth.biometric_enable_requires_login'.tr()),
          ),
        );
      }
      return;
    }

    await bio.saveCredentials(identifier, password, fieldType);
    await bio.setRememberMeEnabled(true);
    await bio.enableBiometricLogin();
    if (mounted) setState(() => _enabled = true);
  }

  Future<String?> _promptForPassword() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('auth.biometric_enter_password_title'.tr()),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'auth.password'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_visible) return const SizedBox.shrink();

    return SwitchListTile(
      secondary: Icon(
        _enabled ? Icons.fingerprint : Icons.fingerprint_outlined,
      ),
      title: Text('auth.settings_biometric_login'.tr()),
      value: _enabled,
      onChanged: _onChanged,
    );
  }
}
