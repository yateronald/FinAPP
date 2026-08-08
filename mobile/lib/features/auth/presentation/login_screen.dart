import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';
import 'forgot_password_dialog.dart';
import 'verification_prompt.dart';
import 'google_auth_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;
  bool _showCredentialForm = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(_email.text.trim(), _password.text);
      if (mounted) {
        context.go('/home');
        final pending = AuthRepository.pendingVerification;
        if (pending != null) {
          AuthRepository.pendingVerification = null;
          // After the navigation so the dialog belongs to the shell, not to a
          // screen that is about to be disposed.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showVerificationPrompt(context, ref,
                email: pending.email, daysLeft: pending.daysLeft);
          });
        }
      }
    } catch (e) {
      // If auth actually succeeded (token stored, state authenticated) but a
      // non-critical post-login step threw, don't show a misleading failure —
      // just proceed to home.
      if (ref.read(authProvider).status == AuthStatus.authenticated) {
        if (mounted) context.go('/home');
      } else if (e is ApiException && e.code == 'ACCOUNT_LOCKED') {
        // Five wrong passwords: the account is suspended, so show the
        // countdown and the one action that ends it.
        if (mounted) {
          context.push('/account-locked', extra: {
            'email': e.email ?? _email.text.trim(),
            'lockedUntil': e.lockedUntil ??
                DateTime.now().add(Duration(seconds: e.retryAfter ?? 0)),
          });
        }
      } else if (e is ApiException &&
          e.code == 'BAD_CREDENTIALS' &&
          e.attemptsLeft != null &&
          e.attemptsLeft! <= 2) {
        // Warn before the lock lands, not after.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${e.message} — ${context.t.accountLockAttemptsLeft(e.attemptsLeft!)}',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } else if (e is ApiException && e.code == 'EMAIL_NOT_VERIFIED') {
        // The account exists and the password was right — it simply has not
        // confirmed its address yet, and the server already sent a code.
        if (mounted) context.push('/verify', extra: e.email ?? _email.text.trim());
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : context.t.signInFailed,
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = await showForgotPasswordDialog(
      context,
      initialEmail: _email.text.trim(),
    );
    if (email == null || email.isEmpty) return;
    var throttled = false;
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
    } on ApiException catch (e) {
      // The only error worth surfacing: everything else answers the same way
      // whether or not the address has an account, and saying more here would
      // turn this screen into an account-enumeration oracle.
      throttled = e.code == 'OTP_RESEND_LIMIT';
      if (throttled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.verifyResendLimit)),
        );
      }
    } catch (_) {}
    if (!mounted || throttled) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t.forgotSent)));
    // Straight to the code screen: the code is only valid three minutes, so
    // making the user find their own way there wastes most of the window.
    context.push('/reset-password', extra: email);
  }

  Widget _methodChoice(AppText t) {
    return Column(
      key: const ValueKey('login-method-choice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.loginWelcome,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.loginSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 24),
        AuthMethodButton(
          emphasized: true,
          leading: const Icon(
            Icons.mail_rounded,
            color: Colors.white,
            size: 22,
          ),
          label: t.signInWithEmail,
          subtitle: t.signInWithEmailBody,
          onTap: () => setState(() => _showCredentialForm = true),
        ),
        const SizedBox(height: 16),
        AuthMethodDivider(label: t.orSeparator),
        const SizedBox(height: 16),
        const GoogleAuthButton(intent: 'signin'),
        const SizedBox(height: 18),
        AuthSecurityBanner(title: t.authSecurityTitle, body: t.bankGrade),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(t.noAccount, style: TextStyle(color: context.muted)),
            TextButton(
              onPressed: () => context.push('/register'),
              child: Text(t.createAccount),
            ),
          ],
        ),
      ],
    );
  }

  Widget _credentialForm(AppText t) {
    return Column(
      key: const ValueKey('login-credential-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton.filledTonal(
              onPressed: _loading
                  ? null
                  : () => setState(() => _showCredentialForm = false),
              icon: const Icon(Icons.arrow_back_rounded, size: 19),
              tooltip: t.backToSignInOptions,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.signInWithEmail,
                    style: const TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.signInWithEmailBody,
                    style: TextStyle(color: context.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        AuthLabel(t.emailAddress),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: authDecoration(
            context,
            hint: t.emailHint,
            icon: Icons.mail_outline_rounded,
          ),
          validator: (v) =>
              (v == null || !v.contains('@')) ? t.emailInvalid : null,
        ),
        const SizedBox(height: 14),
        AuthLabel(t.password),
        TextFormField(
          controller: _password,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => _submit(),
          decoration: authDecoration(
            context,
            hint: t.passwordHint,
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: context.muted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) => (v == null || v.isEmpty) ? t.required : null,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 2,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 22,
                  width: 22,
                  child: Checkbox(
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v ?? true),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    activeColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  t.rememberMe,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _forgotPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
              child: Text(
                t.forgotPassword,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AuthPrimaryButton(label: t.signIn, loading: _loading, onTap: _submit),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _loading
              ? null
              : () => setState(() => _showCredentialForm = false),
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: Text(t.backToSignInOptions),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(t.noAccount, style: TextStyle(color: context.muted)),
            TextButton(
              onPressed: () => context.push('/register'),
              child: Text(t.createAccount),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuthBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, keyboardOpen ? 22 : 18, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!keyboardOpen) ...[
                      AuthHero(
                        height: 192,
                        left: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AuthBrand(logoSize: 42, showText: false),
                            const SizedBox(height: 9),
                            Text(
                              'Fynexa',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              t.appTagline,
                              style: TextStyle(
                                color: context.muted,
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Row(
                              children: [
                                Expanded(
                                  child: _heroFeature(
                                    Icons.verified_user_rounded,
                                    t.featSecure,
                                  ),
                                ),
                                Expanded(
                                  child: _heroFeature(
                                    Icons.lock_rounded,
                                    t.featConfidential,
                                  ),
                                ),
                                Expanded(
                                  child: _heroFeature(
                                    Icons.bolt_rounded,
                                    t.featSmart,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 350.ms),
                      const SizedBox(height: 30),
                    ],
                    AuthPanel(
                          icon: Icons.person_rounded,
                          child: Form(
                            key: _formKey,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.035, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                              child: _showCredentialForm
                                  ? _credentialForm(t)
                                  : _methodChoice(t),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 380.ms)
                        .slideY(begin: 0.04, end: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroFeature(IconData icon, String label) => Column(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 16),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.muted, fontSize: 9.5),
      ),
    ],
  );
}
