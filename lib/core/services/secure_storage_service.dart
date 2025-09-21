import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _secureStorage;

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userDataKey = 'user_data';

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