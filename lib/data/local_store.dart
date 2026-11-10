import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';

class LocalStore {
  LocalStore(this.db);
  final Database db;
  static Future<LocalStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final file = path ?? p.join(await f.getDatabasesPath(), 'iqum.db');
    final database = await f.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE progress (scope TEXT PRIMARY KEY, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE sessions (scope TEXT NOT NULL, game TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY(scope,game))',
          );
          await db.execute(
            'CREATE TABLE runs (id TEXT PRIMARY KEY, scope TEXT NOT NULL, data TEXT NOT NULL, uploaded INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE imports (id TEXT PRIMARY KEY, uid TEXT NOT NULL, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE recovery (id INTEGER PRIMARY KEY AUTOINCREMENT, source TEXT NOT NULL, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE scope_owners (scope TEXT PRIMARY KEY, uid TEXT NOT NULL)',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'CREATE TABLE scope_owners (scope TEXT PRIMARY KEY, uid TEXT NOT NULL)',
            );
            // v1 froze transfer payloads and copied sessions before rotating
            // guestScope, in one transaction. Remove unreachable duplicate
            // guest caches; keep the current guest, user scopes and imports.
            final current = await db.query(
              'metadata',
              where: 'key = ?',
              whereArgs: ['guestScope'],
            );
            final currentGuest = current.isEmpty
                ? ''
                : current.first['value'] as String;
            for (final table in ['progress', 'sessions', 'runs']) {
              await db.delete(
                table,
                where: "scope LIKE 'guest:%' AND scope != ?",
                whereArgs: [currentGuest],
              );
            }
            await db.delete(
              'recovery',
              where:
                  "(source LIKE 'progress:guest:%' AND source != ?) OR (source LIKE 'session:guest:%' AND instr(source, ?) != 1)",
              whereArgs: ['progress:$currentGuest', 'session:$currentGuest:'],
            );
          }
        },
      ),
    );
    return LocalStore(database);
  }

  Future<String> guestScope() async {
    final rows = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['guestScope'],
    );
    if (rows.isNotEmpty) return rows.first['value'] as String;
    final scope = 'guest:${newId()}';
    await db.insert('metadata', {
      'key': 'guestScope',
      'value': scope,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return (await db.query(
          'metadata',
          where: 'key = ?',
          whereArgs: ['guestScope'],
        )).first['value']
        as String;
  }

  Future<PlayerProgress> readProgress(
    String scope,
    int now, {
    bool trustedTime = false,
  }) async {
    final rows = await db.query(
      'progress',
      where: 'scope = ?',
      whereArgs: [scope],
    );
    if (rows.isEmpty) return PlayerProgress(life: LifeState(observedAt: now));
    try {
      return PlayerProgress.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(rows.first['data'] as String) as Map,
        ),
        now,
        trustedTime: trustedTime,
      );
    } catch (_) {
      await db.insert('recovery', {
        'source': 'progress:$scope',
        'data': rows.first['data'],
      });
      return PlayerProgress(life: LifeState(observedAt: now));
    }
  }

  Future<void> saveProgress(String scope, PlayerProgress progress) => db
      .insert('progress', {
        'scope': scope,
        'data': jsonEncode(progress.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});

  Future<void> saveProgressAndPath(
    String scope,
    PlayerProgress progress,
    Map<String, dynamic> session,
  ) => saveProgressAndSession(scope, progress, GameKind.path, session);

  /// Progress and a game session in one transaction (a failed level's heart
  /// and the attempt it belongs to are saved together).
  Future<void> saveProgressAndSession(
    String scope,
    PlayerProgress progress,
    GameKind game,
    Map<String, dynamic> session,
  ) async {
    await db.transaction((tx) async {
      await tx.insert('progress', {
        'scope': scope,
        'data': jsonEncode(progress.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.insert('sessions', {
        'scope': scope,
        'game': game.name,
        'data': jsonEncode(session),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Map<String, dynamic>?> readSession(String scope, GameKind game) async {
    final rows = await db.query(
      'sessions',
      where: 'scope = ? AND game = ?',
      whereArgs: [scope, game.name],
    );
    if (rows.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(
        jsonDecode(rows.first['data'] as String) as Map,
      );
    } catch (_) {
      await discardInvalidSession(scope, game);
      return null;
    }
  }

  Future<void> discardInvalidSession(String scope, GameKind game) async {
    await db.transaction((tx) async {
      final rows = await tx.query(
        'sessions',
        where: 'scope = ? AND game = ?',
        whereArgs: [scope, game.name],
      );
      for (final row in rows) {
        await tx.insert('recovery', {
          'source': 'session:$scope:${game.name}',
          'data': row['data'],
        });
      }
      await tx.delete(
        'sessions',
        where: 'scope = ? AND game = ?',
        whereArgs: [scope, game.name],
      );
    });
  }

  Future<void> saveSession(
    String scope,
    GameKind game,
    Map<String, dynamic> data,
  ) => db
      .insert('sessions', {
        'scope': scope,
        'game': game.name,
        'data': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<void> finishRun(
    String scope,
    RunRecord record,
    PlayerProgress progress,
  ) async {
    await db.transaction((tx) async {
      await tx.insert('runs', {
        'id': record.id,
        'scope': scope,
        'data': jsonEncode(record.toJson()),
        'uploaded': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await tx.insert('progress', {
        'scope': scope,
        'data': jsonEncode(progress.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.delete(
        'sessions',
        where: 'scope = ? AND game = ?',
        whereArgs: [scope, record.game.name],
      );
    });
  }

  Future<void> clearSession(String scope, GameKind game) => db
      .delete(
        'sessions',
        where: 'scope = ? AND game = ?',
        whereArgs: [scope, game.name],
      )
      .then((_) {});
  Future<List<Map<String, dynamic>>> pendingRuns(String scope) async =>
      (await db.query(
            'runs',
            where: 'scope = ? AND uploaded = 0',
            whereArgs: [scope],
            limit: 100,
          ))
          .map(
            (r) => Map<String, dynamic>.from(
              jsonDecode(r['data'] as String) as Map,
            ),
          )
          .toList();
  Future<void> markUploaded(List<String> ids) async {
    if (ids.isEmpty) return;
    await db.update(
      'runs',
      {'uploaded': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<List<Map<String, dynamic>>> imports(String uid) async =>
      (await db.query('imports', where: 'uid = ?', whereArgs: [uid]))
          .map(
            (r) => {
              'id': r['id'],
              'payload': Map<String, dynamic>.from(
                jsonDecode(r['data'] as String) as Map,
              ),
            },
          )
          .toList();
  Future<void> removeImport(String id) =>
      db.delete('imports', where: 'id = ?', whereArgs: [id]).then((_) {});

  // Freeze the guest snapshot before switching scopes. A pending transfer belongs
  // to one uid; signing out can never expose it to a different account.
  Future<void> prepareGuestImport(
    String guest,
    String uid,
    PlayerProgress snapshot,
  ) async {
    await db.transaction((tx) async {
      await tx.insert('scope_owners', {
        'scope': guest,
        'uid': uid,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final rows = await tx.query(
        'runs',
        where: 'scope = ?',
        whereArgs: [guest],
      );
      final records = rows.map((r) => jsonDecode(r['data'] as String)).toList();
      final sessions = await tx.query(
        'sessions',
        where: 'scope = ?',
        whereArgs: [guest],
      );
      for (final session in sessions) {
        await tx.insert('sessions', {
          'scope': 'user:$uid',
          'game': session['game'],
          'data': session['data'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      final chunks = records.isEmpty ? 1 : (records.length / 100).ceil();
      for (var i = 0; i < chunks; i++) {
        final part = records.skip(i * 100).take(100).toList();
        final id = newId();
        await tx.insert('imports', {
          'id': id,
          'uid': uid,
          'data': jsonEncode({
            'importId': id,
            'progress': snapshot.toJson(),
            'records': part,
          }),
        });
      }
      await tx.insert('metadata', {
        'key': 'guestScope',
        'value': 'guest:${newId()}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> close() => db.close();

  Future<String?> metadata(String key) async {
    final rows = await db.query('metadata', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMetadata(String key, String? value) async {
    if (value == null) {
      await db.delete('metadata', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('metadata', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> purgeAccount(String uid) async {
    await db.transaction((tx) async {
      final owned = await tx.query(
        'scope_owners',
        where: 'uid = ?',
        whereArgs: [uid],
      );
      final scopes = {
        'user:$uid',
        ...owned.map((row) => row['scope'] as String),
      };
      for (final scope in scopes) {
        for (final table in ['progress', 'sessions', 'runs']) {
          await tx.delete(table, where: 'scope = ?', whereArgs: [scope]);
        }
        await tx.delete(
          'recovery',
          where: 'source = ? OR instr(source, ?) = 1',
          whereArgs: ['progress:$scope', 'session:$scope:'],
        );
      }
      await tx.delete('imports', where: 'uid = ?', whereArgs: [uid]);
      await tx.delete('scope_owners', where: 'uid = ?', whereArgs: [uid]);
      await tx.delete('metadata', where: 'key = ?', whereArgs: ['terms:$uid']);
    });
  }

  Future<void> clearGuest(String scope) async {
    if (!scope.startsWith('guest:') || await metadata('guestScope') != scope) {
      throw StateError('Misafir alanı doğrulanamadı.');
    }
    await db.transaction((tx) async {
      for (final table in ['progress', 'sessions', 'runs']) {
        await tx.delete(table, where: 'scope = ?', whereArgs: [scope]);
      }
      await tx.delete(
        'recovery',
        where: 'source = ? OR instr(source, ?) = 1',
        whereArgs: ['progress:$scope', 'session:$scope:'],
      );
      await tx.update(
        'metadata',
        {'value': 'guest:${newId()}'},
        where: 'key = ?',
        whereArgs: ['guestScope'],
      );
    });
  }
}
