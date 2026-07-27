import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/auth_provider.dart';

/// Wraps the app and, when biometric unlock is enabled, requires authentication
/// on launch and whenever the app returns to the foreground — even though the
/// session itself stays valid for months. This is the app-access gate.
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  /// True once the user has passed biometric auth for the current foreground.
  bool _authedThisForeground = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Require auth again next time the app comes to the foreground.
      _authedThisForeground = false;
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: context.t.unlockReason,
        persistAcrossBackgrounding: true,
      );
      if (ok && mounted) {
        setState(() => _authedThisForeground = true);
      }
    } catch (_) {
      // Leave locked; the user can retry with the button.
    } finally {
      _authenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(biometricEnabledProvider);
    final authed = ref.watch(authProvider).status == AuthStatus.authenticated;
    final locked = enabled && authed && !_authedThisForeground;

    if (locked && !_authenticating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }

    return Stack(
      children: [
        widget.child,
        if (locked)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    const BrandLogo(size: 72, textColor: Colors.white),
                    const SizedBox(height: 40),
                    const Icon(Icons.lock_rounded, color: Colors.white70, size: 40),
                    const SizedBox(height: 12),
                    Text(context.t.lockTitle,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(context.t.lockSubtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          onPressed: _authenticate,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text(context.t.unlock),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
