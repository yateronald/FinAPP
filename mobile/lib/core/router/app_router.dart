import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/verify_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../i18n/app_text.dart';
import '../storage/app_prefs.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(() => listenable.dispose());
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) =>
            ResetPasswordScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/verify',
        builder: (_, state) => VerifyScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/home', builder: (_, __) => const MainShell()),
      GoRoute(
        path: '/settings',
        builder: (context, __) => Scaffold(
          appBar: AppBar(title: Text(context.t.settings)),
          body: const SettingsScreen(),
        ),
      ),
    ],
    redirect: (context, state) async {
      final auth = ref.read(authProvider).status;
      final loc = state.matchedLocation;
      if (kDebugMode) print('[Router] redirect: loc=$loc auth=$auth');

      if (loc == '/splash') {
        if (auth == AuthStatus.unknown) return null; // wait
        if (auth == AuthStatus.authenticated) return '/home';
        final onboarded = await AppPrefs.instance.onboarded;
        final target = onboarded ? '/login' : '/onboarding';
        if (kDebugMode) print('[Router] splash → $target');
        return target;
      }

      final authRoutes = {'/login', '/register', '/verify', '/onboarding'};
      if (auth == AuthStatus.authenticated && authRoutes.contains(loc)) return '/home';
      if (auth == AuthStatus.unauthenticated && loc == '/home') return '/login';
      return null;
    },
    refreshListenable: listenable,
  );
});

class _AuthListenable extends ChangeNotifier {
  late final ProviderSubscription _sub;
  _AuthListenable(Ref ref) {
    _sub = ref.listen(authProvider, (prev, next) {
      if (kDebugMode) print('[_AuthListenable] auth changed: ${prev?.status} → ${next.status}');
      notifyListeners();
    });
  }
  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

