// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in the test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scales_mobile/main.dart';

void main() {
  testWidgets('ScalesApp displays splash on first frame', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ScalesApp()));
    await tester.pump();

    // Splash screen should show loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
