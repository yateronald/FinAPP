import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Derives the app ThemeMode from the signed-in user's stored preference,
/// defaulting to system when unknown.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final theme = ref.watch(authProvider).user?.settings?.theme;
  switch (theme) {
    case 'LIGHT':
      return ThemeMode.light;
    case 'DARK':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
});
