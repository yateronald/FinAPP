import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/legal_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/ai_providers.dart';

bool isAiEnabled(WidgetRef ref) => ref.watch(
  authProvider.select((state) => state.user?.settings?.aiEnabled == true),
);

/// Presents the complete data-use disclosure and records explicit consent.
/// The backend independently requires the same confirmation and stores its
/// timestamp/version, so bypassing this UI cannot enable AI.
Future<bool> showAiConsentSheet(BuildContext context, WidgetRef ref) async {
  if (ref.read(authProvider).user?.settings?.aiEnabled == true) return true;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiConsentSheet(ref: ref),
  );
  return result == true;
}

/// Offers AI once after the welcome flow. Declining is respected and AI stays
/// available from Settings or any disabled AI card without further prompting.
Future<void> maybePromptAiConsent(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider).user;
  if (user == null || user.settings?.aiEnabled == true) return;

  final storage = SecureStorage.instance;
  if (await storage.aiConsentPrompted(user.id)) return;
  if (!context.mounted) return;
  await showAiConsentSheet(context, ref);
  await storage.markAiConsentPrompted(user.id);
}

Future<void> disableAi(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  try {
    await ref.read(settingsRepositoryProvider).updateSettings({
      'aiEnabled': false,
    });
    await ref.read(authProvider.notifier).refreshUser();
    ref.read(chatProvider.notifier).clear();
    ref.invalidate(forecastProvider);
    ref.invalidate(aiInsightsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.aiDisabledSuccess)));
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    }
  }
}

class _AiConsentSheet extends StatefulWidget {
  const _AiConsentSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_AiConsentSheet> createState() => _AiConsentSheetState();
}

class _AiConsentSheetState extends State<_AiConsentSheet> {
  bool _confirmed = false;
  bool _saving = false;

  Future<void> _enable() async {
    if (!_confirmed || _saving) return;
    setState(() => _saving = true);
    final t = context.t;
    try {
      await widget.ref.read(settingsRepositoryProvider).updateSettings({
        'aiEnabled': true,
        'aiConsentConfirmed': true,
      });
      await widget.ref.read(authProvider.notifier).refreshUser();
      widget.ref.invalidate(forecastProvider);
      widget.ref.invalidate(aiInsightsProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.aiConsentEnabled)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.genericError),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      t.aiConsentTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Center(
                    child: Text(
                      t.aiConsentIntro,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: context.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DisclosurePoint(
                    icon: Icons.account_balance_wallet_outlined,
                    title: t.aiConsentDataTitle,
                    body: t.aiConsentDataBody,
                  ),
                  const SizedBox(height: 10),
                  _DisclosurePoint(
                    icon: Icons.cloud_outlined,
                    title: t.aiConsentProviderTitle,
                    body: t.aiConsentProviderBody,
                  ),
                  const SizedBox(height: 10),
                  _DisclosurePoint(
                    icon: Icons.shield_outlined,
                    title: t.aiConsentControlTitle,
                    body: t.aiConsentControlBody,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            t.aiConsentAccuracy,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        showLegalDocument(context, LegalDocument.privacy),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(t.aiConsentPrivacy),
                  ),
                  InkWell(
                    onTap: _saving
                        ? null
                        : () => setState(() => _confirmed = !_confirmed),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _confirmed
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : context.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _confirmed
                              ? AppColors.primary.withValues(alpha: 0.35)
                              : context.borderColor,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 23,
                            height: 23,
                            child: Checkbox(
                              value: _confirmed,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(
                                      () => _confirmed = value ?? false,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t.aiConsentCheckbox,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _confirmed && !_saving ? _enable : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(t.aiEnableAction),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: Text(
              t.aiConsentNotNow,
              style: TextStyle(color: context.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclosurePoint extends StatelessWidget {
  const _DisclosurePoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: 11.7,
                  height: 1.38,
                  color: context.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared, non-AI placeholder. Keeping this outside AI providers guarantees
/// no request is created merely by rendering a dashboard or budget screen.
class AiDisabledState extends ConsumerWidget {
  const AiDisabledState({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 22),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(compact ? 16 : 22),
        border: Border.all(color: context.borderColor),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 42 : 58,
            height: compact ? 42 : 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(compact ? 13 : 18),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: compact ? 20 : 28,
                ),
                Positioned(
                  right: compact ? 5 : 7,
                  bottom: compact ? 5 : 7,
                  child: Icon(
                    Icons.lock_rounded,
                    color: context.colors.surface,
                    size: compact ? 10 : 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 9 : 15),
          Text(
            t.aiDisabledTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 14 : 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            t.aiDisabledBody,
            textAlign: TextAlign.center,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: TextStyle(
              fontSize: compact ? 11.5 : 13,
              height: 1.4,
              color: context.muted,
            ),
          ),
          SizedBox(height: compact ? 10 : 18),
          FilledButton.icon(
            onPressed: () => showAiConsentSheet(context, ref),
            icon: const Icon(Icons.shield_outlined, size: 17),
            label: Text(t.aiEnableAction),
            style: FilledButton.styleFrom(
              minimumSize: Size(
                compact ? 0 : double.infinity,
                compact ? 40 : 48,
              ),
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
              textStyle: TextStyle(
                fontSize: compact ? 12 : 13.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ],
      ),
    );

    if (compact) return card;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: card,
        ),
      ),
    );
  }
}
