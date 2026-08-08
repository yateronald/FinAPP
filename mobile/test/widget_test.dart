import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/core/widgets/brand_logo.dart';

void main() {
  testWidgets('Brand logo renders the Fynexa wordmark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandLogo())),
      ),
    );
    expect(find.text('Fynexa'), findsOneWidget);
  });
}
