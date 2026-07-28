import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

Future<void> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ChangePasswordSheet(),
  );
}

class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});
  @override
  ConsumerState<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  /// True when the account has no password yet (created via Google).
  bool get _settingFirst => !(ref.read(authProvider).user?.hasPassword ?? true);
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final firstTime = !(ref.read(authProvider).user?.hasPassword ?? true);
      await ref
          .read(settingsRepositoryProvider)
          .changePassword(firstTime ? null : _current.text, _next.text);
      // The account now has a password too — refresh so Settings stops
      // offering "Set a password".
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.passwordUpdated)),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.borderColor, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              Text(_settingFirst ? context.t.setPassword : context.t.changePassword,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              if (_settingFirst) ...[
                const SizedBox(height: 8),
                Text(context.t.setPasswordSubtitle,
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: context.muted)),
              ],
              const SizedBox(height: 18),
              // A Google-created account has no current password to confirm.
              if (!_settingFirst)
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: context.t.currentPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? context.t.required : null,
              ),
              if (!_settingFirst) const SizedBox(height: 14),
              TextFormField(
                controller: _next,
                obscureText: _obscure,
                decoration: InputDecoration(labelText: context.t.newPassword),
                validator: (v) {
                  if (v == null || v.length < 8) return context.t.pwMin;
                  if (!RegExp(r'[A-Z]').hasMatch(v)) return context.t.pwUpper;
                  if (!RegExp(r'[0-9]').hasMatch(v)) return context.t.pwDigit;
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: InputDecoration(labelText: context.t.confirmPassword),
                validator: (v) => v != _next.text ? context.t.pwMismatch : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(context.t.update),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
