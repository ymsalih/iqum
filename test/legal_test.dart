import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:iqum/application/app_controller.dart';
import 'package:iqum/data/backend.dart';
import 'package:iqum/data/local_store.dart';
import 'package:iqum/data/legal_links.dart';
import 'package:iqum/ui/legal_screen.dart';
import 'package:iqum/ui/theme.dart';

class _AccountBackend extends OfflineBackend {
  int reauthentications = 0;
  @override
  Account? get account => const Account('test-account', 'Oyuncu');
  @override
  Future<bool> reauthenticateForDeletion({String? password}) async {
    reauthentications++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStore store;
  late AppController app;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    app = AppController(store, OfflineBackend());
    await app.restore();
  });
  tearDown(() async {
    app.dispose();
    await store.close();
  });
  test('site texts, app and server share one terms version', () {
    final source =
        jsonDecode(File('design/legal/tr.json').readAsStringSync()) as Map;
    expect(source['version'], LegalLinks.version);
    expect((source['documents'] as List).map((d) => (d as Map)['id']).toSet(), {
      'privacy',
      'terms',
      'guide',
      'deletion',
    });
    expect(
      File('functions/src/index.js').readAsStringSync(),
      contains("CURRENT_LEGAL_VERSION='${LegalLinks.version}'"),
    );
  });
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'permanent deletion requires explicit confirmation; provider cancel preserves account at $width',
      (tester) async {
        final backend = _AccountBackend();
        final active = AppController(store, backend);
        await tester.runAsync(active.restore);
        await tester.runAsync(active.sync);
        tester.view.physicalSize = Size(width, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => active)],
            child: MaterialApp(
              theme: AppColors.theme,
              home: const DeleteAccountScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          FilledButton,
          'Hesabımı kalıcı olarak sil',
        );
        // The screen is a lazy ListView: scroll until the button is built.
        await tester.scrollUntilVisible(button, 200);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(backend.reauthentications, 1);
        expect(active.deletion, isNull);
        expect(active.account?.uid, 'test-account');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        active.dispose();
      },
    );
    testWidgets(
      'terms acceptance is explicit, cancellable and readable at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppColors.theme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await requestLegalAcceptance(context);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Devam et'),
              )
              .onPressed,
          isNull,
        );
        if (LegalLinks.uri(LegalLinks.privacy) == null) {
          await tester.tap(find.text('Gizlilik Politikasını oku'));
          await tester.pump();
          expect(find.text('Bu sayfa yakında yayında olacak.'), findsOneWidget);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Devam et'));
        await tester.pumpAndSettle();
        expect(result, LegalLinks.version);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Misafir kal'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'guest can read legal center and deletion help without signing in at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: MaterialApp(
              theme: AppColors.theme,
              home: const LegalCenterScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hesap ve Veri Silme'), findsOneWidget);
        expect(find.text('Açık kaynak lisansları'), findsOneWidget);
        if (LegalLinks.uri(LegalLinks.deletion) == null) {
          await tester.tap(find.text('Hesap ve Veri Silme'));
          await tester.pump();
          expect(find.text('Bu sayfa yakında yayında olacak.'), findsOneWidget);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
