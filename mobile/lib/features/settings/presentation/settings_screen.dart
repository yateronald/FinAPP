import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/responsive.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../categories/presentation/categories_screen.dart';
import '../providers/settings_provider.dart';
import 'delete_account_flow.dart';
import 'change_password_sheet.dart';
import 'edit_profile_sheet.dart';

/// Selectable AI models per provider. Keep in sync with the backend
/// `ai-models.ts` registry (also exposed at GET /ai/models).
const kAiModels = <String, List<(String, String)>>{
  'GEMINI': [
    ('gemini-3.6-flash', 'Gemini 3.6 Flash'),
    ('gemini-3.5-flash', 'Gemini 3.5 Flash'),
    ('gemini-3.1-pro-preview', 'Gemini 3.1 Pro'),
    ('gemini-3-flash-preview', 'Gemini 3 Flash'),
    ('gemini-3-pro-preview', 'Gemini 3 Pro'),
  ],
  'AGENTROUTER': [
    ('claude-opus-4-8', 'Claude Opus 4.8'),
    ('claude-opus-4-7', 'Claude Opus 4.7'),
    ('claude-opus-4-6', 'Claude Opus 4.6'),
    ('glm-5.2', 'GLM 5.2'),
    ('gpt-5.5', 'GPT-5.5'),
  ],
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setTheme(WidgetRef ref, String theme) async {
    await ref.read(settingsRepositoryProvider).updateSettings({'theme': theme});
    await ref.read(authProvider.notifier).refreshUser();
  }

  Future<void> _setLanguage(WidgetRef ref, String lang) async {
    await ref.read(settingsRepositoryProvider).updateSettings({'language': lang});
    await ref.read(authProvider.notifier).refreshUser();
  }

  Future<void> _toggle(WidgetRef ref, String key, bool value) async {
    await ref.read(settingsRepositoryProvider).updateSettings({key: value});
    await ref.read(authProvider.notifier).refreshUser();
  }

  /// Push-notification toggle: enabling asks for OS permission and registers
  /// the device; disabling unregisters it from the backend and Firebase.
  Future<void> _toggleNotifications(BuildContext context, WidgetRef ref, bool value) async {
    final t = context.t;
    if (value) {
      final granted = await NotificationService.instance.enableAndRegister();
      if (!granted) {
        // Permission refused — keep it OFF and tell the user how to enable it.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.notificationsPermissionDenied)),
          );
        }
        return;
      }
      await ref.read(settingsRepositoryProvider).updateSettings({'notificationsEnabled': true});
    } else {
      await NotificationService.instance.unregister();
      await ref.read(settingsRepositoryProvider).updateSettings({'notificationsEnabled': false});
    }
    await ref.read(authProvider.notifier).refreshUser();
  }

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool value) async {
    final t = context.t;
    if (value) {
      final auth = LocalAuthentication();
      try {
        final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
        if (!canCheck) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(t.biometricUnavailable)));
          }
          return;
        }
        final ok = await auth.authenticate(
          localizedReason: t.biometricOnEach,
          persistAcrossBackgrounding: true,
          biometricOnly: true,
        );
        if (!ok) return;
      } catch (_) {
        return;
      }
    }
    await ref.read(biometricEnabledProvider.notifier).set(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final user = ref.watch(authProvider).user;
    final settings = user?.settings;
    final theme = settings?.theme ?? 'SYSTEM';
    final language = (settings?.language ?? 'FR').toUpperCase();
    final biometric = ref.watch(biometricEnabledProvider);
    final bioLabel = ref.watch(biometricLabelProvider).value ?? 'Biométrie';

    return ResponsiveCenter(
      child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(user?.initials ?? '?',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(user?.email ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => showEditProfileSheet(context),
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _sectionLabel(t.appearance),
        _card(context, [
          _selectorTile(context, t.theme, _ThemeSelector(current: theme, onSelect: (v) => _setTheme(ref, v))),
        ]),
        const SizedBox(height: 20),

        _sectionLabel(t.preferences),
        _card(context, [
          _selectorTile(
            context,
            t.language,
            _Segmented(
              current: language,
              options: [('FR', t.langFrench), ('EN', t.langEnglish)],
              onSelect: (v) => _setLanguage(ref, v),
            ),
          ),
          _divider(context),
          _switchTile(context, Icons.notifications_none_rounded, t.notificationsPref,
              settings?.notificationsEnabled ?? true,
              (v) => _toggleNotifications(context, ref, v)),
          _divider(context),
          _switchTile(context, Icons.mark_email_read_outlined, t.emailNotifications,
              settings?.emailNotifications ?? true, (v) => _toggle(ref, 'emailNotifications', v)),
          _divider(context),
          _switchTile(context, Icons.auto_awesome_rounded, t.aiAssistantPref,
              settings?.aiEnabled ?? true, (v) => _toggle(ref, 'aiEnabled', v)),
        ]),
        if (settings?.aiEnabled ?? true) ...[
          const SizedBox(height: 20),
          _sectionLabel(t.aiModel),
          const _AiSettingsCard(),
        ],
        const SizedBox(height: 20),

        _sectionLabel(t.management),
        _card(context, [
          _navTile(context, Icons.category_rounded, t.categories, () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CategoriesScreen()));
          }),
        ]),
        const SizedBox(height: 20),

        _sectionLabel(t.security),
        _card(context, [
          _switchTile(
            context,
            Icons.fingerprint_rounded,
            t.biometricUnlock(bioLabel),
            biometric,
            (v) => _toggleBiometric(context, ref, v),
            subtitle: biometric ? t.biometricOnEach : t.biometricProtect(bioLabel),
          ),
          _divider(context),
          // Google-created accounts have no password yet — offer to set one
          // rather than to change something that does not exist.
          _navTile(
              context,
              Icons.lock_outline_rounded,
              (ref.watch(authProvider).user?.hasPassword ?? true)
                  ? t.changePassword
                  : t.setPassword,
              () => showChangePasswordSheet(context)),
          _divider(context),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.screenshot_monitor_rounded, color: context.muted),
            title: Text(t.screenshotProtection,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            subtitle: Text(t.screenshotBlocked,
                style: TextStyle(color: context.muted, fontSize: 12.5)),
            trailing: const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 20),
          ),
        ]),
        const SizedBox(height: 20),

        _sectionLabel(t.account),
        _card(context, [
          _navTile(context, Icons.logout_rounded, t.logout,
              () => ref.read(authProvider.notifier).logout(),
              color: AppColors.danger),
        ]),
        const SizedBox(height: 20),

        // Separated from the rest: irreversible, and should never sit one
        // mis-tap away from an ordinary setting.
        _sectionLabel(t.dangerZone),
        _card(context, [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            title: Text(t.deleteAccount,
                style: const TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
            subtitle: Text(t.deleteAccountSubtitle,
                style: TextStyle(fontSize: 11.5, color: context.muted)),
            trailing: Icon(Icons.chevron_right_rounded, color: context.muted),
            onTap: () => runDeleteAccountFlow(context, ref),
          ),
        ]),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Text('Fynexa · v1.0.0',
                  style: TextStyle(color: context.muted, fontSize: 12)),
              const SizedBox(height: 4),
              Text(t.developedBy,
                  style: TextStyle(
                      color: context.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _card(BuildContext context, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(children: children),
      );

  Widget _selectorTile(BuildContext context, String label, Widget selector) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.muted, fontSize: 13)),
            const SizedBox(height: 10),
            selector,
          ],
        ),
      );

  Widget _divider(BuildContext context) =>
      Divider(height: 1, indent: 56, color: context.borderColor);

  Widget _switchTile(BuildContext context, IconData icon, String label, bool value,
          ValueChanged<bool> onChanged, {String? subtitle}) =>
      SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        secondary: Icon(icon, color: context.muted),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: TextStyle(color: context.muted, fontSize: 12.5)),
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      );

  Widget _navTile(BuildContext context, IconData icon, String label, VoidCallback onTap,
          {Color? color}) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(icon, color: color ?? context.muted),
        title: Text(label,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: color)),
        trailing: Icon(Icons.chevron_right_rounded, color: context.muted),
        onTap: onTap,
      );
}

class _ThemeSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _ThemeSelector({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final options = [
      ('LIGHT', t.themeLight, Icons.light_mode_rounded),
      ('DARK', t.themeDark, Icons.dark_mode_rounded),
      ('SYSTEM', t.themeSystem, Icons.smartphone_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((o) {
          final sel = o.$1 == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? context.colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: sel
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(o.$3, size: 20, color: sel ? AppColors.primary : context.muted),
                    const SizedBox(height: 4),
                    Text(o.$2,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? AppColors.primary : context.muted)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final String current;
  final List<(String, String)> options;
  final ValueChanged<String> onSelect;
  const _Segmented({required this.current, required this.options, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((o) {
          final sel = o.$1 == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? context.colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: sel
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
                      : null,
                ),
                child: Text(o.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: sel ? AppColors.primary : context.muted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// AI provider + model chooser with an explicit Save action (draft state,
/// loading indicator on save, success/error snackbar).
class _AiSettingsCard extends ConsumerStatefulWidget {
  const _AiSettingsCard();

  @override
  ConsumerState<_AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends ConsumerState<_AiSettingsCard> {
  String? _provider; // draft; null = follow saved value
  String? _model; // draft; null = follow saved value
  bool _saving = false;

  String _savedProvider(UserSettings? s) => (s?.aiProvider ?? 'GEMINI').toUpperCase();
  String? _savedModel(UserSettings? s, String provider) =>
      provider == 'AGENTROUTER' ? s?.agentRouterModel : s?.geminiModel;

  void _onProvider(String p, UserSettings? s) {
    setState(() {
      _provider = p;
      // Follow the model already saved for that provider (or its default).
      _model = _savedModel(s, p);
    });
  }

  Future<void> _save(String provider, String model) async {
    setState(() => _saving = true);
    final t = context.t;
    try {
      final key = provider == 'AGENTROUTER' ? 'agentRouterModel' : 'geminiModel';
      await ref.read(settingsRepositoryProvider).updateSettings({
        'aiProvider': provider,
        key: model,
      });
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      setState(() {
        _provider = null;
        _model = null;
        _saving = false;
      });
      _snack(t.aiModelSaved, AppColors.success, Icons.check_circle_rounded);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(t.saveFailed, AppColors.danger, Icons.error_outline_rounded);
    }
  }

  void _snack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ]),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(authProvider).user?.settings;
    final provider = _provider ?? _savedProvider(settings);
    final isAgent = provider == 'AGENTROUTER';
    final models = kAiModels[provider] ?? kAiModels['GEMINI']!;
    final savedModel = _savedModel(settings, provider);
    var model = _model ?? savedModel ?? models.first.$1;
    if (!models.any((m) => m.$1 == model)) model = models.first.$1;

    final dirty = provider != _savedProvider(settings) || model != savedModel;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.aiProvider, style: TextStyle(color: context.muted, fontSize: 13)),
          const SizedBox(height: 10),
          _Segmented(
            current: provider,
            options: const [('GEMINI', 'Gemini'), ('AGENTROUTER', 'AgentRouter')],
            onSelect: (v) => _onProvider(v, settings),
          ),
          const SizedBox(height: 8),
          Text(
            isAgent ? t.aiModelAgentRouterDesc : t.aiModelGeminiDesc,
            style: TextStyle(color: context.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          Text(t.aiModel, style: TextStyle(color: context.muted, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: model,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: context.colors.surface,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.muted),
                items: models
                    .map((m) => DropdownMenuItem(
                          value: m.$1,
                          child: Text(m.$2,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _model = v),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_saving || !dirty) ? null : () => _save(provider, model),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(t.save,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
