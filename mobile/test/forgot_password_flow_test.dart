import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/core/i18n/app_text.dart';
import 'package:fintrack/core/network/api_client.dart';
import 'package:fintrack/features/auth/presentation/forgot_password_dialog.dart';

/// The reported bug: the dialog closed the moment the address was submitted,
/// so the login screen came back into view while the code was still being
/// sent, and only then did the code screen appear.
///
/// These pin the fix — the dialog owns the whole send — and the security rule
/// that makes the flow safe to show progress for in the first place.
void main() {
  Widget host({
    required Future<ForgotPasswordResult> Function(String) onSubmit,
    required void Function(String?) onClosed,
  }) =>
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          AppTextDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  onClosed(await showForgotPasswordDialog(
                    context,
                    initialEmail: 'jean@exemple.com',
                    onSubmit: onSubmit,
                  ));
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> openAndSubmit(
    WidgetTester tester, {
    required Future<ForgotPasswordResult> Function(String) onSubmit,
    required void Function(String?) onClosed,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(onSubmit: onSubmit, onClosed: onClosed));
    // The localisation delegates resolve asynchronously; nothing is built
    // until they have.
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer le code'));
    await tester.pump();
  }

  testWidgets('stays open while the code is being sent', (tester) async {
    final gate = Completer<ForgotPasswordResult>();
    String? closedWith;
    var settled = false;

    await openAndSubmit(
      tester,
      onSubmit: (_) => gate.future,
      onClosed: (v) {
        closedWith = v;
        settled = true;
      },
    );

    // Mid-flight: the dialog is still up, showing progress — this is exactly
    // what used to be missing.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Envoi en cours…'), findsOneWidget);
    expect(settled, isFalse, reason: 'must not resolve before the send returns');

    gate.complete(const ForgotPasswordResult.sent());
    await tester.pump();

    // Confirmation appears in the same card before anything navigates.
    expect(find.text('Code envoyé'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(closedWith, 'jean@exemple.com');
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('a throttled send keeps the dialog open with a countdown',
      (tester) async {
    String? closedWith;
    var settled = false;

    await openAndSubmit(
      tester,
      onSubmit: (_) async =>
          const ForgotPasswordResult.throttled(retryAfterSeconds: 90),
      onClosed: (v) {
        closedWith = v;
        settled = true;
      },
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('1 min 30'), findsOneWidget);
    expect(settled, isFalse);
    expect(closedWith, isNull);
  });

  testWidgets('an offline send says so instead of claiming success',
      (tester) async {
    await openAndSubmit(
      tester,
      onSubmit: (_) async => const ForgotPasswordResult.offline(),
      onClosed: (_) {},
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune connexion'), findsOneWidget);
    expect(find.text('Code envoyé'), findsNothing);
  });

  group('sendResetCode never reveals whether an address has an account', () {
    // Showing progress is only safe because the answer is identical either
    // way. These pin that: every server response other than throttling has to
    // come back as `sent`, so nothing observable distinguishes a registered
    // address from one that has never been seen.
    test('a successful send reports sent', () async {
      final r = await sendResetCode(() async {});
      expect(r.outcome, ForgotPasswordOutcome.sent);
    });

    test('an unknown account reports sent, not "not found"', () async {
      final r = await sendResetCode(
        () async => throw ApiException('No such user', 404, 'ACCOUNT_NOT_FOUND'),
      );
      expect(r.outcome, ForgotPasswordOutcome.sent);
    });

    test('an unverified address reports sent', () async {
      final r = await sendResetCode(
        () async =>
            throw ApiException('Not verified', 403, 'EMAIL_NOT_VERIFIED'),
      );
      expect(r.outcome, ForgotPasswordOutcome.sent);
    });

    test('a server fault reports sent', () async {
      final r = await sendResetCode(
        () async => throw ApiException('Boom', 500),
      );
      expect(r.outcome, ForgotPasswordOutcome.sent);
    });

    test('a non-API error reports sent', () async {
      final r = await sendResetCode(() async => throw StateError('boom'));
      expect(r.outcome, ForgotPasswordOutcome.sent);
    });

    test('throttling is surfaced, with its retry delay', () async {
      final r = await sendResetCode(
        () async => throw ApiException(
            'Too many', 429, 'OTP_RESEND_LIMIT', null, null, 120),
      );
      expect(r.outcome, ForgotPasswordOutcome.throttled);
      expect(r.retryAfterSeconds, 120);
    });

    test('an unreachable server is surfaced as offline', () async {
      // No status code means the request never landed — telling the user is
      // useful and says nothing about the address.
      final r = await sendResetCode(() async => throw ApiException('No route'));
      expect(r.outcome, ForgotPasswordOutcome.offline);
    });
  });

  for (final size in const [Size(320, 640), Size(430, 932), Size(834, 1194)]) {
    testWidgets('every phase fits at ${size.width.toInt()}pt', (tester) async {
      // The sending and confirmation states are new surfaces, and the French
      // strings on them are the long ones. Both are checked here rather than
      // only the form the dialog opens on.
      final gate = Completer<ForgotPasswordResult>();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(onSubmit: (_) => gate.future, onClosed: (_) {}),
      );
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'form phase');

      // The send button is the whole point of the dialog: it has to be on
      // screen without scrolling, including on a short phone where the
      // illustration is dropped to make room for it.
      final button = tester.getRect(find.text('Envoyer le code'));
      expect(
        button.bottom,
        lessThanOrEqualTo(size.height),
        reason: 'send button must not sit below the fold at ${size.height}pt',
      );

      await tester.tap(find.text('Envoyer le code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'sending phase');

      gate.complete(const ForgotPasswordResult.sent());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'confirmation phase');

      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  }

  testWidgets('rejects a malformed address without calling the server',
      (tester) async {
    var called = false;
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(
      onSubmit: (_) async {
        called = true;
        return const ForgotPasswordResult.sent();
      },
      onClosed: (_) {},
    ));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pas-une-adresse');
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.byType(Dialog), findsOneWidget);
  });
}
