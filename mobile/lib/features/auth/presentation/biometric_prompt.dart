import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../settings/providers/settings_provider.dart';

/// Offers biometric app-lock once, after the user's first sign-in.
///
/// Silently does nothing when the prompt has already been shown, the lock is
/// already on, or the device has no enrolled biometrics — the user can always
/// turn it on later from Settings. Declining is remembered, so this never
/// becomes a recurring nag.
Future<void> maybeOfferBiometricEnrolment(
  BuildContext context,
  WidgetRef ref,
) async {
  final storage = SecureStorage.instance;

  if (await storage.biometricPrompted) return;
  if (await storage.biometricEnabled) return;

  final auth = LocalAuthentication();
  bool available = false;
  try {
    available = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    if (available) {
      // No enrolled fingerprint/face → offering it would only lead to a
      // confusing failure.
      available = (await auth.getAvailableBiometrics()).isNotEmpty;
    }
  } catch (_) {
    available = false;
  }
  if (!available) {
    // Nothing to offer on this device; don't ask again.
    await storage.markBiometricPrompted();
    return;
  }

  if (!context.mounted) return;
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _BiometricEnrolmentDialog(),
  );

  // Whatever they chose, we asked.
  await storage.markBiometricPrompted();
  if (accepted != true) return;

  final t = context.mounted ? context.t : null;
  try {
    final ok = await auth.authenticate(
      localizedReason: t?.biometricOnEach ?? 'Unlock to confirm',
      persistAcrossBackgrounding: true,
      biometricOnly: true,
    );
    if (!ok) return;
    await ref.read(biometricEnabledProvider.notifier).set(true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.biometricEnabled)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.biometricFailed)),
      );
    }
  }
}

class _BiometricEnrolmentDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.22),
              AppColors.primary.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.fingerprint_rounded,
            color: AppColors.primary, size: 32),
      ),
      title: Text(
        t.biometricPromptTitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
      ),
      content: Text(
        t.biometricPromptBody,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13.5, height: 1.45),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(t.biometricPromptLater),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.fingerprint_rounded, size: 18),
          label: Text(t.biometricPromptEnable),
        ),
      ],
    );
  }
}
