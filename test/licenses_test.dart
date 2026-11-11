import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/ui/licenses_screen.dart';
import 'package:iqum/ui/theme.dart';

/// The open-source notices page lists every registered package once,
/// sorted, and opens its full notice. IQUM_SCREENSHOTS saves a picture.
void main() {
  setUpAll(() {
    LicenseRegistry.addLicense(
      () => Stream.fromIterable([
        const LicenseEntryWithLineBreaks([
          'zeta_pkg',
        ], 'Permission is hereby granted, free of charge, to any person.'),
        const LicenseEntryWithLineBreaks([
          'alpha_pkg',
          'zeta_pkg',
        ], 'Apache License\nVersion 2.0'),
      ]),
    );
  });

  testWidgets('packages are listed once and open their notice', (tester) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: AppColors.theme,
          home: const LicensesScreen(),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('alpha_pkg'), findsOneWidget);
    expect(find.text('zeta_pkg'), findsOneWidget);
    // Real Flutter notices are registered too; check our own package's row.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('alpha_pkg'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('Apache lisansı'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('alpha_pkg')).dy,
      lessThan(tester.getTopLeft(find.text('zeta_pkg')).dy),
    );
    final shots = Platform.environment['IQUM_SCREENSHOTS'];
    if (shots != null) {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      Directory(shots).createSync(recursive: true);
      File('$shots/licenses.png').writeAsBytesSync(png!.buffer.asUint8List());
    }
    await tester.tap(find.text('zeta_pkg'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permission is hereby granted'), findsOneWidget);
    expect(find.textContaining('Version 2.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
