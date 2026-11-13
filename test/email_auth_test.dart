import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:iqum/application/app_controller.dart';
import 'package:iqum/data/backend.dart';
import 'package:iqum/data/local_store.dart';
import 'package:iqum/ui/email_auth_screen.dart';
import 'package:iqum/ui/theme.dart';

/// Records e-mail account calls; the address is verified only when asked.
class _EmailBackend extends OfflineBackend {
  final registered = <String>[];
  bool verified = false;
  @override
  bool get available => true;
  @override
  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async => registered.add('$name|$email|$password');
  @override
  Future<bool> signInWithEmail(String email, String password) async {
    if (!verified) throw EmailNotVerified(email);
    return true;
  }
}

void main() {
  late LocalStore store;
  late AppController app;
  late _EmailBackend backend;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    backend = _EmailBackend();
    app = AppController(store, backend);
    await app.restore();
  });
  tearDown(() async {
    app.dispose();
    await store.close();
  });

  Future<void> open(WidgetTester tester, {bool register = true}) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: MaterialApp(
          theme: AppColors.theme,
          home: EmailAuthScreen(register: register),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, label), text);

  testWidgets('registration checks every field before creating an account', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await tester.pumpAndSettle();
    expect(find.text('Adını yaz.'), findsOneWidget);
    expect(find.text('Geçerli bir e-posta adresi yaz.'), findsOneWidget);
    await fill(tester, 'Ad', 'Ada');
    await fill(tester, 'Soyad', 'Lovelace');
    await fill(tester, 'E-posta', 'ada@example.com');
    await fill(tester, 'Şifre', 'kisa');
    await fill(tester, 'Şifre (tekrar)', 'baska');
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await tester.pumpAndSettle();
    expect(find.text('En az 8 karakter olmalı.'), findsOneWidget);
    expect(find.text('Şifreler aynı olmalı.'), findsOneWidget);
    await fill(tester, 'Şifre', 'sadeceharf');
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await tester.pumpAndSettle();
    expect(find.text('En az bir harf ve bir rakam içermeli.'), findsOneWidget);
    await fill(tester, 'Şifre', 'dogrusifre1');
    await fill(tester, 'Şifre (tekrar)', 'dogrusifre1');
    // Terms not accepted yet: nothing is created.
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await tester.pump();
    expect(backend.registered, isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await tester.pumpAndSettle();
    expect(backend.registered, ['Ada Lovelace|ada@example.com|dogrusifre1']);
    // Next step: verify the address, then sign in from the login tab.
    expect(find.textContaining('ada@example.com adresine'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Giriş yap'), findsOneWidget);
    expect(app.account, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unverified address is told to confirm its e-mail', (
    tester,
  ) async {
    await open(tester, register: false);
    await fill(tester, 'E-posta', 'ada@example.com');
    await fill(tester, 'Şifre', 'dogrusifre1');
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await tester.pumpAndSettle();
    // Terms acceptance comes first, as with Google and Apple.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
    await tester.pumpAndSettle();
    expect(find.text('E-postanı doğrula'), findsOneWidget);
    expect(find.text('Tekrar gönder'), findsOneWidget);
    expect(app.account, isNull);
    expect(tester.takeException(), isNull);
  });
}
