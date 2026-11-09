import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/ui/components.dart';
import 'package:iqum/ui/premium_motion.dart';

void main() {
  testWidgets(
    'Spring press activates once, settles, and busy buttons stay disabled',
    (tester) async {
      var calls = 0;
      Widget page(bool busy) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: IqumButton('Devam', busy: busy, onPressed: () => calls++),
          ),
        ),
      );
      await tester.pumpWidget(page(false));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FilledButton)),
      );
      await tester.pump();
      await tester.pump(MotionTokens.press);
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(SpringPress),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.entry(0, 0), lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(page(true));
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Feedback and celebration respect reduced motion; counters retain the true score',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ResultCelebration(
                enabled: true,
                child: StepFeedback(
                  wrong: true,
                  correct: false,
                  child: const ScoreNumber(8, suffix: ' / 8'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('8 / 8'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('A success celebration disappears and does not loop', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultCelebration(
            enabled: true,
            child: SizedBox(width: 200, height: 300),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
