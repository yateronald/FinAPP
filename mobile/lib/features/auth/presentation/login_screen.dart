import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';
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
      await ref.read(authProvider.notifier).login(_email.text.trim(), _password.text);
      if (mounted) context.go('/home');
    } catch (e) {
      // If auth actually succeeded (token stored, state authenticated) but a
      // non-critical post-login step threw, don't show a misleading failure —
      // just proceed to home.
      if (ref.read(authProvider).status == AuthStatus.authenticated) {
        if (mounted) context.go('/home');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : context.t.signInFailed),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t.forgotTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t.forgotBody),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.t.send),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t.forgotSent)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: context.isDark ? context.colors.surface : const Color(0xFFEFEEFB),
      body: Column(
        children: [
          if (!keyboardOpen)
            SafeArea(
              bottom: false,
              child: AuthHero(
                height: 240,
                left: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AuthBrand(logoSize: 46, showText: false),
                    const SizedBox(height: 10),
                    Text(
                      'Fynexa',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: context.colors.onSurface),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 180,
                      child: Text(t.appTagline,
                          style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.25)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _feature(context, Icons.verified_user_rounded, t.featSecure),
                        const SizedBox(width: 16),
                        _feature(context, Icons.lock_rounded, t.featConfidential),
                        const SizedBox(width: 16),
                        _feature(context, Icons.bolt_rounded, t.featSmart),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                  // Keep the form a comfortable, centred width on tablets and
                  // landscape instead of stretching it across the screen.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(t.loginWelcome,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(t.loginSubtitle,
                              style: TextStyle(color: context.muted, fontSize: 13.5)),
                        ),
                        const SizedBox(height: 18),
                        AuthLabel(t.emailAddress),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: authDecoration(context,
                              hint: t.emailHint, icon: Icons.mail_outline_rounded),
                          validator: (v) =>
                              (v == null || !v.contains('@')) ? t.emailInvalid : null,
                        ),
                        const SizedBox(height: 14),
                        AuthLabel(t.password),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
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
                                  color: context.muted),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? t.required : null,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: Checkbox(
                                value: _remember,
                                onChanged: (v) => setState(() => _remember = v ?? true),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                                activeColor: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(t.rememberMe,
                                style:
                                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            GestureDetector(
                              onTap: _forgotPassword,
                              child: Text(t.forgotPassword,
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AuthPrimaryButton(
                          label: t.signIn,
                          loading: _loading,
                          onTap: _submit,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Divider(color: context.borderColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(t.continueWith,
                                  style: TextStyle(color: context.muted, fontSize: 12.5)),
                            ),
                            Expanded(child: Divider(color: context.borderColor)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const GoogleAuthButton(intent: 'signin'),
                        const SizedBox(height: 14),
                        _SecurityBanner(text: t.bankGrade),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.noAccount, style: TextStyle(color: context.muted)),
                            TextButton(
                              onPressed: () => context.push('/register'),
                              child: Text(t.createAccount),
                            ),
                          ],
                        ),
                      ],
                    ),
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
          ),
        ],
      ),
    );
  }

  Widget _feature(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.colors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: context.muted, fontSize: 11)),
      ],
    );
  }
}

class _SecurityBanner extends StatelessWidget {
  final String text;
  const _SecurityBanner({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.35)),
          ),
          Icon(Icons.chevron_right_rounded, color: context.muted),
        ],
      ),
    );
  }
}
