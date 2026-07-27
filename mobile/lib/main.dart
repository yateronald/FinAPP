import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/i18n/app_text.dart';
import 'core/i18n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/security/screen_security.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/formatters.dart';
import 'features/auth/presentation/app_lock_gate.dart';

import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) print('[main] WidgetsFlutterBinding initialized');

  await ScreenSecurity.enable(); // block screenshots / screen recording
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('en_US', null);
  // Allow every orientation so tablets can use landscape; the responsive
  // wrapper keeps content nicely centred and readable at any width.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  if (kDebugMode) print('[main] Pre-init done, calling runApp');

  // NOTE: NotificationService is initialized AFTER runApp (non-blocking).
  // Firebase.initializeApp() can hang on misconfigured devices and must NOT
  // block the Flutter UI from starting.
  runApp(const ProviderScope(child: FynexaApp()));

  // Initialize notifications in the background after the first frame renders.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (kDebugMode) print('[main] Post-frame: initializing NotificationService');
    try {
      await NotificationService.instance.init();
      if (kDebugMode) print('[main] NotificationService initialized OK');
    } catch (e) {
      if (kDebugMode) print('[main] NotificationService init failed: $e');
    }
  });
}

class FynexaApp extends ConsumerWidget {
  const FynexaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    // Keep date formatting in sync with the UI language.
    dateLocale = locale.languageCode == 'en' ? 'en_US' : 'fr';
    return MaterialApp.router(
      title: 'Fynexa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      routerConfig: router,
      builder: (context, child) => AppLockGate(child: child ?? const SizedBox.shrink()),
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        AppTextDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
