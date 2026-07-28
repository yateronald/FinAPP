import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';
import '../data/google_auth_service.dart';
import '../data/user_model.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  const AuthState(this.status, [this.user]);
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    if (kDebugMode) print('[AuthController] build() called, scheduling _bootstrap');
    Future.microtask(_bootstrap);
    return const AuthState(AuthStatus.unknown);
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _bootstrap() async {
    if (kDebugMode) print('[AuthController] _bootstrap() started');
    try {
      final token = await SecureStorage.instance.accessToken;
      if (kDebugMode) print('[AuthController] token=${token != null ? "present" : "null"}');
      if (token == null) {
        state = const AuthState(AuthStatus.unauthenticated);
        if (kDebugMode) print('[AuthController] → unauthenticated (no token)');
        return;
      }
      final user = await _repo.me();
      state = AuthState(AuthStatus.authenticated, user);
      if (kDebugMode) print('[AuthController] → authenticated as ${user.email}');
      _safeRegisterToken();
    } catch (e) {
      if (kDebugMode) print('[AuthController] _bootstrap error: $e');
      state = const AuthState(AuthStatus.unauthenticated);
      if (kDebugMode) print('[AuthController] → unauthenticated (error fallback)');
    }
  }

  void _safeRegisterToken() {
    // Respect the user's choice: only register for push if notifications are on.
    if (state.user?.settings?.notificationsEnabled == false) {
      if (kDebugMode) print('[AuthController] notifications disabled — skip token register');
      return;
    }
    // Fire-and-forget: must NEVER surface as a login failure. Catch both the
    // synchronous access (Firebase not ready) and the async future rejection.
    try {
      NotificationService.instance.registerDeviceToken().catchError((Object e) {
        if (kDebugMode) print('[AuthController] registerDeviceToken ignored (async): $e');
      });
    } catch (e) {
      if (kDebugMode) print('[AuthController] registerDeviceToken ignored (sync): $e');
    }
  }

  Future<void> login(String email, String password) async {
    final user = await _repo.login(email, password);
    state = AuthState(AuthStatus.authenticated, user);
    _safeRegisterToken();
  }

  Future<void> completeVerification(AppUser user) async {
    state = AuthState(AuthStatus.authenticated, user);
    _safeRegisterToken();
  }

  void setUser(AppUser user) {
    state = AuthState(AuthStatus.authenticated, user);
    _safeRegisterToken();
  }

  /// Re-fetches the profile from the backend (after profile/settings changes).
  Future<void> refreshUser() async {
    try {
      final user = await _repo.me();
      state = AuthState(AuthStatus.authenticated, user);
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repo.logout();
    // Clear the cached Google session too, otherwise the next sign-in silently
    // reuses the same account and switching users becomes impossible.
    await GoogleAuthService.instance.signOut();
    state = const AuthState(AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
