import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';

/// The app locale, driven by the signed-in user's `settings.language`
/// (FR/EN — same source as the web app). Before sign-in, falls back to the
/// device language (English if the phone is English, otherwise French).
final localeProvider = Provider<Locale>((ref) {
  final lang = ref.watch(authProvider).user?.settings?.language;
  if (lang != null) {
    return Locale(lang.toUpperCase() == 'EN' ? 'en' : 'fr');
  }
  // First launch: French phone → French; everything else defaults to English.
  final system = PlatformDispatcher.instance.locale.languageCode;
  return Locale(system == 'fr' ? 'fr' : 'en');
});
