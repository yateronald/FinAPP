import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'legal_screen.dart';

/// One-time consent prompt for accounts that predate consent recording, or
/// that accepted an earlier revision of the documents.
///
/// The server decides via `needsTermsAcceptance` on /users/me, comparing the
/// stored version against the one currently in force — so the same gate also
/// handles future policy updates without new code.
Future<void> maybePromptTermsAcceptance(BuildContext context, WidgetRef ref) async {
  final api = ApiClient.instance;

  bool needed;
  try {
    final me = Map<String, dynamic>.from(await api.get('/users/me'));
    needed = me['needsTermsAcceptance'] == true;
  } catch (_) {
    // Offline or a server hiccup — never block someone out of their own data
    // over a consent check. It will be asked again next launch.
    return;
  }
  if (!needed || !context.mounted) return;

  await showDialog<void>(
    context: context,
    // Consent has to be a deliberate act, so it cannot be dismissed by
    // tapping outside or by the back button.
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: _TermsAcceptanceDialog(ref: ref),
    ),
  );
}

class _TermsAcceptanceDialog extends StatefulWidget {
  const _TermsAcceptanceDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_TermsAcceptanceDialog> createState() => _TermsAcceptanceDialogState();
}

class _TermsAcceptanceDialogState extends State<_TermsAcceptanceDialog> {
  bool _readTerms = false;
  bool _readPrivacy = false;
  bool _checked = false;
  bool _saving = false;

  bool get _canAccept => _readTerms && _readPrivacy && _checked && !_saving;

  Future<void> _open(LegalDocument doc) async {
    await showLegalDocument(context, doc);
    if (!mounted) return;
    setState(() {
      if (doc == LegalDocument.terms) {
        _readTerms = true;
      } else {
        _readPrivacy = true;
      }
    });
  }

  Future<void> _accept() async {
    setState(() => _saving = true);
    try {
      await ApiClient.instance.post('/users/me/accept-terms');
      await widget.ref.read(authProvider.notifier).refreshUser();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 26),
      ),
      title: Text(t.termsUpdateTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.termsUpdateBody,
                style: const TextStyle(fontSize: 13.5, height: 1.45)),
            const SizedBox(height: 16),
            Text(t.termsUpdateRead,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: context.muted)),
            const SizedBox(height: 8),
            _DocLink(
              label: t.termsOfUse,
              read: _readTerms,
              onTap: () => _open(LegalDocument.terms),
            ),
            const SizedBox(height: 8),
            _DocLink(
              label: t.privacyPolicy,
              read: _readPrivacy,
              onTap: () => _open(LegalDocument.privacy),
            ),
            const SizedBox(height: 12),
            InkWell(
              // Only offer the checkbox once both documents have been opened —
              // "I have read" should not be possible to tick without reading.
              onTap: (_readTerms && _readPrivacy)
                  ? () => setState(() => _checked = !_checked)
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.termsUpdateMustRead)),
                      ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _checked,
                      onChanged: (_readTerms && _readPrivacy)
                          ? (v) => setState(() => _checked = v ?? false)
                          : null,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(t.termsUpdateAcceptLabel,
                          style: const TextStyle(fontSize: 12.5, height: 1.4)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canAccept ? _accept : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2))
                : Text(t.termsUpdateAccept),
          ),
        ),
      ],
    );
  }
}

class _DocLink extends StatelessWidget {
  const _DocLink({required this.label, required this.read, required this.onTap});
  final String label;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: context.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: read ? AppColors.success.withValues(alpha: 0.5) : context.borderColor,
          ),
        ),
        child: Row(children: [
          Icon(
            read ? Icons.check_circle_rounded : Icons.description_outlined,
            size: 17,
            color: read ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: context.muted),
        ]),
      ),
    );
  }
}
