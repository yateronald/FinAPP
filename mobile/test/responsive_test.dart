import 'package:fintrack/core/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool> usesCompactLayout(
    WidgetTester tester, {
    required double width,
    double textScale = 1,
  }) async {
    var compact = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 700),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Builder(
            builder: (context) {
              compact = context.useCompactLayout;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return compact;
  }

  testWidgets('uses compact layout below 360 logical pixels', (tester) async {
    expect(await usesCompactLayout(tester, width: 359), isTrue);
    expect(await usesCompactLayout(tester, width: 400), isFalse);
  });

  testWidgets('reflows ordinary phones when system text is enlarged', (
    tester,
  ) async {
    expect(
      await usesCompactLayout(tester, width: 400, textScale: 1.25),
      isTrue,
    );
  });
}
