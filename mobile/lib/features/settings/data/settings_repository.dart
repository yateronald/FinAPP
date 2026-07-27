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

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.post('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
