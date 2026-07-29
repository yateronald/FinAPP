import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

/// Two-step permanent account deletion.
///
/// Step 1 states exactly what is lost, step 2 requires the user to type
/// DELETE / SUPPRIMER. Both steps are deliberate friction: this erases
/// everything server-side with no recovery path.
Future<void> runDeleteAccountFlow(BuildContext context, WidgetRef ref) async {
  final api = ApiClient.instance;

  // ---- Step 1: show the real cost, fetched from the server.
  Map<String, dynamic> impact;
  try {
    impact = Map<String, dynamic>.from(await api.get('/users/me/deletion-impact'));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : context.t.genericError),
        backgroundColor: AppColors.danger,
      ));
    }
    return;
  }
  if (!context.mounted) return;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _Step1Dialog(impact: impact),
  );
  if (proceed != true || !context.mounted) return;

  // ---- Step 2: typed confirmation.
  final keyword = context.t.deleteAccountKeyword;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _Step2Dialog(keyword: keyword),
  );
  if (confirmed != true || !context.mounted) return;

  // ---- Erase.
  try {
    await api.delete('/users/me', body: {'confirmation': keyword});
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : context.t.genericError),
        backgroundColor: AppColors.danger,
      ));
    }
    return;
  }

  // Confirm it explicitly before anything else. A SnackBar would be wrong
  // here: navigating away disposes it, so the user could be thrown back to
  // the login screen having never seen that the deletion succeeded.
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle_outline_rounded,
            color: AppColors.success, size: 28),
      ),
      title: Text(ctx.t.deleteAccountDoneTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: Text(ctx.t.deleteAccountDone,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, height: 1.45)),
      actions: [
        Center(
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t.backToLogin),
          ),
        ),
      ],
    ),
  );

  // The account is gone, but authProvider still reports `authenticated`.
  // The router sends any authenticated user away from /login back to /home,
  // so navigating without clearing the state first would bounce the user into
  // a dashboard backed by a dead token. logout() clears tokens, the Google
  // session and the auth state together.
  await ref.read(authProvider.notifier).logout();
  if (!context.mounted) return;
  context.go('/login');
}

class _Step1Dialog extends StatelessWidget {
  const _Step1Dialog({required this.impact});
  final Map<String, dynamic> impact;

  int _n(String key) => (impact[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final rows = <(int, String)>[
      (_n('expenses'), t.deleteAccountExpenses),
      (_n('incomes'), t.deleteAccountIncomes),
      (_n('budgets'), t.deleteAccountBudgets),
      (_n('categories'), t.deleteAccountCategories),
      (_n('insights'), t.deleteAccountInsights),
    ].where((r) => r.$1 > 0).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.delete_forever_rounded,
            color: AppColors.danger, size: 28),
      ),
      title: Text(t.deleteAccountStep1Title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.deleteAccountStep1Body,
              style: const TextStyle(fontSize: 13.5, height: 1.45)),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (n, label) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        const Icon(Icons.remove_circle_outline_rounded,
                            size: 15, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Text(t.deleteAccountCount(n, label),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(t.deleteAccountContinue),
        ),
      ],
    );
  }
}

class _Step2Dialog extends StatefulWidget {
  const _Step2Dialog({required this.keyword});
  final String keyword;

  @override
  State<_Step2Dialog> createState() => _Step2DialogState();
}

class _Step2DialogState extends State<_Step2Dialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final ok = _controller.text.trim().toUpperCase() == widget.keyword.toUpperCase();
      if (ok != _matches) setState(() => _matches = ok);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(t.deleteAccountStep2Title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.deleteAccountStep2Body,
              style: const TextStyle(fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: t.deleteAccountTypeHint,
              errorText: _controller.text.isNotEmpty && !_matches
                  ? t.deleteAccountMismatch
                  : null,
            ),
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          // Stays disabled until the word matches exactly.
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: Text(t.deleteAccountConfirmButton),
        ),
      ],
    );
  }
}
