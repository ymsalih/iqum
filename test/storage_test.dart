import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:iqum/data/local_store.dart';
import 'package:iqum/domain/models.dart';

void main() {
  late LocalStore store;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() async => store.close());
  test('version one databases upgrade without losing guest progress', () async {
    final file = File(
      '${Directory.systemTemp.path}/iqum-migration-${newId()}.db',
    );
    final old = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: file.path,
    );
    final guest = await old.guestScope();
    await old.saveProgress(
      guest,
      const PlayerProgress(life: LifeState(observedAt: 1000), level: 12),
    );
    await old.saveProgress(
      'guest:legacy-duplicate',
      const PlayerProgress(life: LifeState(observedAt: 1000), level: 9),
    );
    await old.saveProgress(
      'user:b',
      const PlayerProgress(life: LifeState(observedAt: 1000), level: 7),
    );
    await old.db.insert('imports', {
      'id': 'legacy-transfer',
      'uid': 'b',
      'data':
          '{"importId":"legacy-transfer","progress":{"level":9},"records":[]}',
    });
    await old.db.execute('DROP TABLE scope_owners');
    await old.db.execute('PRAGMA user_version = 1');
    await old.close();
    final upgraded = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: file.path,
    );
    expect((await upgraded.readProgress(guest, 1000)).level, 12);
    expect(
      await upgraded.db.query(
        'progress',
        where: 'scope = ?',
        whereArgs: ['guest:legacy-duplicate'],
      ),
      isEmpty,
    );
    expect((await upgraded.readProgress('user:b', 1000)).level, 7);
    expect((await upgraded.imports('b')).single['id'], 'legacy-transfer');
    await upgraded.prepareGuestImport(
      guest,
      'a',
      await upgraded.readProgress(guest, 1000),
    );
    await upgraded.purgeAccount('a');
    expect(await upgraded.imports('a'), isEmpty);
    await upgraded.close();
    await databaseFactoryFfi.deleteDatabase(file.path);
  });
  test(
    'purge removes account-owned imports, sessions and recovery without clearing unrelated scopes',
    () async {
      final guest = await store.guestScope();
      const p = PlayerProgress(life: LifeState(observedAt: 1000), level: 9);
      await store.saveProgress(guest, p);
      await store.prepareGuestImport(guest, 'a', p);
      await store.saveSession('user:a', GameKind.path, {'row': 1});
      await store.saveProgress('user:b', p);
      await store.db.insert('recovery', {
        'source': 'session:user:a:path',
        'data': 'private',
      });
      await store.db.insert('recovery', {
        'source': 'progress:user:b',
        'data': 'keep',
      });
      await store.setMetadata('terms:a', 'version');
      await store.purgeAccount('a');
      expect(
        await store.db.query(
          'progress',
          where: 'scope = ?',
          whereArgs: [guest],
        ),
        isEmpty,
      );
      expect(await store.readSession('user:a', GameKind.path), isNull);
      expect(await store.imports('a'), isEmpty);
      expect(await store.metadata('terms:a'), isNull);
      expect((await store.db.query('recovery')).single['data'], 'keep');
      expect((await store.readProgress('user:b', 1000)).level, 9);
    },
  );
  test('guest reset rotates scope but cannot target a cloud account', () async {
    final guest = await store.guestScope();
    await store.saveProgress(
      guest,
      const PlayerProgress(life: LifeState(observedAt: 1000), level: 5),
    );
    await expectLater(store.clearGuest('user:a'), throwsStateError);
    await store.clearGuest(guest);
    expect(await store.guestScope(), isNot(guest));
    expect(await store.db.query('progress'), isEmpty);
  });
  test(
    'SQLite persists progress, sessions and unique completed runs',
    () async {
      final guest = await store.guestScope();
      final p = PlayerProgress(life: LifeState(observedAt: 1000), level: 7);
      await store.saveProgress(guest, p);
      expect((await store.readProgress(guest, 1000)).level, 7);
      await store.saveSession(guest, GameKind.path, {'level': 7, 'row': 2});
      expect((await store.readSession(guest, GameKind.path))!['row'], 2);
      final record = RunRecord(
        id: 'same-run',
        game: GameKind.path,
        finishedAt: 1000,
        data: {'level': 7},
      );
      await store.finishRun(guest, record, p);
      await store.finishRun(guest, record, p);
      expect(await store.readSession(guest, GameKind.path), isNull);
      expect((await store.pendingRuns(guest)).length, 1);
    },
  );
  test('guest transfers belong to a uid and rotate the guest scope', () async {
    final guest = await store.guestScope(),
        p = PlayerProgress(life: LifeState(observedAt: 1000), level: 9);
    await store.prepareGuestImport(guest, 'account-a', p);
    expect((await store.imports('account-a')).length, 1);
    expect(await store.imports('account-b'), isEmpty);
    expect(await store.guestScope(), isNot(guest));
    final transfer = (await store.imports('account-a')).single;
    await store.removeImport(transfer['id'] as String);
    expect(await store.imports('account-a'), isEmpty);
  });
  test(
    'malformed state is preserved for recovery rather than deleted',
    () async {
      final guest = await store.guestScope();
      await store.db.insert('progress', {
        'scope': guest,
        'data': 'broken json',
      });
      expect((await store.readProgress(guest, 1000)).level, 1);
      expect((await store.db.query('recovery')).single['data'], 'broken json');
      await store.db.insert('sessions', {
        'scope': guest,
        'game': 'path',
        'data': 'bad session',
      });
      expect(await store.readSession(guest, GameKind.path), isNull);
      expect((await store.db.query('recovery')).length, 2);
    },
  );
}
