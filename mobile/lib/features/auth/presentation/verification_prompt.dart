import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Shown once per sign-in to accounts that predate mandatory verification.
///
/// It states the deadline plainly rather than nagging: these users can still
/// use the app, and the only thing that changes on the deadline is that
/// sign-in stops working — so that is what the copy leads with.
Future<void> showVerificationPrompt(
  BuildContext context,
  WidgetRef ref, {
  required String email,
  required int daysLeft,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _VerificationDialog(
      email: email,
      daysLeft: daysLeft,
      ref: ref,
    ),
  );
}

class _VerificationDialog extends StatefulWidget {
  const _VerificationDialog({
    required this.email,
    required this.daysLeft,
    required this.ref,
  });
  final String email;
  final int daysLeft;
  final WidgetRef ref;

  @override
  State<_VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<_VerificationDialog> {
  bool _sending = false;

  Future<void> _verifyNow() async {
    setState(() => _sending = true);
    try {
      // The server sends a fresh code; the verify screen takes it from here.
      await widget.ref.read(authRepositoryProvider).resendOtp(widget.email);
    } on ApiException catch (e) {
      if (mounted && e.code == 'OTP_RESEND_LIMIT') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.verifyResendLimit)),
        );
      }
    } catch (_) {
      // A failed send must not trap the user in the dialog — the verify screen
      // has its own resend.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (!mounted) return;
    Navigator.pop(context);
    context.push('/verify', extra: widget.email);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final urgent = widget.daysLeft <= 3;
    final accent = urgent ? AppColors.danger : AppColors.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.mark_email_unread_rounded, color: accent, size: 26),
      ),
      title: Text(
        t.verifyBannerTitle(widget.daysLeft),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.verifyBannerBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.45, color: context.muted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.email,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: Text(t.verifyBannerLater),
        ),
        FilledButton(
          onPressed: _sending ? null : _verifyNow,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              : Text(t.verifyBannerCta),
        ),
      ],
    );
  }
}
