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
    required bool acceptedTerms,
  }) async {
    final data = await _api.post('/auth/register', body: {
      'email': email,
      'password': password,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      'language': language,
      if (country != null && country.isNotEmpty) 'country': country,
      if (currency != null && currency.isNotEmpty) 'currency': currency,
      // Recorded server-side with the document versions in force.
      'acceptedTerms': acceptedTerms,
    }, auth: false);
    final map = Map<String, dynamic>.from(data);
    // When the server has no mail configured it skips the OTP and hands back a
    // session directly — persist it so the app can go straight in.
    if (map['requiresVerification'] == false && map['accessToken'] != null) {
      await SecureStorage.instance.saveTokens(
        access: map['accessToken'],
        refresh: map['refreshToken'],
      );
    }
    return map;
  }

  /// Exchanges a Google ID token for a Fynexa session.
  ///
  /// [intent] must match what the user pressed: `signin` fails when no account
  /// exists, `signup` fails when one already does. The backend reports those
  /// as ACCOUNT_NOT_FOUND / ACCOUNT_EXISTS so the UI can explain what to do.
  Future<AppUser> googleAuth({
    required String idToken,
    required String intent,
  }) async {
    final data = await _api.post('/auth/google/token',
        body: {'idToken': idToken, 'intent': intent}, auth: false);
    await SecureStorage.instance.saveTokens(
      access: data['accessToken'],
      refresh: data['refreshToken'],
    );
    return AppUser.fromJson(Map<String, dynamic>.from(data['user']));
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

  /// Returns how many resends remain in the current hour, when the server
  /// says — null when it does not (e.g. the address has no pending account,
  /// which the response deliberately does not reveal).
  Future<int?> resendOtp(String email) async {
    final data =
        await _api.post('/auth/resend-otp', body: {'email': email}, auth: false);
    if (data is Map && data['resendsLeft'] != null) {
      return (data['resendsLeft'] as num).toInt();
    }
    return null;
  }

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
