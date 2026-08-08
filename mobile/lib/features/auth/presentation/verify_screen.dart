import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Confirms ownership of the sign-up address.
///
/// The rules are the server's, mirrored here only so the user can see them:
/// a code lives 3 minutes, survives 3 wrong guesses, and may be re-sent 3
/// times an hour. Every one of those limits is enforced again server-side —
/// nothing here is a security control, it is feedback.
class VerifyScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  static const _codeLength = 6;
  static const _ttl = Duration(minutes: 3);
  /// Matches the server's cool-down between explicit resends.
  static const _resendCooldown = Duration(seconds: 45);

  final _controller = TextEditingController();
  final _focus = FocusNode();

  Timer? _ticker;
  Duration _left = _ttl;
  Duration _resendIn = _resendCooldown;

  bool _loading = false;
  bool _resending = false;
  bool _expired = false;
  bool _locked = false;
  String? _error;
  int? _attemptsLeft;
  int? _resendsLeft;

  String get _code => _controller.text;

  @override
  void initState() {
    super.initState();
    _startTicker();
    // The field is the whole point of the screen; open the keyboard on arrival.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _left = _ttl;
    _resendIn = _resendCooldown;
    _expired = false;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_left.inSeconds > 0) {
          _left -= const Duration(seconds: 1);
          if (_left.inSeconds == 0) _expired = true;
        }
        if (_resendIn.inSeconds > 0) _resendIn -= const Duration(seconds: 1);
      });
    });
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canSubmit =>
      _code.length == _codeLength && !_loading && !_expired && !_locked;

  Future<void> _verify() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user =
          await ref.read(authRepositoryProvider).verifyEmail(widget.email, _code);
      ref.read(authProvider.notifier).completeVerification(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(context.t.verifySuccess),
          behavior: SnackBarBehavior.floating,
        ));
      context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _attemptsLeft = e.attemptsLeft;
        switch (e.code) {
          case 'OTP_LOCKED':
            _locked = true;
            _error = context.t.verifyLocked;
            break;
          case 'OTP_EXPIRED':
            _expired = true;
            _error = context.t.verifyExpired;
            break;
          case 'OTP_NONE':
            _error = context.t.verifyNoCode;
            break;
          default:
            _error = context.t.verifyWrongCode;
        }
        _controller.clear();
      });
      // A wrong code is a dead end until it changes — put the cursor back.
      if (!_locked && !_expired) _focus.requestFocus();
    } catch (_) {
      if (mounted) setState(() => _error = context.t.genericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendIn.inSeconds > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final res = await ref.read(authRepositoryProvider).resendOtp(widget.email);
      if (!mounted) return;
      setState(() {
        _locked = false;
        _attemptsLeft = null;
        _resendsLeft = res;
        _controller.clear();
      });
      _startTicker();
      _focus.requestFocus();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(context.t.verifyCodeSent),
          behavior: SnackBarBehavior.floating,
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'OTP_RESEND_LIMIT') {
          _error = context.t.verifyResendLimit;
          // Hold the button for as long as the server says.
          if (e.retryAfter != null) {
            _resendIn = Duration(seconds: e.retryAfter!);
          }
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final canResend = _resendIn.inSeconds == 0 && !_resending;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuthBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ResponsiveCenter(
              maxWidth: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(onBack: () => context.go('/login')),
                  const SizedBox(height: 10),
                  const Center(child: AuthBrand(logoSize: 36)),
                  const SizedBox(height: 26),

                  _Header(email: widget.email),
                  const SizedBox(height: 24),

                  _CodeField(
                    controller: _controller,
                    focusNode: _focus,
                    length: _codeLength,
                    hasError: _error != null,
                    enabled: !_locked && !_expired && !_loading,
                    onChanged: (_) => setState(() => _error = null),
                    onCompleted: _verify,
                  ),

                  const SizedBox(height: 14),
                  _StatusLine(
                    expired: _expired,
                    locked: _locked,
                    error: _error,
                    attemptsLeft: _attemptsLeft,
                    countdown: _mmss(_left),
                  ),

                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _canSubmit ? _verify : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(t.verify,
                              style: const TextStyle(
                                  fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _ResendRow(
                    canResend: canResend,
                    busy: _resending,
                    countdown: _mmss(_resendIn),
                    resendsLeft: _resendsLeft,
                    onResend: _resend,
                  ),

                  const SizedBox(height: 22),
                  Center(
                    child: Column(
                      children: [
                        Text(t.verifyCheckSpam,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: context.muted)),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(t.verifyChangeAccount,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
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

// ────────────────────────────────────────────────────────────── pieces

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: context.colors.surface.withValues(alpha: 0.88),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              size: 29, color: AppColors.primary),
        ).animate().scale(duration: 380.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 16),
        Text(
          t.verifyHeadline,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 23, fontWeight: FontWeight.w800, height: 1.2),
        ),
        const SizedBox(height: 10),
        Text(
          t.verifyIntro,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.45, color: context.muted),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
      ],
    );
  }
}

/// Six boxes over one hidden field: the OS keeps autofill and SMS/e-mail code
/// suggestions working, which per-box TextFields break.
class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError, enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofillHints: const [AutofillHints.oneTimeCode],
              keyboardType: TextInputType.number,
              maxLength: length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                onChanged(v);
                if (v.length == length) onCompleted();
              },
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
        ),
        GestureDetector(
          onTap: enabled ? focusNode.requestFocus : null,
          behavior: HitTestBehavior.opaque,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final code = value.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(length, (i) {
                  final filled = i < code.length;
                  final active = i == code.length && focusNode.hasFocus;
                  final border = hasError
                      ? AppColors.danger
                      : active
                          ? AppColors.primary
                          : filled
                              ? AppColors.primary.withValues(alpha: 0.45)
                              : context.borderColor;
                  return Padding(
                    padding: EdgeInsets.only(right: i == length - 1 ? 0 : 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: enabled
                            ? context.colors.surface
                            : context.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border, width: active ? 1.8 : 1.3),
                      ),
                      child: Text(
                        filled ? code[i] : '',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: hasError ? AppColors.danger : context.colors.onSurface,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.expired,
    required this.locked,
    required this.error,
    required this.attemptsLeft,
    required this.countdown,
  });

  final bool expired, locked;
  final String? error;
  final int? attemptsLeft;
  final String countdown;

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    if (error != null) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: 7),
              Flexible(
                child: Text(error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.danger, height: 1.35)),
              ),
            ],
          ),
          if (attemptsLeft != null && attemptsLeft! > 0 && !locked) ...[
            const SizedBox(height: 6),
            Text(t.verifyAttemptsLeft(attemptsLeft!),
                style: TextStyle(fontSize: 11.5, color: context.muted)),
          ],
        ],
      );
    }

    if (expired) {
      return Text(t.verifyExpired,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.danger));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.schedule_rounded, size: 15, color: context.muted),
        const SizedBox(width: 6),
        Text(t.verifyExpiresIn(countdown),
            style: TextStyle(fontSize: 12.5, color: context.muted)),
      ],
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.canResend,
    required this.busy,
    required this.countdown,
    required this.resendsLeft,
    required this.onResend,
  });

  final bool canResend, busy;
  final String countdown;
  final int? resendsLeft;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: canResend ? onResend : null,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              canResend ? t.verifyResend : t.verifyResendIn(countdown),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (resendsLeft != null && resendsLeft! > 0) ...[
          const SizedBox(height: 8),
          Text(t.verifyResendsLeft(resendsLeft!),
              style: TextStyle(fontSize: 11.5, color: context.muted)),
        ],
      ],
    );
  }
}
