import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:iqum/main.dart';
import 'package:iqum/application/app_controller.dart';
import 'package:iqum/data/backend.dart';
import 'package:iqum/data/local_store.dart';
import 'package:iqum/domain/models.dart';

/// Walks every main screen on phones from 320 dp to tablets, at normal and
/// 1.3× text, with the real bundled fonts so measurements match devices.
/// Set the IQUM_SCREENSHOTS folder variable to also save PNGs of each screen.
Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  await (FontLoader('Baloo2')
        ..addFont(bytes('assets/fonts/Baloo2-SemiBold.ttf'))
        ..addFont(bytes('assets/fonts/Baloo2-ExtraBold.ttf')))
      .load();
  await (FontLoader('Nunito')
        ..addFont(bytes('assets/fonts/Nunito-Medium.ttf'))
        ..addFont(bytes('assets/fonts/Nunito-Bold.ttf'))
        ..addFont(bytes('assets/fonts/Nunito-ExtraBold.ttf')))
      .load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (root != null && icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(bytes(icons.path))).load();
  }
}

const sizes = [
  Size(320, 568), // iPhone SE (1st gen) / small Android
  Size(360, 640),
  Size(390, 844),
  Size(430, 932),
  Size(768, 1024), // iPad portrait
  Size(1024, 1366), // iPad Pro portrait
];

void main() {
  late LocalStore store;
  late AppController controller;
  final shots = Platform.environment['IQUM_SCREENSHOTS'];
  final boundary = GlobalKey();
  setUpAll(() async {
    sqfliteFfiInit();
    await _loadFonts();
  });
  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    controller = AppController(store, OfflineBackend());
    await controller.restore();
    // No audio plugin in widget tests; haptics are harmless.
    await controller.settings(sound: false);
  });
  tearDown(() async => store.close());

  for (final size in sizes) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'All screens fit ${size.width.toInt()}×${size.height.toInt()} '
        'at text ×$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          Future<void> check(String name) async {
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$name @ $size ×$scale',
            );
            if (shots == null || scale != 1.0) return;
            await tester.runAsync(() async {
              for (final element in find.byType(Image).evaluate()) {
                final image = (element.widget as Image).image;
                await precacheImage(image, element);
              }
            });
            await tester.pumpAndSettle();
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final png = await tester.runAsync(() async {
              final image = await render.toImage(pixelRatio: 2);
              return image.toByteData(format: ui.ImageByteFormat.png);
            });
            Directory(shots).createSync(recursive: true);
            File(
              '$shots/${size.width.toInt()}x${size.height.toInt()}-$name.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
          }

          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: ProviderScope(
                overrides: [appProvider.overrideWith((ref) => controller)],
                child: const IqumApp(),
              ),
            ),
          );
          await check('home');

          // Game screens read their saved session from SQLite (real I/O).
          Future<void> io() async {
            for (var i = 0; i < 5; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 60)),
              );
              await tester.pump();
            }
          }

          Future<void> back() async {
            tester.state<NavigatorState>(find.byType(Navigator).first).pop();
            await tester.pumpAndSettle();
          }

          await tester.ensureVisible(find.text('Leveller'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Leveller'));
          await check('levels');
          expect(find.byKey(const ValueKey('level-road-scroll')), findsOne);
          await back();

          await tester.tap(find.text('Profil').last);
          await check('profile');
          await tester.tap(find.text('Düello').last);
          await check('duel');
          await tester.tap(find.text('Oyna').last);
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.text('Antrenman').first);
          await tester.tap(find.text('Antrenman').first);
          await io();
          await check('sequence');
          await tester.tap(find.text('Kartları göster'));
          await io();
          await tester.pump(const Duration(milliseconds: 500));
          await check('sequence-preview');
          await tester.pump(const Duration(seconds: 7));
          await check('sequence-answer');
          await back();

          await tester.ensureVisible(find.text('Antrenman').last);
          await tester.tap(find.text('Antrenman').last);
          await io();
          await tester.pumpAndSettle();
          final tiles = tester.widgetList<Widget>(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == 'MemoryTile',
            ),
          );
          expect(tiles.length, 16);
          await tester.tap(
            find
                .byWidgetPredicate(
                  (w) => w.runtimeType.toString() == 'MemoryTile',
                )
                .first,
          );
          await check('matching');
          await back();

          await tester.ensureVisible(find.text('Devam et'));
          await tester.tap(find.text('Devam et'));
          await io();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Yolu ezberle'));
          await io();
          await tester.pump(const Duration(milliseconds: 400));
          await check('path-preview');
          await tester.pump(const Duration(seconds: 10));
          await check('path');
          expect(controller.progress.level, 1);
          await back();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  test('level layouts used for board fitting stay in range', () {
    for (var n = 1; n <= 30; n++) {
      final l = LevelDefinition(n);
      expect(l.columns * 1.45 / l.rows, inInclusiveRange(.5, 1.5));
    }
  });
}
