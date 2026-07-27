import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'user_model.dart';

class AuthRepository {
  final _api = ApiClient.instance;

  Future<AppUser> login(String email, String password) async {
    final data = await _api.post('/auth/login',
        body: {'email': email, 'password': password}, auth: false);
    await SecureStorage.instance.saveTokens(
      access: data['accessToken'],
      refresh: data['refreshToken'],
    );
    return AppUser.fromJson(Map<String, dynamic>.from(data['user']));
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String language = 'FR',
    String? country,
    String? currency,
  }) async {
    final data = await _api.post('/auth/register', body: {
      'email': email,
      'password': password,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      'language': language,
      if (country != null && country.isNotEmpty) 'country': country,
      if (currency != null && currency.isNotEmpty) 'currency': currency,
    }, auth: false);
    return Map<String, dynamic>.from(data);
  }

  Future<AppUser> verifyEmail(String email, String code) async {
    final data = await _api
        .post('/auth/verify-email', body: {'email': email, 'code': code}, auth: false);
    await SecureStorage.instance.saveTokens(
      access: data['accessToken'],
      refresh: data['refreshToken'],
    );
    return AppUser.fromJson(Map<String, dynamic>.from(data['user']));
  }

  Future<void> resendOtp(String email) =>
      _api.post('/auth/resend-otp', body: {'email': email}, auth: false);

  Future<void> forgotPassword(String email) =>
      _api.post('/auth/forgot-password', body: {'email': email}, auth: false);

  Future<AppUser> me() async {
    final data = await _api.get('/users/me');
    return AppUser.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await SecureStorage.instance.clear();
  }
}
