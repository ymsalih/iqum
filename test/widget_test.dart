import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:iqum/main.dart';
import 'package:iqum/application/app_controller.dart';
import 'package:iqum/data/backend.dart';
import 'package:iqum/data/local_store.dart';

void main() {
  late LocalStore store;
  late AppController controller;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    controller = AppController(store, OfflineBackend());
    await controller.restore();
  });
  tearDown(() async {
    await store.close();
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('Guest home, profile and duel fit a $width pixel phone', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => controller)],
          child: const IqumApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Biraz odak.\nBir adım ileri.'), findsOneWidget);
      expect(find.text('Sıra Hafızası'), findsOneWidget);
      expect(find.text('Kart Eşleştirme'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Leveller'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('level-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('level-30')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final locked = tester.widget<FilledButton>(
        find.byKey(const ValueKey('level-2')),
      );
      expect(locked.onPressed, isNull);
      Navigator.of(tester.element(find.byKey(const ValueKey('level-1')))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('MİSAFİR OYUNCU'), findsOneWidget);
      expect(find.text('Google ile devam et'), findsOneWidget);
      expect(find.text('Apple ile devam et'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Düello').last);
      await tester.pumpAndSettle();
      expect(find.text('Rastgele rakip bul'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'iOS offers both Google and Apple sign-in',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => controller)],
          child: const IqumApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Google ile devam et'), findsOneWidget);
      expect(find.text('Apple ile devam et'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
