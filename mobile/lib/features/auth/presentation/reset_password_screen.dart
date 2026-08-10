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
import 'forgot_password_dialog.dart';
import 'otp_code_field.dart';

/// Code + new password in one step.
///
/// One screen rather than two because the code lives three minutes: making the
/// user clear a screen transition before they can start typing the password is
/// how people run out of time and have to request another code.
///
/// Everything is sized from the available height so the whole form fits
/// without scrolling — on a short phone it tightens, on a tablet it breathes,
/// and the illustration is the first thing to give up space because it is the
/// only element carrying no information.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const _codeLength = 6;
  static const _ttl = Duration(minutes: 3);
  static const _resendCooldown = Duration(seconds: 45);

  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _codeFocus = FocusNode();

  late String _email = widget.email;

  Timer? _ticker;
  Duration _left = _ttl;
  Duration _resendIn = _resendCooldown;

  bool _loading = false;
  bool _resending = false;
  bool _expired = false;
  bool _locked = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _passwordError;
  int? _attemptsLeft;

  @override
  void initState() {
    super.initState();
    _startTicker();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _codeFocus.requestFocus(),
    );
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

  /// 0–3, mirroring the server's rule: length, case mix, digit, symbol.
  int get _strength {
    final p = _password.text;
    if (p.isEmpty) return 0;
    var score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p) && RegExp(r'[^A-Za-z0-9]').hasMatch(p))
      score++;
    return score;
  }

  bool get _meetsPolicy =>
      _password.text.length >= 8 &&
      RegExp(r'[a-z]').hasMatch(_password.text) &&
      RegExp(r'[A-Z]').hasMatch(_password.text) &&
      RegExp(r'\d').hasMatch(_password.text) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(_password.text);

  bool get _confirmMatches =>
      _confirm.text.isNotEmpty && _confirm.text == _password.text;

  bool get _canSubmit =>
      _code.text.length == _codeLength &&
      _meetsPolicy &&
      _confirmMatches &&
      !_loading &&
      !_expired &&
      !_locked;

  Future<void> _changeEmail() async {
    // The dialog sends the new code itself and only resolves once it is away,
    // so this screen retargets against a request that has already happened —
    // no second send, and no silent gap after the dialog closes.
    final next = await showForgotPasswordDialog(
      context,
      initialEmail: _email,
      onSubmit: (address) => sendResetCode(
        () => ref.read(authRepositoryProvider).forgotPassword(address),
      ),
    );
    if (next == null || next.isEmpty || next == _email) return;
    if (!mounted) return;
    setState(() {
      _email = next;
      _code.clear();
      _error = null;
      _locked = false;
      _attemptsLeft = null;
    });
    _startTicker();
    _codeFocus.requestFocus();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _passwordError = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(_email, _code.text, _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${context.t.resetDone} ${context.t.resetSessionsRevoked}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
            // A 400 with no OTP code is the server's password policy talking.
            if (e.statusCode == 400 && e.code == null) {
              _passwordError = e.message;
            } else {
              _error = context.t.verifyWrongCode;
              _code.clear();
            }
        }
      });
      if (!_locked && !_expired && _passwordError == null) {
        _codeFocus.requestFocus();
      }
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
      await ref.read(authRepositoryProvider).forgotPassword(_email);
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
        ..showSnackBar(
          SnackBar(
            content: Text(context.t.verifyCodeSent),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'OTP_RESEND_LIMIT') {
          _error = context.t.verifyResendLimit;
          if (e.retryAfter != null)
            _resendIn = Duration(seconds: e.retryAfter!);
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
          child: LayoutBuilder(
            builder: (context, c) {
              // Three density steps rather than a continuous scale: predictable,
              // and each step was checked against a real viewport height.
              final h = c.maxHeight;
              final tight = h < 700;
              final roomy = h >= 860;

              final gap = tight ? 7.0 : (roomy ? 14.0 : 8.0);
              final heroSize = tight ? 70.0 : (roomy ? 116.0 : 78.0);
              final titleSize = tight ? 20.0 : (roomy ? 26.0 : 22.0);

              return ResponsiveCenter(
                maxWidth: 480,
                child: SingleChildScrollView(
                  // Scrolls only as a safety valve: with minHeight equal to the
                  // viewport the Spacer below absorbs the slack, so on a normal
                  // screen there is nothing to scroll.
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: h),
                    // Gives the Column a finite height so the Spacer can
                    // distribute the slack; under a scroll view alone it would
                    // have nothing to expand into.
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          tight ? 4 : 10,
                          20,
                          tight ? 8 : 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TopRow(onBack: () => context.go('/login')),
                            SizedBox(height: gap * 0.6),

                            // The illustration yields first when height is scarce:
                            // it is the only element that carries no information.
                            if (h > 700)
                              Image.asset(
                                    'img/reset_hero.png',
                                    height: heroSize,
                                    filterQuality: FilterQuality.high,
                                  )
                                  .animate()
                                  .fadeIn(duration: 320.ms)
                                  .scale(
                                    begin: const Offset(0.94, 0.94),
                                    duration: 380.ms,
                                  ),
                            SizedBox(height: gap * 0.7),

                            Text(
                              t.resetHeadline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: -0.4,
                              ),
                            ),
                            SizedBox(height: gap * 0.45),
                            Text(
                              t.resetIntro,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: tight ? 12.5 : 13.5,
                                height: 1.4,
                                color: context.muted,
                              ),
                            ),
                            SizedBox(height: gap * 0.75),

                            Center(
                              child: _EmailChip(
                                email: _email,
                                onChange: _changeEmail,
                              ),
                            ),
                            SizedBox(height: gap),

                            _Label(t.resetCodeLabel),
                            SizedBox(height: gap * 0.5),
                            OtpCodeField(
                              controller: _code,
                              focusNode: _codeFocus,
                              length: _codeLength,
                              hasError: _error != null,
                              enabled: !_locked && !_expired && !_loading,
                              onChanged: (_) => setState(() => _error = null),
                              onCompleted: () =>
                                  FocusScope.of(context).nextFocus(),
                            ),
                            SizedBox(height: gap * 0.55),
                            _CodeStatus(
                              expired: _expired,
                              locked: _locked,
                              error: _error,
                              attemptsLeft: _attemptsLeft,
                              countdown: _mmss(_left),
                            ),
                            SizedBox(height: gap),

                            _Label(t.resetNewPassword),
                            SizedBox(height: gap * 0.45),
                            _PasswordField(
                              controller: _password,
                              obscure: _obscure,
                              onToggle: () =>
                                  setState(() => _obscure = !_obscure),
                              onChanged: (_) =>
                                  setState(() => _passwordError = null),
                              errorText: _passwordError,
                            ),
                            SizedBox(height: gap * 0.5),
                            _StrengthMeter(level: _strength),
                            SizedBox(height: gap * 0.4),
                            Text(
                              t.resetRules,
                              style: TextStyle(
                                fontSize: tight ? 10.5 : 11.5,
                                height: 1.4,
                                color: context.muted,
                              ),
                            ),
                            SizedBox(height: gap * 0.85),

                            _Label(t.resetConfirmPassword),
                            SizedBox(height: gap * 0.45),
                            Row(
                              children: [
                                Expanded(
                                  child: _PasswordField(
                                    controller: _confirm,
                                    obscure: _obscureConfirm,
                                    onToggle: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    matched: _confirmMatches,
                                  ),
                                ),
                                if (_confirm.text.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Icon(
                                    _confirmMatches
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    size: 20,
                                    color: _confirmMatches
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ],
                              ],
                            ),

                            // Absorbs whatever height is left, so the actions sit at
                            // the bottom on a tall screen and stay reachable on a
                            // short one — without ever scrolling.
                            const Spacer(),
                            SizedBox(height: gap * 0.5),

                            _PrimaryButton(
                              label: t.resetAction,
                              loading: _loading,
                              enabled: _canSubmit,
                              onTap: _submit,
                              compact: tight,
                            ),
                            SizedBox(height: gap * 0.55),
                            _ResendButton(
                              label: canResend
                                  ? t.verifyResend
                                  : t.verifyResendIn(_mmss(_resendIn)),
                              busy: _resending,
                              enabled: canResend,
                              onTap: _resend,
                              compact: tight,
                            ),
                            SizedBox(height: gap * 0.7),
                            _SecurityFooter(compact: !roomy),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── pieces

class _TopRow extends StatelessWidget {
  const _TopRow({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: context.colors.surface,
          shape: const CircleBorder(),
          elevation: 1.5,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
        ),
        const Expanded(child: Center(child: AuthBrand(logoSize: 30))),
        // Balances the back button so the wordmark stays optically centred.
        const SizedBox(width: 42),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    );
  }
}

class _EmailChip extends StatelessWidget {
  const _EmailChip({required this.email, required this.onChange});
  final String email;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(
          alpha: context.isDark ? 0.18 : 0.07,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mail_outline_rounded, size: 16, color: context.muted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              email,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onChange,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                context.t.resetChangeEmail,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeStatus extends StatelessWidget {
  const _CodeStatus({
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
              const Icon(
                Icons.error_outline_rounded,
                size: 15,
                color: AppColors.danger,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.danger,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (attemptsLeft != null && attemptsLeft! > 0 && !locked)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                t.verifyAttemptsLeft(attemptsLeft!),
                style: TextStyle(fontSize: 11, color: context.muted),
              ),
            ),
        ],
      );
    }
    if (expired) {
      return Text(
        t.verifyExpired,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.danger),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.schedule_rounded, size: 14, color: context.muted),
        const SizedBox(width: 6),
        // Flexible so a longer translation shrinks instead of spilling out of
        // the row — this line overflowed by a few pixels in French.
        Flexible(
          child: Text(
            t.resetExpiresIn(countdown),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.muted),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.onChanged,
    this.errorText,
    this.matched,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool? matched;

  @override
  Widget build(BuildContext context) {
    final borderColor = errorText != null
        ? AppColors.danger
        : matched == false && controller.text.isNotEmpty
        ? AppColors.danger
        : AppColors.primary.withValues(alpha: 0.35);

    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        errorText: errorText,
        errorMaxLines: 3,
        filled: true,
        fillColor: context.colors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          size: 19,
          color: context.muted,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            size: 19,
            color: context.muted,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final (color, label) = switch (level) {
      >= 3 => (AppColors.success, t.pwStrong),
      2 => (AppColors.warning, t.pwMedium),
      1 => (AppColors.danger, t.pwWeak),
      _ => (context.borderColor, ''),
    };

    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 4,
              decoration: BoxDecoration(
                color: i < level ? color : context.borderColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, maxWidth: 70),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final bool loading, enabled, compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return Opacity(
      opacity: active ? 1 : 0.55,
      child: Container(
        height: compact ? 48 : 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.primary, AppColors.accent],
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: active ? onTap : null,
            borderRadius: BorderRadius.circular(15),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  // Padded and flexible: the French label is long, and a
                  // MainAxisSize.min row would spill past the button rather
                  // than shrink to it.
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 14.5 : 15.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResendButton extends StatelessWidget {
  const _ResendButton({
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final bool busy, enabled, compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 42 : 48,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: busy
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2.1),
              )
            : const Icon(Icons.refresh_rounded, size: 17),
        label: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 13 : 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: context.borderColor),
        ),
      ),
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 14, color: context.muted),
            const SizedBox(width: 7),
            Text(
              t.resetSecurityTitle,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.muted,
              ),
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            t.resetSecurityBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.muted),
          ),
        ],
      ],
    );
  }
}
