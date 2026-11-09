import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:iqum/application/app_controller.dart';
import 'package:iqum/data/local_store.dart';
import 'package:iqum/data/backend.dart';
import 'package:iqum/domain/models.dart';

class FakeBackend extends OfflineBackend {
  Account? signed;
  Account next = const Account('a', 'A');
  bool cancel = false,
      fail = false,
      cancelReauth = false,
      failDeletion = false,
      failSignOut = false;
  String deletionState = 'pending';
  @override
  Future<bool> reauthenticateForDeletion() async => !cancelReauth;
  final calls = <Map<String, dynamic>>[];
  final profiles = <String, PlayerProgress>{};
  final applied = <String>{};
  @override
  bool get available => true;
  @override
  Account? get account => signed;
  @override
  Future<bool> signIn(bool apple) async {
    if (cancel) return false;
    signed = next;
    return true;
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw StateError('native sign-out failure');
    signed = null;
  }

  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final uid = signed?.uid ?? 'guest';
    calls.add({'uid': uid, 'name': name, 'payload': data});
    if (fail) throw StateError('offline');
    if (name == 'getServerTime') return {'serverNow': 1000};
    if (name == 'requestAccountDeletion') {
      if (failDeletion) throw StateError('connection interrupted');
      return {'state': deletionState};
    }
    if (name == 'getDeletionStatus') return {'state': deletionState};
    if (name == 'acceptLegalTerms') return {'accepted': true};
    var profile =
        profiles[uid] ??
        PlayerProgress(
          life: const LifeState(observedAt: 1000),
          points: uid == 'a' ? 300 : 50,
        );
    if (name == 'importProgress' && applied.add('$uid:${data['importId']}')) {
      final local = PlayerProgress.fromJson(
        Map<String, dynamic>.from(data['progress'] as Map),
        1000,
      );
      profile = profile.copyWith(
        level: max(profile.level, local.level),
        life: profile.life.merge(local.life, 1000),
        completedLevels: max(profile.completedLevels, local.completedLevels),
        sequenceBest: max(profile.sequenceBest, local.sequenceBest),
      );
      profiles[uid] = profile;
    }
    return {'profile': profile.toJson()};
  }
}

class ClockBackend extends OfflineBackend {
  bool sampled = false;
  @override
  bool get available => true;
  @override
  bool get hasServerTime => sampled;
  @override
  int get now => sampled ? 1000 : 9999999999999;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    expect(name, 'getServerTime');
    sampled = true;
    return {'serverNow': 1000};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStore store;
  late FakeBackend backend;
  late AppController app;
  var now = 1000;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    now = 1000;
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    backend = FakeBackend();
    app = AppController(store, backend, clock: () => now);
    await app.restore();
  });
  tearDown(() async {
    app.dispose();
    await store.close();
  });
  test(
    'native logout failure cannot reactivate or recreate a deleted local account scope',
    () async {
      await app.signIn(false);
      backend.failSignOut = true;
      await expectLater(app.deleteAccount(), throwsStateError);
      expect(app.account, isNull);
      expect(app.scope, startsWith('guest:'));
      await app.settings(sound: false);
      expect(
        await store.db.query(
          'progress',
          where: 'scope = ?',
          whereArgs: ['user:a'],
        ),
        isEmpty,
      );
      backend.failSignOut = false;
      backend.deletionState = 'unknown';
      await app.refreshDeletionStatus();
      expect(app.deletion?['state'], 'pending');
      expect(app.deletion?['statusUnavailable'], true);
      backend.deletionState = 'complete';
      await app.refreshDeletionStatus();
      expect(app.deletion?['state'], 'complete');
      expect(app.deletion?['statusUnavailable'], isNull);
    },
  );
  test(
    'accepted deletion purges owned guest and account data, preserves another account',
    () async {
      final guest = app.scope;
      await app.signIn(false, legalVersion: '2026-11-09');
      await store.saveProgress(
        'user:b',
        const PlayerProgress(life: LifeState(observedAt: 1000), level: 8),
      );
      expect(backend.calls.any((c) => c['name'] == 'acceptLegalTerms'), true);
      expect(await app.deleteAccount(), true);
      expect(app.account, isNull);
      expect(backend.signed, isNull);
      expect(app.scope, startsWith('guest:'));
      expect(
        await store.db.query(
          'progress',
          where: 'scope IN (?, ?)',
          whereArgs: [guest, 'user:a'],
        ),
        isEmpty,
      );
      expect((await store.readProgress('user:b', 1000)).level, 8);
      expect(app.deletion?['state'], 'pending');
      backend.fail = true;
      await app.refreshDeletionStatus();
      expect(app.deletion?['state'], 'pending');
      backend.fail = false;
      backend.deletionState = 'complete';
      await app.refreshDeletionStatus();
      expect(app.deletion?['state'], 'complete');
      await app.dismissCompletedDeletion();
      expect(await store.metadata('accountDeletion'), isNull);
    },
  );
  test(
    'cancelled reauthentication and interrupted request never discard account data',
    () async {
      await app.signIn(false);
      final before = app.scope;
      backend.cancelReauth = true;
      expect(await app.deleteAccount(), false);
      expect(app.deletion, isNull);
      backend.cancelReauth = false;
      backend.failDeletion = true;
      await expectLater(app.deleteAccount(), throwsStateError);
      expect(app.deletion?['state'], 'prepared');
      expect(app.account?.uid, 'a');
      expect(
        await store.db.query(
          'progress',
          where: 'scope = ?',
          whereArgs: [before],
        ),
        isNotEmpty,
      );
      final receipt = app.deletion?['requestId'];
      backend.failDeletion = false;
      await app.deleteAccount();
      expect(app.deletion?['requestId'], receipt);
    },
  );
  test(
    'restart completes local cleanup after server accepted request, even when status is offline',
    () async {
      await app.signIn(false);
      await store.setMetadata(
        'accountDeletion',
        '{"uid":"a","requestId":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","state":"pending"}',
      );
      app.dispose();
      backend.fail = true;
      app = AppController(store, backend, clock: () => now);
      await app.restore();
      expect(backend.signed, isNull);
      expect(app.deletion?['state'], 'pending');
      expect(
        await store.db.query(
          'progress',
          where: 'scope = ?',
          whereArgs: ['user:a'],
        ),
        isEmpty,
      );
      expect(app.scope, startsWith('guest:'));
    },
  );
  test(
    'startup obtains server time before renewing a cached guest wallet',
    () async {
      final scope = app.scope;
      await store.saveProgress(
        scope,
        const PlayerProgress(
          life: LifeState(count: 1, observedAt: 1000, nextAt: 1801000),
        ),
      );
      app.dispose();
      final timed = ClockBackend();
      app = AppController(store, timed);
      await app.restore();
      expect(timed.sampled, true);
      expect(app.now, 1000);
      expect(app.progress.life.count, 1);
      expect(app.progress.life.nextAt, 1801000);
    },
  );
  test(
    'heart loss and failed path session commit together; renewal uses wall time',
    () async {
      final scope = app.scope;
      await app.spendHeart(pathSession: {'level': 1, 'phase': 'feedback'});
      expect((await store.readProgress(scope, now)).life.count, 3);
      expect(
        (await store.readSession(scope, GameKind.path))!['phase'],
        'feedback',
      );
      now += 1800000;
      await app.refreshLife();
      expect(app.progress.life.count, 4);
    },
  );
  test('cancelled sign-in keeps the exact guest and its data', () async {
    final guest = app.scope;
    await app.spendHeart();
    backend.cancel = true;
    expect(await app.signIn(false), false);
    expect(app.scope, guest);
    expect(app.progress.life.count, 3);
    expect(await store.guestScope(), guest);
    expect(await store.imports('a'), isEmpty);
  });
  test(
    'guest data migrates once and signing out never exposes it to another account',
    () async {
      await app.complete(
        RunRecord(
          id: newId(),
          game: GameKind.path,
          finishedAt: now,
          data: {'level': 7},
        ),
      );
      await app.spendHeart();
      expect(await app.signIn(false), true);
      expect(app.progress.level, 8);
      expect(app.progress.completedLevels, 7);
      expect(app.progress.points, 300);
      expect(await store.imports('a'), isEmpty);
      await app.signOut();
      expect(app.progress.level, 1);
      expect(app.progress.points, 0);
      expect(app.progress.completedLevels, 0);
      backend.next = const Account('b', 'B');
      await app.signIn(false);
      expect(app.progress.points, 50);
      expect(app.progress.level, 1);
      final bTransfers = backend.calls.where(
        (c) => c['uid'] == 'b' && c['name'] == 'importProgress',
      );
      expect(
        bTransfers,
        everyElement(
          predicate<Map<String, dynamic>>(
            (c) => ((c['payload'] as Map)['records'] as List).isEmpty,
          ),
        ),
      );
    },
  );
  test(
    'failed transfer remains queued only for its intended account',
    () async {
      await app.complete(
        RunRecord(
          id: newId(),
          game: GameKind.sequence,
          finishedAt: now,
          data: {'correct': 12},
        ),
      );
      backend.fail = true;
      await app.signIn(false);
      expect(app.syncError, isNotNull);
      expect((await store.imports('a')).length, 1);
      await app.signOut();
      backend.fail = false;
      backend.next = const Account('b', 'B');
      await app.signIn(false);
      expect((await store.imports('a')).length, 1);
      expect(app.progress.sequenceBest, 0);
    },
  );
}
