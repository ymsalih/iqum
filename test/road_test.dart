import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/ui/level_road.dart';

void main() {
  for (final level in [1, 7, 30]) {
    testWidgets('Road ascends and opens at level $level on a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 272,
                height: 340,
                child: LevelRoad(level: level, onSelect: (n) => selected = n),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getCenter(find.byKey(const ValueKey('level-1')));
      final second = tester.getCenter(find.byKey(const ValueKey('level-2')));
      expect(second.dy, lessThan(first.dy));
      final current = find.byKey(ValueKey('level-$level'));
      final viewport = tester.getRect(
        find.byKey(const ValueKey('level-road-scroll')),
      );
      expect(viewport.contains(tester.getCenter(current)), isTrue);
      await tester.tap(current);
      await tester.pumpAndSettle();
      expect(selected, level);
      if (level < 30) {
        expect(
          tester
              .widget<FilledButton>(find.byKey(ValueKey('level-${level + 1}')))
              .onPressed,
          isNull,
        );
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
