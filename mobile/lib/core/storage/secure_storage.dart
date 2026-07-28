import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keychain (iOS) / EncryptedSharedPreferences (Android) backed token storage.
class SecureStorage {
  SecureStorage._();
  static final instance = SecureStorage._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kAccess = 'ft_access_token';
  static const _kRefresh = 'ft_refresh_token';
  static const _kBiometric = 'ft_biometric_enabled';
  static const _kBiometricAsked = 'ft_biometric_prompted';

  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null) await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<String?> get accessToken => _storage.read(key: _kAccess);
  Future<String?> get refreshToken => _storage.read(key: _kRefresh);

  Future<void> setBiometric(bool enabled) =>
      _storage.write(key: _kBiometric, value: enabled ? '1' : '0');
  Future<bool> get biometricEnabled async =>
      (await _storage.read(key: _kBiometric)) == '1';

  /// Whether we already offered biometric enrolment. Asked once after the
  /// first sign-in; declining is remembered so we never nag.
  Future<void> markBiometricPrompted() =>
      _storage.write(key: _kBiometricAsked, value: '1');
  Future<bool> get biometricPrompted async =>
      (await _storage.read(key: _kBiometricAsked)) == '1';

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    // Deliberately keeps the biometric preference and the "already asked"
    // flag: signing out is not a request to reconfigure device security.
  }
}
