import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    // Safety timeout: if auth never resolves, navigate away after 8 seconds
    _timeout = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      final auth = ref.read(authProvider).status;
      if (auth == AuthStatus.unknown) {
        // Auth bootstrap failed silently — go to login
        _navigateToLogin();
      }
    });
  }

  Future<void> _navigateToLogin() async {
    final onboarded = await AppPrefs.instance.onboarded;
    if (mounted) {
      context.go(onboarded ? '/login' : '/onboarding');
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? [const Color(0xFF141B2E), const Color(0xFF0B1120)]
                : [const Color(0xFFEFEEFB), Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 118, showText: false)
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: 20),
              Text(
                'Fynexa',
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              Text(
                'Gérez. Épargnez. Atteignez vos objectifs.',
                style: TextStyle(
                    color: (dark ? Colors.white : const Color(0xFF64748B))
                        .withValues(alpha: 0.85),
                    fontSize: 14),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 40),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
