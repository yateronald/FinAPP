import 'package:fintrack/core/i18n/app_text.dart';
import 'package:fintrack/core/theme/app_theme.dart';
import 'package:fintrack/features/auth/presentation/auth_widgets.dart';
import 'package:fintrack/features/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget preview(ThemeData theme) => MaterialApp(
    theme: theme,
    home: Scaffold(
      body: AuthBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 320,
                child: Column(
                  children: [
                    const AuthFeatureStrip(
                      features: [
                        AuthFeatureData(
                          icon: Icons.shield_outlined,
                          title: 'Secure',
                          body: 'Data protected',
                        ),
                        AuthFeatureData(
                          icon: Icons.lock_outline,
                          title: 'Private',
                          body: 'Private and confidential',
                        ),
                        AuthFeatureData(
                          icon: Icons.bolt_outlined,
                          title: 'Smart',
                          body: 'Smart financial insights',
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    AuthPanel(
                      icon: Icons.person,
                      child: Column(
                        children: [
                          AuthMethodButton(
                            emphasized: true,
                            leading: const Icon(
                              Icons.mail,
                              color: Colors.white,
                            ),
                            label: 'Continue with your credentials',
                            subtitle: 'Use your email address and password',
                            onTap: () {},
                          ),
                          const SizedBox(height: 14),
                          const AuthSecurityBanner(
                            title: 'Bank-grade protection',
                            body: 'Your data is encrypted and protected.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('authentication presentation renders in light and dark themes', (
    tester,
  ) async {
    await tester.pumpWidget(preview(AppTheme.light));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(preview(AppTheme.dark));
    expect(tester.takeException(), isNull);
  });

  test('new authentication copy is available in English and French', () {
    const en = AppText('en');
    const fr = AppText('fr');

    expect(en.loginWelcome, 'Welcome back!');
    expect(fr.loginWelcome, 'Bon retour !');
    expect(en.authSecurityTitle, 'Bank-grade protection');
    expect(fr.authSecurityTitle, 'Protection de niveau bancaire');
    expect(fr.featPrivateBody, 'Confidentiel et privé');
    expect(fr.featSmartBody, 'Conseils intelligents');
  });

  testWidgets('hero illustration follows the selected language', (
    tester,
  ) async {
    Future<String> heroAssetFor(Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: AuthHeroImage()),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image).first);
      return (image.image as AssetImage).assetName;
    }

    expect(
      await heroAssetFor(const Locale('en')),
      'img/english_login_register.png',
    );
    expect(
      await heroAssetFor(const Locale('fr')),
      'img/french_login_register.png',
    );
  });

  testWidgets('compact hero keeps content and illustration separate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AuthHero(
              height: 192,
              left: Container(key: const Key('hero-left'), color: Colors.red),
            ),
          ),
        ),
      ),
    );

    final left = tester.getRect(find.byKey(const Key('hero-left')));
    final illustration = tester.getRect(find.byType(Image).first);
    expect(left.right, lessThanOrEqualTo(illustration.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration features remain above the authentication panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            AppTextDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final features = tester.getRect(
      find.byKey(const Key('register-feature-cards')),
    );
    final panel = tester.getRect(find.byKey(const Key('register-auth-panel')));
    expect(features.bottom, lessThan(panel.top));
    expect(tester.takeException(), isNull);
  });
}
