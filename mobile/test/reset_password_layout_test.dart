import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/core/i18n/app_text.dart';
import 'package:fintrack/features/auth/presentation/reset_password_screen.dart';

/// The screen promises to fit without scrolling. A scroll view is still
/// present as a safety valve, so the assertion is not "no scrollable" but
/// "nothing to scroll": maxScrollExtent stays at zero on a real phone, and
/// nothing overflows at any size.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppTextDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ResetPasswordScreen(email: 'user@example.com'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The screen runs a periodic countdown; unmount it so the test does not end
  /// with a live timer.
  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Lets any one-shot timers left by entrance animations fire before the
    // framework's pending-timer check runs.
    await tester.pump(const Duration(seconds: 2));
  }

  double scrollExtent(WidgetTester tester) {
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    return state.position.maxScrollExtent;
  }

  testWidgets('no overflow and nothing to scroll on a tall phone',
      (tester) async {
    await pumpAt(tester, const Size(430, 932));
    expect(tester.takeException(), isNull);
    expect(scrollExtent(tester), 0);
    await teardown(tester);
  });

  testWidgets('no overflow and nothing to scroll on a tablet', (tester) async {
    await pumpAt(tester, const Size(834, 1194));
    expect(tester.takeException(), isNull);
    expect(scrollExtent(tester), 0);
    await teardown(tester);
  });

  testWidgets('short phone never overflows', (tester) async {
    // 360x640 is the floor we support; content may scroll here rather than
    // clip, which is the point of the safety valve.
    await pumpAt(tester, const Size(360, 640));
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });
}
