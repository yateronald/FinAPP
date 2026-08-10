import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// What the caller's request came back with.
///
/// Deliberately coarse: [sent] also covers a server error, because answering
/// differently would turn this dialog into an account-enumeration oracle. Only
/// throttling and a dead network are distinguishable, and neither reveals
/// whether the address has an account.
enum ForgotPasswordOutcome { sent, throttled, offline }

/// An outcome plus, when throttled, how long the caller was told to wait.
class ForgotPasswordResult {
  const ForgotPasswordResult(this.outcome, {this.retryAfterSeconds});

  const ForgotPasswordResult.sent() : this(ForgotPasswordOutcome.sent);
  const ForgotPasswordResult.offline() : this(ForgotPasswordOutcome.offline);
  const ForgotPasswordResult.throttled({int? retryAfterSeconds})
      : this(ForgotPasswordOutcome.throttled,
            retryAfterSeconds: retryAfterSeconds);

  final ForgotPasswordOutcome outcome;

  /// Seconds until a retry is allowed, when the server said so.
  final int? retryAfterSeconds;
}

/// Runs a reset-code request and classifies the answer for the dialog.
///
/// Lives here, in one place, because the classification *is* a security rule:
/// everything except throttling and an unreachable server must report as
/// [ForgotPasswordOutcome.sent], or the reply would differ depending on whether
/// the address has an account and the screen would become an enumeration
/// oracle. Both callers go through this rather than each writing the branch.
Future<ForgotPasswordResult> sendResetCode(Future<void> Function() send) async {
  try {
    await send();
    return const ForgotPasswordResult.sent();
  } on ApiException catch (e) {
    if (e.code == 'OTP_RESEND_LIMIT') {
      return ForgotPasswordResult.throttled(retryAfterSeconds: e.retryAfter);
    }
    // No status code means the request never reached the server — worth
    // telling the user, and it reveals nothing about the address.
    if (e.statusCode == null) return const ForgotPasswordResult.offline();
    return const ForgotPasswordResult.sent();
  } catch (_) {
    return const ForgotPasswordResult.sent();
  }
}

/// Asks for the address a reset code should go to, then sends it.
///
/// The request runs *inside* the dialog rather than after it closes. That is
/// the whole point: the send takes a second or two against SMTP, and a dialog
/// that dismissed first left the user staring at the login screen wondering
/// whether anything had happened.
///
/// The caller still owns the request through [onSubmit] — it keeps the
/// throttling rules and the neutral answer — while the dialog owns the
/// progress, error and confirmation states.
///
/// Resolves the trimmed address once a code is on its way, or null if
/// dismissed. A non-null result means the caller can go straight to the code
/// screen with no further work.
Future<String?> showForgotPasswordDialog(
  BuildContext context, {
  String initialEmail = '',
  required Future<ForgotPasswordResult> Function(String email) onSubmit,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    // Dismissal is governed by the dialog itself: it must not vanish mid-send.
    barrierDismissible: false,
    builder: (_) => _ForgotPasswordDialog(
      initialEmail: initialEmail,
      onSubmit: onSubmit,
    ),
  );
}

/// The dialog is a small three-step flow, not a single form.
enum _Phase { form, sending, sent }

/// How much room the dialog has to work with.
///
/// The send button must be reachable without scrolling — on a short phone,
/// with the keyboard up, a card that scrolls hides the one control the user
/// came for. Space is given back in the order it costs the least: the
/// illustration first (it carries no information; the seal already sets the
/// tone), then the vertical rhythm.
enum _Density { tight, snug, roomy }

_Density _densityFor(double height) => height < 700
    ? _Density.tight
    : height < 820
        ? _Density.snug
        : _Density.roomy;

extension on _Density {
  /// Null hides the illustration entirely.
  double? get heroWidth => switch (this) {
        _Density.tight => null,
        _Density.snug => 150,
        _Density.roomy => 210,
      };

  double get gap => switch (this) {
        _Density.tight => 12,
        _Density.snug => 16,
        _Density.roomy => 18,
      };

  double get blockGap => switch (this) {
        _Density.tight => 16,
        _Density.snug => 20,
        _Density.roomy => 24,
      };

  double get topPad => switch (this) {
        _Density.tight => 34,
        _Density.snug => 38,
        _Density.roomy => 40,
      };

  double get titleSize => switch (this) {
        _Density.tight => 19,
        _Density.snug => 21,
        _Density.roomy => 22,
      };
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onSubmit,
  });
  final String initialEmail;
  final Future<ForgotPasswordResult> Function(String email) onSubmit;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  final _focus = FocusNode();
  String? _error;
  _Phase _phase = _Phase.form;

  /// The address the code actually went to — frozen at send time so the
  /// confirmation cannot show something the user edited afterwards.
  String _sentTo = '';

  static final _pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  bool get _busy => _phase != _Phase.form;

  @override
  void dispose() {
    _email.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m min ${s.toString().padLeft(2, '0')}' : '$s s';
  }

  Future<void> _submit() async {
    if (_busy) return;
    final value = _email.text.trim();
    if (!_pattern.hasMatch(value)) {
      setState(() => _error = context.t.emailInvalid);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.sending;
      _error = null;
      _sentTo = value;
    });

    late final ForgotPasswordResult result;
    try {
      result = await widget.onSubmit(value);
    } catch (_) {
      // Never leave the dialog stuck on the spinner, whatever went wrong.
      result = const ForgotPasswordResult.sent();
    }
    if (!mounted) return;

    switch (result.outcome) {
      case ForgotPasswordOutcome.sent:
        HapticFeedback.mediumImpact();
        setState(() => _phase = _Phase.sent);
        // Long enough to read the confirmation, short enough not to feel like
        // a wait — the code is only valid three minutes.
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        if (mounted) Navigator.pop(context, value);
      case ForgotPasswordOutcome.throttled:
      case ForgotPasswordOutcome.offline:
        HapticFeedback.heavyImpact();
        setState(() {
          _phase = _Phase.form;
          _error = switch (result.outcome) {
            ForgotPasswordOutcome.offline => context.t.forgotOffline,
            // A concrete countdown beats "too many requests" — the user can
            // decide whether to wait or come back.
            _ when result.retryAfterSeconds != null =>
              context.t.forgotRetryIn(_mmss(result.retryAfterSeconds!)),
            _ => context.t.verifyResendLimit,
          };
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final media = MediaQuery.of(context);
    final density = _densityFor(media.size.height);

    return PopScope(
      // A back gesture mid-send would drop the request on the floor while the
      // server has already queued an e-mail.
      canPop: !_busy,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          // The card scrolls internally rather than growing under a keyboard.
          constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                // Room for the badge that straddles the top edge.
                margin: const EdgeInsets.only(top: 30),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(26),
                ),
                // Both phases live in one card that resizes between them, so
                // the confirmation grows out of the form instead of replacing
                // a dialog that blinked away first.
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _phase == _Phase.sent
                        ? _SentPanel(key: const ValueKey('sent'), email: _sentTo)
                        : _form(t, density),
                  ),
                ),
              ),

              // Straddles the card's top edge, so it reads as a seal on the
              // dialog rather than an icon inside it.
              _Seal(sent: _phase == _Phase.sent),

              // Hidden once the request is away: there is nothing left to
              // cancel, and the dialog closes itself a moment later.
              if (!_busy)
                Positioned(
                  top: 42,
                  right: 10,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        size: 22, color: context.muted),
                    tooltip: t.cancel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(AppText t, _Density d) {
    final heroWidth = d.heroWidth;
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: EdgeInsets.fromLTRB(24, d.topPad, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (heroWidth != null) ...[
            Image.asset(
              'img/reset_hero.png',
              width: heroWidth,
              filterQuality: FilterQuality.high,
            ).animate().fadeIn(duration: 320.ms).scale(
                  begin: const Offset(0.92, 0.92),
                  duration: 380.ms,
                  curve: Curves.easeOutBack,
                ),
            SizedBox(height: d.gap),
          ],
          Text(
            t.forgotDialogTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: d.titleSize,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t.forgotDialogBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: context.muted),
          ),
          SizedBox(height: d.blockGap),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              t.emailLabel,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _email,
            focusNode: _focus,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: t.emailPlaceholder,
              errorText: _error,
              // A throttle message runs to two lines; one line would clip it.
              errorMaxLines: 3,
              filled: true,
              fillColor: context.colors.surface,
              prefixIcon:
                  Icon(Icons.mail_outline_rounded, size: 20, color: context.muted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.6),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 15, color: context.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.forgotPrivacyNote,
                  style: TextStyle(
                      fontSize: 11.5, height: 1.4, color: context.muted),
                ),
              ),
            ],
          ),

          SizedBox(height: d.blockGap - 2),
          _SendButton(
            onTap: _submit,
            label: _phase == _Phase.sending ? t.forgotSending : t.forgotSendCode,
            busy: _phase == _Phase.sending,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(
              t.cancel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _busy ? context.muted : AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 6),
          Divider(color: context.borderColor, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: context.muted),
              const SizedBox(width: 7),
              // Ellipsises rather than overflowing once the label is long — it
              // is reassurance, not information the user has to read in full.
              Flexible(
                child: Text(
                  t.secureAndPrivate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The confirmation the dialog shows before handing over to the code screen.
///
/// It exists so the transition reads as one continuous flow: send → confirmed →
/// code screen, with the login screen never coming back into view.
class _SentPanel extends StatelessWidget {
  const _SentPanel({super.key, required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 46, 28, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.forgotSentTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ).animate().fadeIn(duration: 260.ms, delay: 60.ms),
          const SizedBox(height: 10),
          Text(
            t.forgotSentBody(email),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: context.muted),
          ).animate().fadeIn(duration: 260.ms, delay: 120.ms),
          const SizedBox(height: 22),
          // A determinate-looking sliver rather than a spinner: the wait is
          // short and fixed, and a spinner would suggest more work is pending.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  t.forgotOpening,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.muted,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 240.ms, delay: 260.ms),
        ],
      ),
    );
  }
}

/// The badge on the card's top edge. Turns into a tick on success, which is
/// what carries the "it worked" moment while the card resizes behind it.
class _Seal extends StatelessWidget {
  const _Seal({required this.sent});
  final bool sent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: sent ? const Color(0xFFDCFCE7) : const Color(0xFFEDE9FE),
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.surface, width: 4),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: sent
            ? const Icon(Icons.check_rounded,
                key: ValueKey('ok'), size: 30, color: AppColors.successDark)
            : const Icon(Icons.lock_rounded,
                key: ValueKey('lock'), size: 27, color: AppColors.primary),
      ),
    ).animate().scale(duration: 360.ms, curve: Curves.easeOutBack);
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.onTap,
    required this.label,
    required this.busy,
  });
  final VoidCallback onTap;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.9 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.primary, AppColors.accent],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: busy ? 0.18 : 0.34),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Row(
                  key: ValueKey(busy),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (!busy) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                    ],
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
