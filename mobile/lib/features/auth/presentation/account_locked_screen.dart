import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/responsive.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';

/// Shown when five wrong passwords have suspended sign-in.
///
/// The countdown is the honest part: the user is told exactly how long, and
/// offered the one action that actually shortens it — a password reset, which
/// clears the lock server-side.
class AccountLockedScreen extends ConsumerStatefulWidget {
  const AccountLockedScreen({
    super.key,
    required this.email,
    required this.lockedUntil,
  });

  final String email;
  final DateTime lockedUntil;

  @override
  ConsumerState<AccountLockedScreen> createState() => _AccountLockedScreenState();
}

class _AccountLockedScreenState extends ConsumerState<AccountLockedScreen> {
  Timer? _ticker;
  late Duration _left = _remaining();
  bool _sending = false;

  Duration _remaining() {
    final d = widget.lockedUntil.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = _remaining());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _hhmmss {
    final h = _left.inHours.toString().padLeft(2, '0');
    final m = _left.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _left.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _resetNow() async {
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(widget.email);
    } on ApiException catch (e) {
      if (mounted && e.code == 'OTP_RESEND_LIMIT') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.verifyResendLimit)),
        );
        setState(() => _sending = false);
        return;
      }
    } catch (_) {
      // The neutral answer is identical either way; the reset screen has its
      // own resend if nothing arrives.
    }
    if (!mounted) return;
    setState(() => _sending = false);
    context.push('/reset-password', extra: widget.email);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final unlocked = _left == Duration.zero;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuthBackdrop(
        child: SafeArea(
          child: ResponsiveCenter(
            maxWidth: 440,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AuthBrand(logoSize: 34)),
                  const SizedBox(height: 32),

                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.11),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_clock_rounded,
                        size: 36, color: AppColors.danger),
                  )
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 22),

                  Text(
                    t.accountLockTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t.accountLockBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, height: 1.5, color: context.muted),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: unlocked
                          ? AppColors.success.withValues(alpha: 0.10)
                          : AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text(
                          unlocked ? t.accountLockExpired : t.accountLockUnlocksIn,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.muted),
                        ),
                        if (!unlocked) ...[
                          const SizedBox(height: 6),
                          Text(
                            _hhmmss,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _resetNow,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Icon(Icons.lock_reset_rounded, size: 19),
                      label: Text(t.accountLockResetNow,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(t.accountLockBackToLogin),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
