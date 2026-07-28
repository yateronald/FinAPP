import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper over `google_sign_in` 7.x.
///
/// The plugin returns an ID token on-device; the backend verifies it at
/// `POST /auth/google/token`. No browser redirect is involved, which is why
/// this differs from the web flow.
class GoogleAuthService {
  GoogleAuthService._();
  static final instance = GoogleAuthService._();

  /// The WEB OAuth client of project `fintrack-9818a`. Passing it as
  /// `serverClientId` makes Google mint an ID token whose `aud` is this value,
  /// which is exactly what the backend validates against. Using the Android
  /// client id here instead would produce a token the server rejects.
  static const _serverClientId =
      '939949089938-j3b1dt0ccm8a4pcv45f4i7sok4btdcmt.apps.googleusercontent.com';

  bool _initialised = false;

  Future<void> _ensureInitialised() async {
    if (_initialised) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _initialised = true;
  }

  /// Runs the native account picker and returns a fresh ID token.
  ///
  /// Returns null when the user dismisses the picker — a cancellation is not
  /// an error and must not surface as one.
  Future<GoogleIdentity?> signIn() async {
    await _ensureInitialised();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleAuthUnavailable();
    }

    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        // Almost always a misconfigured serverClientId or a missing SHA-1.
        throw const GoogleAuthUnavailable();
      }
      return GoogleIdentity(
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      if (kDebugMode) print('[GoogleAuth] ${e.code}: ${e.description}');
      rethrow;
    }
  }

  /// Clears the cached Google session so the next sign-in shows the picker
  /// again. Called on logout so switching accounts is possible.
  Future<void> signOut() async {
    if (!_initialised) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Never let this block signing out of the app itself.
    }
  }
}

class GoogleIdentity {
  final String idToken;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const GoogleIdentity({
    required this.idToken,
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}

/// Google Play Services missing, or the OAuth client is not configured for
/// this build's signing certificate.
class GoogleAuthUnavailable implements Exception {
  const GoogleAuthUnavailable();
}
