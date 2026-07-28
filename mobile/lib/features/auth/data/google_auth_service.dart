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
        // The picker succeeded but Google withheld the token. That means the
        // OAuth clients are wrong — almost always a missing ANDROID client for
        // this package + signing certificate.
        throw const GoogleAuthMisconfigured('no ID token returned');
      }
      return GoogleIdentity(
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (e) {
      if (kDebugMode) {
        print('[GoogleAuth] ${e.code.name}: ${e.description} ${e.details ?? ''}');
      }
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          // Genuinely dismissed by the user — say nothing.
          //
          // Caveat: Android also surfaces some configuration failures as a
          // cancellation, which is why a misconfigured app "does nothing" on
          // tap. `description` is the only way to tell them apart.
          final d = (e.description ?? '').toLowerCase();
          if (d.contains('credential') || d.contains('10:') || d.contains('developer')) {
            throw GoogleAuthMisconfigured(e.description ?? e.code.name);
          }
          return null;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw GoogleAuthMisconfigured(e.description ?? e.code.name);
        case GoogleSignInExceptionCode.uiUnavailable:
          throw const GoogleAuthUnavailable();
        default:
          throw GoogleAuthMisconfigured('${e.code.name}: ${e.description ?? ''}');
      }
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

/// Google Play Services is missing or cannot show its UI on this device.
class GoogleAuthUnavailable implements Exception {
  const GoogleAuthUnavailable();
}

/// Sign-in reached Google but the OAuth clients are wrong for this build —
/// typically no ANDROID client registered for this package + SHA-1, or a
/// `serverClientId` from a different project.
///
/// Surfaced rather than swallowed: Android reports this as a cancellation, so
/// treating it as one makes the button appear to do nothing at all.
class GoogleAuthMisconfigured implements Exception {
  final String detail;
  const GoogleAuthMisconfigured(this.detail);
  @override
  String toString() => 'GoogleAuthMisconfigured: $detail';
}
