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
import 'package:iqum/ui/components.dart';
import 'package:iqum/ui/solo_screen.dart';

/// Store screenshots from the real app screens, at the sizes both stores
/// ask for. Runs only when IQUM_STORE_SHOTS names an output folder:
///   IQUM_STORE_SHOTS=store_assets/screenshots flutter test test/store_screenshots_test.dart
/// The player is a guest with some cleared levels; no account data appears.
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

/// Output pixels and device pixel ratio (logical size = pixels / ratio).
const _devices = [
  ('android-phone', Size(1080, 1920), 1080 / 412), // a 412 dp wide phone
  ('ios-iphone-6.9', Size(1320, 2868), 3.0), // 440 × 956 pt
  ('ios-ipad-13', Size(2064, 2752), 2.0), // 1032 × 1376 pt
];

void main() {
  final out = Platform.environment['IQUM_STORE_SHOTS'];
  late LocalStore store;
  late AppController controller;
  var fakeNow = 1762790400000;
  setUpAll(() async {
    sqfliteFfiInit();
    await _loadFonts();
  });
  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final scope = await store.guestScope();
    await store.saveProgress(
      scope,
      PlayerProgress(
        life: LifeState(observedAt: fakeNow),
        level: 7,
        completedLevels: 6,
        sequenceLevel: 6,
        matchingLevel: 9,
        stars: {'path': '332323', 'sequence': '33322', 'matching': '33232333'},
        stats: const {
          'path': GameStats(played: 9, cleared: 6, failed: 3, perfect: 3),
          'sequence': GameStats(
            played: 7,
            cleared: 5,
            failed: 2,
            timeMs: 412000,
            perfect: 3,
          ),
          'matching': GameStats(
            played: 10,
            cleared: 8,
            failed: 2,
            timeMs: 905000,
            perfect: 5,
          ),
        },
        sequenceBest: 5,
        sound: false,
        haptics: false,
      ),
    );
    controller = AppController(store, OfflineBackend(), clock: () => fakeNow);
    await controller.restore();
  });
  tearDown(() async => store.close());

  for (final (name, size, ratio) in _devices) {
    testWidgets('store screenshots: $name', skip: out == null, (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      var index = 0;

      Future<void> io() async {
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
        }
      }

      Future<void> wait(Duration d) async {
        fakeNow += d.inMilliseconds;
        await tester.pump(d);
      }

      Future<void> shot(String label) async {
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            await precacheImage((element.widget as Image).image, element);
          }
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final png = await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: ratio);
          return image.toByteData(format: ui.ImageByteFormat.png);
        });
        index++;
        final dir = Directory('$out/$name')..createSync(recursive: true);
        File(
          '${dir.path}/${index.toString().padLeft(2, '0')}-$label.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        expect(tester.takeException(), isNull, reason: label);
      }

      NavigatorState nav() =>
          tester.state<NavigatorState>(find.byType(Navigator).first);
      Future<void> open(Widget screen) async {
        nav().push(MaterialPageRoute<void>(builder: (_) => screen));
        await io();
        await tester.pumpAndSettle();
      }

      Future<void> back() async {
        nav().popUntil((r) => r.isFirst);
        await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      await shot('ana-sayfa');

      await tester.ensureVisible(find.text('Leveller'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leveller'));
      await tester.pumpAndSettle();
      await shot('level-haritasi');
      await back();

      // Memory Path: the route on its own card, before it is taken away.
      await open(const SoloScreen(GameKind.path, level: 7));
      // The route shows by itself after the 3-2-1 countdown.
      await wait(const Duration(milliseconds: 2200));
      await io();
      await wait(const Duration(milliseconds: 700));
      await shot('hafiza-yolu');
      await back();

      // Sequence Memory: the study phase.
      await open(const SoloScreen(GameKind.sequence, level: 6));
      // The cards show by itself after the 3-2-1 countdown.
      await wait(const Duration(milliseconds: 2200));
      await io();
      await wait(const Duration(milliseconds: 900));
      await shot('sira-hafizasi');
      await back();

      // Card Matching: three pairs found, one card turned over.
      await open(const SoloScreen(GameKind.matching, level: 13));
      List<MemoryTile> tiles() =>
          tester.widgetList<MemoryTile>(find.byType(MemoryTile)).toList();
      Future<void> tapTile(int i) async {
        await tester.tap(
          find.byWidgetPredicate((w) => w is MemoryTile && w.index == i),
        );
        await wait(const Duration(milliseconds: 120));
      }

      final board = tiles();
      final animals = board.map((t) => t.animal!).toSet().toList();
      for (final animal in animals.take(3)) {
        final pair = [
          for (final t in board)
            if (t.animal == animal) t.index,
        ];
        await tapTile(pair[0]);
        await tapTile(pair[1]);
        await wait(const Duration(milliseconds: 800));
      }
      final lone = board.firstWhere((t) => t.animal == animals[4]).index;
      await tapTile(lone);
      await wait(const Duration(milliseconds: 500));
      await shot('kart-eslestirme');
      await back();

      // A real cleared level: three pairs without a miss, three stars.
      await open(const SoloScreen(GameKind.matching, level: 1));
      final small = tiles();
      for (final animal in small.map((t) => t.animal!).toSet()) {
        final pair = [
          for (final t in small)
            if (t.animal == animal) t.index,
        ];
        await tapTile(pair[0]);
        await tapTile(pair[1]);
        await wait(const Duration(milliseconds: 800));
      }
      await io();
      await tester.pumpAndSettle();
      expect(find.byType(ResultScreen), findsOneWidget);
      await shot('sonuc');
      await back();

      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
      // Statistics heading at the top of the screen.
      final heading = find.text('İstatistikler');
      await tester.scrollUntilVisible(
        heading,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(tester.element(heading), alignment: .03);
      await tester.pumpAndSettle();
      await shot('istatistikler');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
