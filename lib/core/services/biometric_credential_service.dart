import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class StoredCredentials {
  const StoredCredentials({
    required this.identifier,
    required this.password,
    required this.fieldType,
  });

  final String identifier;
  final String password;
  final String fieldType;
}

/// Stores login credentials in OS secure storage, bound to the current device.
/// Supports remember-me pre-fill and biometric unlock.
class BiometricCredentialService {
  BiometricCredentialService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
    DeviceInfoPlugin? deviceInfo,
  })  : _storage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            ),
        _localAuth = localAuth ?? LocalAuthentication(),
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  static const _blobKey = 'biometric_credentials_blob';
  static const _enabledKey = 'biometric_login_enabled';
  static const _optOutKey = 'biometric_user_opted_out';
  static const _rememberMeKey = 'remember_me_enabled';
  static const _schemaVersion = 1;

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;
  final DeviceInfoPlugin _deviceInfo;

  // --- Capability checks ---

  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> prefersFaceIcon() async {
    final types = await getAvailableBiometrics();
    return types.contains(BiometricType.face);
  }

  Future<bool> authenticate({required String localizedReason}) async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canCheck && !supported) return false;

      final biometrics = await _localAuth.getAvailableBiometrics();
      if (biometrics.isEmpty) return false;

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e, st) {
      debugPrint('BiometricCredentialService.authenticate failed: $e\n$st');
      return false;
    }
  }

  // --- Remember me ---

  Future<bool> isRememberMeEnabled() async {
    return (await _storage.read(key: _rememberMeKey)) == 'true';
  }

  Future<void> setRememberMeEnabled(bool enabled) async {
    await _storage.write(
      key: _rememberMeKey,
      value: enabled.toString(),
    );
  }

  // --- Credential lifecycle ---

  Future<void> saveCredentials(
    String identifier,
    String password,
    String fieldType,
  ) async {
    final fingerprint = await _deviceFingerprint();
    final blob = jsonEncode({
      'schemaVersion': _schemaVersion,
      'identifier': identifier,
      'password': password,
      'fieldType': fieldType,
      'deviceFingerprint': fingerprint,
    });
    await _storage.write(key: _blobKey, value: blob);
  }

  Future<StoredCredentials?> peekCredentials() async {
    return _readBlob(requireBiometricEnabled: false);
  }

  Future<StoredCredentials?> readCredentials() async {
    final enabled = (await _storage.read(key: _enabledKey)) == 'true';
    if (!enabled) return null;
    return _readBlob(requireBiometricEnabled: true);
  }

  Future<bool> hasCredentialBlob() async {
    final creds = await _readBlob(requireBiometricEnabled: false);
    return creds != null;
  }

  Future<bool> matchesStoredLoginIdentifier(
    String attempted, {
    String? fieldType,
  }) async {
    final creds = await _readBlob(requireBiometricEnabled: false);
    if (creds == null) return false;

    final type = fieldType ?? creds.fieldType;
    if (type == 'email') {
      return attempted.trim().toLowerCase() ==
          creds.identifier.toLowerCase();
    }
    final attemptDigits = attempted.replaceAll(RegExp(r'\D'), '');
    final storedDigits = creds.identifier.replaceAll(RegExp(r'\D'), '');
    return attemptDigits == storedDigits;
  }

  // --- Biometric enable / disable ---

  Future<void> enableBiometricLogin() async {
    if (!await hasCredentialBlob()) return;
    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.delete(key: _optOutKey);
  }

  Future<void> optOut() => disableBiometricLogin();

  Future<void> disableBiometricLogin() async {
    await _storage.write(key: _enabledKey, value: 'false');
    await _storage.write(key: _optOutKey, value: 'true');
  }

  Future<bool> hasEnabledSession() async {
    if (kIsWeb) return false;
    final enabled = (await _storage.read(key: _enabledKey)) == 'true';
    if (!enabled) return false;
    return hasCredentialBlob();
  }

  Future<bool> shouldOfferOptIn() async {
    if (kIsWeb) return false;
    if (!await isDeviceSupported()) return false;
    if (!await hasCredentialBlob()) return false;
    if ((await _storage.read(key: _enabledKey)) == 'true') return false;
    if ((await _storage.read(key: _optOutKey)) == 'true') return false;
    return true;
  }

  Future<bool> isBiometricLoginEnabled() async {
    return (await _storage.read(key: _enabledKey)) == 'true';
  }

  // --- Clear / wipe ---

  Future<void> clearCredentials() async {
    await _storage.delete(key: _blobKey);
  }

  Future<void> clearSessionKeepOptOut() async {
    await _storage.delete(key: _blobKey);
    await _storage.write(key: _enabledKey, value: 'false');
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _blobKey);
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _optOutKey);
    await _storage.delete(key: _rememberMeKey);
  }

  Future<void> clearRememberedLogin() => clearAll();

  // --- Internal ---

  Future<StoredCredentials?> _readBlob({required bool requireBiometricEnabled}) async {
    final raw = await _storage.read(key: _blobKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final storedFingerprint = map['deviceFingerprint'] as String?;
      final currentFingerprint = await _deviceFingerprint();
      if (storedFingerprint != currentFingerprint) {
        await clearCredentials();
        return null;
      }

      if (requireBiometricEnabled) {
        final enabled = (await _storage.read(key: _enabledKey)) == 'true';
        if (!enabled) return null;
      }

      return StoredCredentials(
        identifier: map['identifier'] as String,
        password: map['password'] as String,
        fieldType: map['fieldType'] as String? ?? 'email',
      );
    } catch (_) {
      await clearCredentials();
      return null;
    }
  }

  Future<String> _deviceFingerprint() async {
    try {
      if (kIsWeb) return 'unknown:web';
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return 'android:${info.id}';
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return 'ios:${info.identifierForVendor}';
      }
      return 'unknown:${Platform.operatingSystem}';
    } catch (_) {
      return 'unknown:${Platform.operatingSystem}';
    }
  }
}
