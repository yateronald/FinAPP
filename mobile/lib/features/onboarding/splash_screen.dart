import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_colors.dart';
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
    // Deliberately light in both themes: the launch artwork carries a navy
    // wordmark that would disappear on the dark palette, and the native first
    // frame is white — keeping this light makes the hand-over seamless instead
    // of flashing white then dark.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFEEFB), Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mark + wordmark in one asset — no separate "Fynexa" text,
              // which would double it up.
              Image.asset(
                'img/logo_launch.png',
                width: 190,
                filterQuality: FilterQuality.high,
              )
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: 22),
              Text(
                'Gérez. Épargnez. Atteignez vos objectifs.',
                style: TextStyle(
                  color: const Color(0xFF64748B).withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 40),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}
