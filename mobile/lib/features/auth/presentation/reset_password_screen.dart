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
import 'otp_code_field.dart';

/// Code + new password in one step.
///
/// One screen rather than two because the code lives three minutes: making the
/// user clear a screen transition before they can start typing the password is
/// how people run out of time and have to request another code.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const _codeLength = 6;
  static const _ttl = Duration(minutes: 3);
  static const _resendCooldown = Duration(seconds: 45);

  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _codeFocus = FocusNode();

  Timer? _ticker;
  Duration _left = _ttl;
  Duration _resendIn = _resendCooldown;

  bool _loading = false;
  bool _resending = false;
  bool _expired = false;
  bool _locked = false;
  bool _obscure = true;
  String? _error;
  String? _passwordError;
  int? _attemptsLeft;

  @override
  void initState() {
    super.initState();
    _startTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) => _codeFocus.requestFocus());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    _codeFocus.dispose();
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

  static String _mmss(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  /// Mirrors the server's rule so the user is told before a round trip.
  String? _validatePassword() {
    final p = _password.text;
    final strong = p.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(p) &&
        RegExp(r'[0-9]').hasMatch(p);
    if (!strong) return context.t.resetTooShort;
    if (p != _confirm.text) return context.t.resetMismatch;
    return null;
  }

  bool get _canSubmit =>
      _code.text.length == _codeLength &&
      _password.text.isNotEmpty &&
      _confirm.text.isNotEmpty &&
      !_loading &&
      !_expired &&
      !_locked;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final pwError = _validatePassword();
    if (pwError != null) {
      setState(() => _passwordError = pwError);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _passwordError = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(widget.email, _code.text, _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${context.t.resetDone} ${context.t.resetSessionsRevoked}'),
          behavior: SnackBarBehavior.floating,
        ));
      context.go('/login');
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
        _code.clear();
      });
      if (!_locked && !_expired) _codeFocus.requestFocus();
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
      await ref.read(authRepositoryProvider).forgotPassword(widget.email);
      if (!mounted) return;
      setState(() {
        _locked = false;
        _attemptsLeft = null;
        _code.clear();
      });
      _startTicker();
      _codeFocus.requestFocus();
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
          if (e.retryAfter != null) _resendIn = Duration(seconds: e.retryAfter!);
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
                  Row(
                    children: [
                      Material(
                        color: context.colors.surface.withValues(alpha: 0.88),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.go('/login'),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.arrow_back_rounded, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Center(child: AuthBrand(logoSize: 36)),
                  const SizedBox(height: 24),

                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded,
                        size: 30, color: AppColors.primary),
                  )
                      .animate()
                      .scale(duration: 380.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  Text(t.resetHeadline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 10),
                  Text(t.resetIntro,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5, height: 1.45, color: context.muted)),
                  const SizedBox(height: 4),
                  Text(widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const SizedBox(height: 24),

                  OtpCodeField(
                    controller: _code,
                    focusNode: _codeFocus,
                    length: _codeLength,
                    hasError: _error != null,
                    enabled: !_locked && !_expired && !_loading,
                    onChanged: (_) => setState(() => _error = null),
                    onCompleted: () => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 12),
                  _Countdown(
                    expired: _expired,
                    error: _error,
                    attemptsLeft: _attemptsLeft,
                    locked: _locked,
                    countdown: _mmss(_left),
                  ),

                  const SizedBox(height: 22),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    onChanged: (_) => setState(() => _passwordError = null),
                    decoration: InputDecoration(
                      labelText: t.resetNewPassword,
                      prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: _obscure,
                    onChanged: (_) => setState(() => _passwordError = null),
                    decoration: InputDecoration(
                      labelText: t.resetConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      errorText: _passwordError,
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(t.resetAction,
                              style: const TextStyle(
                                  fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: canResend ? _resend : null,
                      icon: _resending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2.2))
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        canResend
                            ? t.verifyResend
                            : t.verifyResendIn(_mmss(_resendIn)),
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(t.verifyCheckSpam,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: context.muted)),
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

class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.expired,
    required this.error,
    required this.attemptsLeft,
    required this.locked,
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
