import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/settings_repository.dart';

final settingsRepositoryProvider = Provider((_) => SettingsRepository());

/// Human label for the device's biometric method (Face ID vs fingerprint).
final biometricLabelProvider = FutureProvider<String>((_) async {
  try {
    final types = await LocalAuthentication().getAvailableBiometrics();
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.iris)) return 'Reconnaissance de l\'iris';
    if (types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong)) {
      return 'Empreinte digitale';
    }
  } catch (_) {}
  return 'Biométrie';
});

/// Whether biometric unlock is enabled (persisted in secure storage).
final biometricEnabledProvider = NotifierProvider<BiometricController, bool>(
  BiometricController.new,
);

class BiometricController extends Notifier<bool> {
  @override
  bool build() {
    Future.microtask(_load);
    return false;
  }
  Future<void> _load() async {
    state = await SecureStorage.instance.biometricEnabled;
  }

  Future<void> set(bool value) async {
    await SecureStorage.instance.setBiometric(value);
    state = value;
  }
}
