import '../../../core/network/api_client.dart';

class SettingsRepository {
  final _api = ApiClient.instance;

  Future<void> updateSettings(Map<String, dynamic> patch) async {
    await _api.patch('/settings', body: patch);
  }

  Future<void> updateProfile({String? firstName, String? lastName}) async {
    await _api.patch('/users/me', body: {
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
    });
  }

  /// Changes the password, or sets the first one.
  ///
  /// Google-created accounts have no password to confirm, so
  /// [currentPassword] is omitted entirely rather than sent empty — the
  /// backend distinguishes the two cases.
  Future<void> changePassword(String? currentPassword, String newPassword) async {
    await _api.post('/auth/change-password', body: {
      if (currentPassword != null && currentPassword.isNotEmpty)
        'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
