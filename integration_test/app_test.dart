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
        // Starts by itself after the 3-2-1 countdown.
        await tester.pump(const Duration(milliseconds: 2400));
        await tester.pump(const Duration(milliseconds: 600));
        await screenshot('path-preview');
        final preview = Duration(milliseconds: LevelDefinition(1).previewMs);
        await tester.pump(preview);
        final wrong = find
            .byWidgetPredicate(
              (w) =>
                  w is PathTile &&
                  w.row == 0 &&
                  w.column != LevelDefinition(1).route[0] &&
                  w.onTap != null,
            )
            .first;
        await tester.tap(wrong);
        await tester.pump(const Duration(milliseconds: 1400));
        expect(controller.progress.life.count, 3);
        // Starts by itself after the 3-2-1 countdown.
        await tester.pump(const Duration(milliseconds: 2400));
        await tester.pump(preview + const Duration(milliseconds: 300));
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
          await tester.pump(const Duration(milliseconds: 450));
          if (row == 1) await screenshot('path-walking');
        }
        await tester.pumpAndSettle();
        expect(find.byType(ResultScreen), findsOneWidget);
        expect(controller.progress.level, 2);
        expect(controller.progress.completedLevels, 1);
        // One wrong step before clearing: two stars.
        expect(controller.progress.starsOf(GameKind.path, 1), 2);
        await tester.tap(find.text('Ana sayfaya dön'));
        await tester.pumpAndSettle();

        // Sequence Memory level 1: one right answer, then a wrong one.
        await tester.ensureVisible(find.text('Level 1').first);
        await tester.tap(find.text('Level 1').first);
        await tester.pumpAndSettle();
        // Starts by itself after the 3-2-1 countdown.
        await tester.pump(const Duration(milliseconds: 2400));
        await tester.pump(const Duration(milliseconds: 400));
        final sequence = tester
            .widgetList<MemoryTile>(find.byType(MemoryTile))
            .toList();
        expect(sequence.length, SequenceLevel(1).count);
        final first = sequence[0].animal!,
            incorrect = animals.keys.firstWhere((a) => a != sequence[1].animal);
        await screenshot('sequence-preview');
        await tester.pump(
          Duration(milliseconds: SequenceLevel(1).previewMs + 300),
        );
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
        expect(find.text('Tekrar dene'), findsOneWidget);
        expect(controller.progress.life.count, 2);
        expect(controller.progress.statsOf(GameKind.sequence).failed, 1);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        final saved = await store.readSession(
          controller.scope,
          GameKind.sequence,
        );
        expect(saved!['phase'], 'failed');
        expect(saved['answered'], 1);

        // Card Matching level 1: three pairs found without a miss.
        await tester.ensureVisible(find.text('Level 1').last);
        await tester.tap(find.text('Level 1').last);
        await tester.pumpAndSettle();
        final tiles = tester
            .widgetList<MemoryTile>(find.byType(MemoryTile))
            .toList();
        expect(tiles.length, MatchingLevel(1).cards);
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
        expect(controller.progress.matchingLevel, 2);
        expect(controller.progress.starsOf(GameKind.matching, 1), 3);
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
        expect(controller.progress.matchingLevel, 2);
        expect(controller.progress.life.count, 2);
        expect(
          (await store.readSession(scope, GameKind.sequence))!['phase'],
          'failed',
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
