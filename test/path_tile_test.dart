import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/ui/components.dart';

/// A route tile lies face up in green while the route is studied and must
/// turn over again when the study time ends, or the level would be free.
void main() {
  Widget tile({bool lit = false, bool stepped = false}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 90,
        height: 70,
        child: PathTile(row: 0, column: 0, lit: lit, stepped: stepped),
      ),
    ),
  );

  testWidgets('study reveal turns the tile up, then face down again', (
    tester,
  ) async {
    await tester.pumpWidget(tile());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    await tester.pumpWidget(tile(lit: true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    await tester.pumpWidget(tile());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    // A correct step later turns the same tile up with a check.
    await tester.pumpWidget(tile(stepped: true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
