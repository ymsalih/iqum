import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/ui/components.dart';
import 'package:iqum/ui/premium_motion.dart';

/// A pair's result must not show before its second card has turned over:
/// the card that was already open waits one full flip too.
void main() {
  Widget tile({bool wrong = false, bool matched = false}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 80,
        height: 100,
        child: MemoryTile(index: 0, open: true, wrong: wrong, matched: matched),
      ),
    ),
  );

  testWidgets('a miss is shown only after the partner card has turned', (
    tester,
  ) async {
    await tester.pumpWidget(tile());
    await tester.pumpAndSettle();
    await tester.pumpWidget(tile(wrong: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    await tester.pump(MotionTokens.flip);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a match is shown only after the partner card has turned', (
    tester,
  ) async {
    await tester.pumpWidget(tile());
    await tester.pumpAndSettle();
    await tester.pumpWidget(tile(matched: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.pump(MotionTokens.flip);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a restored matched card shows its result at once', (
    tester,
  ) async {
    await tester.pumpWidget(tile(matched: true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
