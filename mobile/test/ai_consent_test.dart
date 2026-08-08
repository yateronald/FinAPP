import 'package:fintrack/core/i18n/app_text.dart';
import 'package:fintrack/core/theme/app_theme.dart';
import 'package:fintrack/features/ai/presentation/ai_access.dart';
import 'package:fintrack/features/auth/data/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI is disabled when a settings payload omits the opt-in flag', () {
    final settings = UserSettings.fromJson(const {
      'language': 'EN',
      'currency': 'XOF',
      'theme': 'SYSTEM',
    });

    expect(settings.aiEnabled, isFalse);
    expect(settings.aiConsentAt, isNull);
    expect(settings.aiConsentVersion, isNull);
  });

  test('AI consent metadata is parsed when the user has opted in', () {
    final settings = UserSettings.fromJson(const {
      'language': 'FR',
      'currency': 'XOF',
      'theme': 'DARK',
      'aiEnabled': true,
      'aiConsentAt': '2026-08-08T12:00:00.000Z',
      'aiConsentVersion': '1.0',
    });

    expect(settings.aiEnabled, isTrue);
    expect(settings.aiConsentAt, DateTime.utc(2026, 8, 8, 12));
    expect(settings.aiConsentVersion, '1.0');
  });

  test('AI opt-in disclosure is available in English and French', () {
    const en = AppText('en');
    const fr = AppText('fr');

    expect(en.aiConsentTitle, 'Enable AI Assistant?');
    expect(fr.aiConsentTitle, 'Activer l’assistant IA ?');
    expect(en.aiConsentCheckbox, contains('I understand and agree'));
    expect(fr.aiConsentCheckbox, contains('Je comprends et j’accepte'));
    expect(en.aiOffSubtitle, contains('no data is sent'));
    expect(fr.aiOffSubtitle, contains('aucune donnée n’est envoyée'));
  });

  testWidgets(
    'disabled AI and disclosure fit a small phone in light and dark',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pump(ThemeData theme) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: const [Locale('en'), Locale('fr')],
              localizationsDelegates: const [
                AppTextDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: theme,
              home: const Scaffold(body: AiDisabledState()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(AppTheme.light);
      expect(find.text('AI Assistant is off'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Review and enable AI'));
      await tester.pumpAndSettle();
      expect(find.text('Enable AI Assistant?'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pump(AppTheme.dark);
      expect(find.text('AI Assistant is off'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
