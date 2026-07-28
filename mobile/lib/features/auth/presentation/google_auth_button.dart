import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/google_auth_service.dart';
import '../providers/auth_provider.dart';

/// "Continue with Google" / "Sign up with Google".
///
/// [intent] must reflect the screen it sits on. The backend refuses to
/// silently create an account on sign-in, or silently sign in on sign-up, and
/// reports which happened so we can point the user at the other screen.
class GoogleAuthButton extends ConsumerStatefulWidget {
  const GoogleAuthButton({super.key, required this.intent});

  /// 'signin' or 'signup'.
  final String intent;

  @override
  ConsumerState<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends ConsumerState<GoogleAuthButton> {
  bool _loading = false;

  bool get _isSignUp => widget.intent == 'signup';

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final identity = await GoogleAuthService.instance.signIn();
      // Null = user dismissed the picker. Not an error; say nothing.
      if (identity == null) return;

      final user = await ref.read(authRepositoryProvider).googleAuth(
            idToken: identity.idToken,
            intent: widget.intent,
          );
      if (!mounted) return;
      ref.read(authProvider.notifier).setUser(user);
      context.go('/home');
    } on GoogleAuthUnavailable {
      if (mounted) _snack(context.t.googleUnavailable);
    } on GoogleAuthMisconfigured catch (e) {
      // Show the underlying reason: this is a setup problem, and a generic
      // message would leave nothing to act on.
      if (mounted) _snack('${context.t.googleSetupError}\n${e.detail}');
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'ACCOUNT_NOT_FOUND':
          await _showRedirect(
            title: context.t.googleNoAccountTitle,
            body: context.t.googleNoAccountBody(e.email ?? ''),
            cta: context.t.googleNoAccountCta,
            route: '/register',
          );
          break;
        case 'ACCOUNT_EXISTS':
          await _showRedirect(
            title: context.t.googleAccountExistsTitle,
            body: context.t.googleAccountExistsBody(e.email ?? ''),
            cta: context.t.googleAccountExistsCta,
            route: '/login',
          );
          break;
        case 'GOOGLE_EMAIL_UNVERIFIED':
          _snack(context.t.googleEmailUnverified);
          break;
        default:
          _snack(e.message);
      }
    } catch (_) {
      if (mounted) _snack(context.t.genericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  /// Explains why sign-in didn't proceed and offers the correct screen,
  /// rather than a dead-end error toast.
  Future<void> _showRedirect({
    required String title,
    required String body,
    required String cta,
    required String route,
  }) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(body, style: const TextStyle(fontSize: 13.5, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(cta),
          ),
        ],
      ),
    );
    if (go == true && mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _loading ? null : _run,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: context.colors.surface,
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleGlyph(),
                  const SizedBox(width: 12),
                  Text(
                    _isSignUp ? t.signUpWithGoogle : t.continueWithGoogle,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Google's four-colour "G", drawn rather than shipped as an asset.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.22;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four arcs approximating the Google mark.
    canvas.drawArc(rect, -0.35, 1.15, false, p..color = const Color(0xFF4285F4));
    canvas.drawArc(rect, 0.85, 1.35, false, p..color = const Color(0xFF34A853));
    canvas.drawArc(rect, 2.25, 1.35, false, p..color = const Color(0xFFFBBC05));
    canvas.drawArc(rect, 3.65, 1.5, false, p..color = const Color(0xFFEA4335));

    // The horizontal bar of the "G".
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.40, s * 0.5 - stroke / 2, stroke * 0.9),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
