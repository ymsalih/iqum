import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/ui/components.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('Open cards rotate on entry; reduced motion=$reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Center(
              child: SizedBox(
                width: 80,
                height: 100,
                child: MemoryTile(index: 0, animal: 'kedi', open: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 180));
      final matrix = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(MemoryTile),
              matching: find.byType(Transform),
            ),
          )
          .firstWhere((widget) => widget.transform.entry(3, 2) != 0)
          .transform;
      if (reduced) {
        expect(matrix.entry(0, 0), closeTo(1, .001));
      } else {
        expect(matrix.entry(0, 0).abs(), lessThan(.95));
        expect(matrix.entry(2, 0).abs(), greaterThan(.1));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
