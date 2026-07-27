import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

Future<void> showEditProfileSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const EditProfileSheet(),
  );
}

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});
  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).user;
    _first = TextEditingController(text: u?.firstName ?? '');
    _last = TextEditingController(text: u?.lastName ?? '');
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(settingsRepositoryProvider).updateProfile(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
          );
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider).user?.email ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
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
            Text(context.t.editProfile,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            TextField(
              controller: _first,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.t.firstName),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _last,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.t.lastName),
            ),
            const SizedBox(height: 14),
            TextField(
              enabled: false,
              controller: TextEditingController(text: email),
              decoration: InputDecoration(
                labelText: context.t.emailReadOnly,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              ),
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
                    : Text(context.t.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
