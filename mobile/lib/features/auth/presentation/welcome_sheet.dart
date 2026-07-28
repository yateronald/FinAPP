import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// One-time greeting after a user's very first sign-in.
///
/// Returns true when the user chose to add their first expense, so the caller
/// can open the add-expense sheet — a welcome that ends in a dead end is just
/// a popup to dismiss.
Future<bool> maybeShowWelcome(BuildContext context, WidgetRef ref) async {
  final storage = SecureStorage.instance;
  if (await storage.welcomeShown) return false;

  // The server flags the first sign-in; a reinstall would repeat it, hence the
  // local record as well.
  final user = ref.read(authProvider).user;
  if (user == null) return false;

  await storage.markWelcomeShown();
  if (!context.mounted) return false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _WelcomeSheet(firstName: user.firstName),
  );
  return result == true;
}

class _WelcomeSheet extends StatelessWidget {
  const _WelcomeSheet({this.firstName});
  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 28, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.celebration_rounded,
                  color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.welcomeTitle(firstName),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.25),
          ),
          const SizedBox(height: 12),
          Text(
            t.welcomeBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: context.muted),
          ),
          const SizedBox(height: 22),
          _Point(icon: Icons.bolt_rounded, text: t.welcomePoint1),
          const SizedBox(height: 10),
          _Point(icon: Icons.savings_rounded, text: t.welcomePoint2),
          const SizedBox(height: 10),
          _Point(icon: Icons.auto_awesome_rounded, text: t.welcomePoint3),
          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(t.welcomeCta,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.welcomeLater, style: TextStyle(color: context.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 17, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}
