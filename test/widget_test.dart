import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scales_mobile/main.dart';
import 'package:scales_mobile/presentation/screens/singer/singer_profile_screen.dart';
import 'package:scales_mobile/presentation/screens/check_in/check_in_screen.dart';
import 'package:scales_mobile/presentation/screens/leaderboard/leaderboard_screen.dart';

void main() {
  testWidgets('ScalesApp displays splash on first frame', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ScalesApp()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SingerProfileScreen renders with providers', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SingerProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Profile screen should eventually display the singer name
    expect(find.textContaining('Alex Singer'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('CheckInScreen shows venue code input', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CheckInScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter Venue Code'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('LeaderboardScreen renders with mock data', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LeaderboardScreen(venueId: 'test_venue')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Alex Singer'), findsOneWidget);
    expect(find.text('1240 pts'), findsOneWidget);
  });
}
