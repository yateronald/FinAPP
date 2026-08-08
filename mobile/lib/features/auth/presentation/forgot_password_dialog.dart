import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Asks for the address a reset code should go to.
///
/// Resolves the trimmed address, or null if dismissed. It deliberately does
/// no network work: the caller owns the request so it can also own the
/// throttling and the neutral "if this address has an account" answer.
Future<String?> showForgotPasswordDialog(
  BuildContext context, {
  String initialEmail = '',
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  final _focus = FocusNode();
  String? _error;

  static final _pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  @override
  void dispose() {
    _email.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _email.text.trim();
    if (!_pattern.hasMatch(value)) {
      setState(() => _error = context.t.emailInvalid);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final media = MediaQuery.of(context);

    return Dialog(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'img/reset_hero.png',
                      width: 210,
                      filterQuality: FilterQuality.high,
                    ).animate().fadeIn(duration: 320.ms).scale(
                          begin: const Offset(0.92, 0.92),
                          duration: 380.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 18),
                    Text(
                      t.forgotDialogTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.forgotDialogBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: context.muted,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t.emailLabel,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _email,
                      focusNode: _focus,
                      autofocus: true,
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
                        filled: true,
                        fillColor: context.colors.surface,
                        prefixIcon: Icon(Icons.mail_outline_rounded,
                            size: 20, color: context.muted),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.35)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 15, color: context.muted),
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

                    const SizedBox(height: 22),
                    _SendButton(onTap: _submit, label: t.forgotSendCode),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        t.cancel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    Divider(color: context.borderColor, height: 1),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 14, color: context.muted),
                        const SizedBox(width: 7),
                        Text(
                          t.secureAndPrivate,
                          style:
                              TextStyle(fontSize: 12, color: context.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Straddles the card's top edge, so it reads as a seal on the
            // dialog rather than an icon inside it.
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.surface, width: 4),
              ),
              child: const Icon(Icons.lock_rounded,
                  size: 27, color: AppColors.primary),
            ).animate().scale(duration: 360.ms, curve: Curves.easeOutBack),

            Positioned(
              top: 42,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, size: 22, color: context.muted),
                tooltip: t.cancel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: AppColors.primary.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
