import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:iqum/main.dart';
import 'package:iqum/application/app_controller.dart';
import 'package:iqum/data/backend.dart';
import 'package:iqum/data/local_store.dart';
import 'package:iqum/domain/models.dart';
import 'package:iqum/ui/components.dart';
import 'package:iqum/ui/solo_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: three games, heart loss, progression and restart persistence',
    (tester) async {
      final file = p.join(
        await getDatabasesPath(),
        'iqum_integration_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      var store = await LocalStore.open(path: file);
      var controller = AppController(store, OfflineBackend());
      await controller.restore();
      await controller.settings(sound: false, haptics: false);
      Future<void> mount() async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [appProvider.overrideWith((ref) => controller)],
            child: const IqumApp(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> screenshot(String name) async {
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      }

      try {
        await mount();
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        expect(find.text('Biraz odak.\nBir adım ileri.'), findsOneWidget);
        await screenshot('home');
        await tester.tap(find.text('Devam et'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yolu ezberle'));
        await tester.pump(const Duration(milliseconds: 400));
        await screenshot('path-preview');
        await tester.pump(const Duration(milliseconds: 9200));
        final wrong = find
            .byWidgetPredicate(
              (w) =>
                  w is PathTile &&
                  w.row == 0 &&
                  w.column != 1 &&
                  w.onTap != null,
            )
            .first;
        await tester.tap(wrong);
        await tester.pump(const Duration(milliseconds: 1200));
        expect(controller.progress.life.count, 3);
        await tester.tap(find.text('Yolu ezberle'));
        await tester.pump(const Duration(milliseconds: 9200));
        final route = LevelDefinition(1).route;
        for (var row = 0; row < route.length; row++) {
          await tester.tap(
            find.byWidgetPredicate(
              (w) =>
                  w is PathTile &&
                  w.row == row &&
                  w.column == route[row] &&
                  w.onTap != null,
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));
          if (row == 1) await screenshot('path-walking');
        }
        await tester.pumpAndSettle();
        expect(find.byType(ResultScreen), findsOneWidget);
        expect(controller.progress.level, 2);
        expect(controller.progress.completedLevels, 1);
        await tester.tap(find.text('Ana sayfaya dön'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Antrenman').first);
        await tester.tap(find.text('Antrenman').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kartları göster'));
        await tester.pump(const Duration(milliseconds: 400));
        final sequence = tester
            .widgetList<MemoryTile>(find.byType(MemoryTile))
            .toList();
        final first = sequence[0].animal!,
            incorrect = animals.keys.firstWhere((a) => a != sequence[1].animal);
        await screenshot('sequence-preview');
        await tester.pump(const Duration(milliseconds: 6200));
        Finder choice(String key) => find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == animals[key] &&
              w.properties.button == true,
        );
        await tester.tap(choice(first));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(choice(incorrect));
        await tester.pumpAndSettle();
        expect(find.text('Sonraki tur'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        final saved = await store.readSession(
          controller.scope,
          GameKind.sequence,
        );
        expect(saved!['total'], 1);
        await tester.ensureVisible(find.text('Antrenman').last);
        await tester.tap(find.text('Antrenman').last);
        await tester.pumpAndSettle();
        final tiles = tester
            .widgetList<MemoryTile>(find.byType(MemoryTile))
            .toList();
        final keys = tiles.map((t) => t.animal!).toSet().toList();
        for (var n = 0; n < keys.length; n++) {
          final pair = tiles
              .where((t) => t.animal == keys[n])
              .map((t) => t.index)
              .toList();
          for (final index in pair) {
            await tester.tap(
              find.byWidgetPredicate(
                (w) => w is MemoryTile && w.index == index,
              ),
            );
            await tester.pump(const Duration(milliseconds: 120));
          }
          await tester.pump(const Duration(milliseconds: 800));
          if (n == 0) await screenshot('matching');
        }
        await tester.pumpAndSettle();
        expect(find.byType(ResultScreen), findsOneWidget);
        expect(controller.progress.matchingBestAttempts, 8);
        expect(controller.progress.points, 0);
        await screenshot('result');
        await tester.tap(find.text('Ana sayfaya dön'));
        await tester.pumpAndSettle();
        final scope = controller.scope;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await store.close();
        store = await LocalStore.open(path: file);
        controller = AppController(store, OfflineBackend());
        await controller.restore();
        expect(controller.scope, scope);
        expect(controller.progress.level, 2);
        expect(controller.progress.life.count, 3);
        expect(controller.progress.matchingBestAttempts, 8);
        expect(
          (await store.readSession(scope, GameKind.sequence))!['total'],
          1,
        );
        await mount();
        await screenshot('home-restored');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        controller.dispose();
        await store.close();
        await deleteDatabase(file);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
