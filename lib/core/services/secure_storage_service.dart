import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _secureStorage;

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userDataKey = 'user_data';
  static const String userPermissionsKey = 'user_permissions';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';
  static const String userPhoneKey = 'user_phone';
  static const String userReferralCodeKey = 'user_referral_code';
  static const String userEmailVerifiedKey = 'user_email_verified';
  static const String userPhoneVerifiedKey = 'user_phone_verified';
  static const String userTypeKey = 'user_type';

  SecureStorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  // Save methods
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: tokenKey, value: token);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _secureStorage.write(key: refreshTokenKey, value: refreshToken);
  }

  Future<void> saveUserId(String userId) async {
    await _secureStorage.write(key: userIdKey, value: userId);
  }

  Future<void> saveUserData(String userData) async {
    await _secureStorage.write(key: userDataKey, value: userData);
  }

  Future<void> saveUserPermissions(String permissions) async {
    await _secureStorage.write(key: userPermissionsKey, value: permissions);
  }

  Future<void> saveUserName(String name) async {
    await _secureStorage.write(key: userNameKey, value: name);
  }

  Future<void> saveUserEmail(String email) async {
    await _secureStorage.write(key: userEmailKey, value: email);
  }

  Future<void> saveUserPhone(String phone) async {
    await _secureStorage.write(key: userPhoneKey, value: phone);
  }

  Future<void> saveUserReferralCode(String referralCode) async {
    await _secureStorage.write(key: userReferralCodeKey, value: referralCode);
  }

  Future<void> saveUserEmailVerified(bool isVerified) async {
    await _secureStorage.write(key: userEmailVerifiedKey, value: isVerified.toString());
  }

  Future<void> saveUserPhoneVerified(bool isVerified) async {
    await _secureStorage.write(key: userPhoneVerifiedKey, value: isVerified.toString());
  }

  Future<void> saveUserType(String type) async {
    await _secureStorage.write(key: userTypeKey, value: type);
  }

  // Get methods
  Future<String?> getToken() async {
    return await _secureStorage.read(key: tokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: refreshTokenKey);
  }

  Future<String?> getUserId() async {
    return await _secureStorage.read(key: userIdKey);
  }

  Future<String?> getUserData() async {
    return await _secureStorage.read(key: userDataKey);
  }

  Future<String?> getUserPermissions() async {
    return await _secureStorage.read(key: userPermissionsKey);
  }

  Future<String?> getUserName() async {
    return await _secureStorage.read(key: userNameKey);
  }

  Future<String?> getUserEmail() async {
    return await _secureStorage.read(key: userEmailKey);
  }

  Future<String?> getUserPhone() async {
    return await _secureStorage.read(key: userPhoneKey);
  }

  Future<String?> getUserReferralCode() async {
    return await _secureStorage.read(key: userReferralCodeKey);
  }

  Future<bool> getUserEmailVerified() async {
    final value = await _secureStorage.read(key: userEmailVerifiedKey);
    return value == 'true';
  }

  Future<bool> getUserPhoneVerified() async {
    final value = await _secureStorage.read(key: userPhoneVerifiedKey);
    return value == 'true';
  }

  Future<String?> getUserType() async {
    return await _secureStorage.read(key: userTypeKey);
  }

  // Delete methods
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: tokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _secureStorage.delete(key: refreshTokenKey);
  }

  Future<void> deleteUserId() async {
    await _secureStorage.delete(key: userIdKey);
  }

  Future<void> deleteUserData() async {
    await _secureStorage.delete(key: userDataKey);
  }

  Future<void> deleteUserPermissions() async {
    await _secureStorage.delete(key: userPermissionsKey);
  }

  Future<void> deleteUserName() async {
    await _secureStorage.delete(key: userNameKey);
  }

  Future<void> deleteUserEmail() async {
    await _secureStorage.delete(key: userEmailKey);
  }

  Future<void> deleteUserPhone() async {
    await _secureStorage.delete(key: userPhoneKey);
  }

  Future<void> deleteUserReferralCode() async {
    await _secureStorage.delete(key: userReferralCodeKey);
  }

  Future<void> deleteUserEmailVerified() async {
    await _secureStorage.delete(key: userEmailVerifiedKey);
  }

  Future<void> deleteUserPhoneVerified() async {
    await _secureStorage.delete(key: userPhoneVerifiedKey);
  }

  Future<void> deleteUserType() async {
    await _secureStorage.delete(key: userTypeKey);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }

  // Check if token exists
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}