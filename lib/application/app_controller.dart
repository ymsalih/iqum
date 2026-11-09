import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/backend.dart';
import '../data/local_store.dart';
import '../domain/models.dart';

final appProvider = ChangeNotifierProvider<AppController>(
  (ref) =>
      throw UnimplementedError('AppController must be provided at startup'),
);

class AppController extends ChangeNotifier {
  AppController(this.store, this.backend, {int Function()? clock})
    : _clock = clock ?? (() => backend.now);
  final int Function() _clock;
  final LocalStore store;
  final Backend backend;
  late String scope;
  late PlayerProgress progress;
  Account? get account =>
      deletionAccepted && backend.account?.uid == deletion?['uid']
      ? null
      : backend.account;
  Map<String, dynamic>? deletion;
  bool get deletionAccepted =>
      ['pending', 'processing', 'complete'].contains(deletion?['state']);
  bool busy = false;
  String? syncError;
  StreamSubscription<Map<String, dynamic>>? _profileSub;
  Future<void>? _syncing;
  String? _syncUid;
  bool _syncAgain = false;
  AudioPlayer? _audio;
  Timer? _lifeTimer;
  bool _disposed = false;
  int get now => _clock();
  LifeState _localLife(LifeState life) =>
      backend.hasServerTime ? life.rebaseFuture(now) : life;

  Future<void> synchronizeTime() async {
    if (!backend.available) return;
    try {
      await backend.call('getServerTime');
    } catch (_) {
      // Offline play remains available; no competitive result uses this clock.
    }
  }

  Future<void> resume() async {
    await synchronizeTime();
    if (_disposed) return;
    await refreshLife();
    await sync();
  }

  Future<void> restore() async {
    await synchronizeTime();
    final savedDeletion = await store.metadata('accountDeletion');
    if (savedDeletion != null) {
      try {
        deletion = Map<String, dynamic>.from(jsonDecode(savedDeletion) as Map);
      } catch (_) {
        await store.setMetadata('accountDeletion', null);
      }
      if (deletion != null) {
        if (deletionAccepted) await _clearDeletedAccount();
        await _readDeletionStatus();
        if (deletionAccepted) await _clearDeletedAccount();
      }
    }
    scope = account == null ? await store.guestScope() : 'user:${account!.uid}';
    progress = await store.readProgress(
      scope,
      now,
      trustedTime: backend.hasServerTime,
    );
    _scheduleLife();
    _watchProfile();
    if (account != null) unawaited(sync());
  }

  Future<void> refreshLife() async {
    final life = _localLife(progress.life).at(now);
    final changed = life.count != progress.life.count;
    progress = progress.copyWith(life: life);
    await store.saveProgress(scope, progress);
    _scheduleLife();
    if (changed) notifyListeners();
  }

  Future<bool> spendHeart({Map<String, dynamic>? pathSession}) async {
    final current = _localLife(progress.life).at(now);
    if (current.count == 0) return false;
    final previous = progress;
    progress = progress.copyWith(life: current.spend(now));
    notifyListeners();
    try {
      if (pathSession == null) {
        await store.saveProgress(scope, progress);
      } else {
        await store.saveProgressAndPath(scope, progress, pathSession);
      }
    } catch (_) {
      progress = previous;
      notifyListeners();
      rethrow;
    }
    _scheduleLife();
    if (account != null) unawaited(sync());
    return true;
  }

  void _scheduleLife() {
    _lifeTimer?.cancel();
    if (_disposed) return;
    final life = _localLife(progress.life).at(now);
    if (life.count < 4 && life.nextAt != null) {
      _lifeTimer = Timer(
        Duration(milliseconds: max(1, life.nextAt! - now)),
        () => unawaited(refreshLife()),
      );
    }
  }

  Future<void> settings({bool? sound, bool? haptics}) async {
    progress = progress.copyWith(sound: sound, haptics: haptics);
    notifyListeners();
    await store.saveProgress(scope, progress);
  }

  Future<void> feedback(String cue) async {
    if (progress.haptics) {
      if (cue == 'error') {
        unawaited(HapticFeedback.heavyImpact());
      } else {
        unawaited(HapticFeedback.lightImpact());
      }
    }
    if (progress.sound) {
      try {
        final audio = _audio ??= AudioPlayer();
        await audio.stop();
        await audio.play(
          AssetSource('sounds/$cue.wav'),
          mode: PlayerMode.lowLatency,
          volume: .5,
        );
      } catch (_) {
        /* Audio device availability never blocks a move. */
      }
    }
  }

  Future<void> complete(RunRecord record) async {
    var updated = progress;
    if (record.game == GameKind.path) {
      updated = updated.copyWith(
        level: max(progress.level, min(30, intValue(record.data['level']) + 1)),
        completedLevels: max(
          progress.completedLevels,
          intValue(record.data['level']).clamp(0, 30),
        ),
      );
    }
    if (record.game == GameKind.sequence) {
      updated = updated.copyWith(
        sequenceBest: max(
          progress.sequenceBest,
          intValue(record.data['correct']),
        ),
      );
    }
    if (record.game == GameKind.matching) {
      final ms = intValue(record.data['elapsedMs']),
          attempts = intValue(record.data['attempts']);
      updated = updated.copyWith(
        matchingBestMs: progress.matchingBestMs == null
            ? ms
            : min(progress.matchingBestMs!, ms),
        matchingBestAttempts: progress.matchingBestAttempts == null
            ? attempts
            : min(progress.matchingBestAttempts!, attempts),
      );
    }
    await store.finishRun(scope, record, updated);
    progress = updated;
    notifyListeners();
    if (account != null) unawaited(sync());
  }

  Future<bool> signIn(bool apple, {String? legalVersion}) async {
    if (busy) return false;
    if (deletion != null && deletion?['state'] != 'complete') {
      throw StateError(
        'Önce bekleyen hesap silme işleminin durumunu kontrol et.',
      );
    }
    busy = true;
    notifyListeners();
    try {
      if (deletion?['state'] == 'complete') {
        await store.setMetadata('accountDeletion', null);
        deletion = null;
      }
      final previousScope = scope, snapshot = progress;
      if (!await backend.signIn(apple)) return false;
      final uid = account!.uid;
      if (legalVersion != null) {
        await store.setMetadata('terms:$uid', legalVersion);
      }
      if (previousScope.startsWith('guest:')) {
        try {
          await store.prepareGuestImport(previousScope, uid, snapshot);
        } catch (_) {
          await backend.signOut();
          rethrow;
        }
      }
      scope = 'user:$uid';
      await synchronizeTime();
      final cached = await store.readProgress(
        scope,
        now,
        trustedTime: backend.hasServerTime,
      );
      progress = _merge(cached, snapshot.copyWith(points: cached.points));
      _scheduleLife();
      await store.saveProgress(scope, progress);
      _watchProfile();
      await sync();
      return true;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await _profileSub?.cancel();
      _profileSub = null;
      await backend.signOut();
      scope = await store.guestScope();
      progress = await store.readProgress(
        scope,
        now,
        trustedTime: backend.hasServerTime,
      );
      _scheduleLife();
      syncError = null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  PlayerProgress _merge(PlayerProgress local, PlayerProgress remote) =>
      local.copyWith(
        level: max(local.level, remote.level),
        completedLevels: max(local.completedLevels, remote.completedLevels),
        life: _localLife(local.life).merge(remote.life, now),
        points: remote.points,
        sequenceBest: max(local.sequenceBest, remote.sequenceBest),
        matchingBestMs: local.matchingBestMs == null
            ? remote.matchingBestMs
            : remote.matchingBestMs == null
            ? local.matchingBestMs
            : min(local.matchingBestMs!, remote.matchingBestMs!),
        matchingBestAttempts: local.matchingBestAttempts == null
            ? remote.matchingBestAttempts
            : remote.matchingBestAttempts == null
            ? local.matchingBestAttempts
            : min(local.matchingBestAttempts!, remote.matchingBestAttempts!),
      );
  void _watchProfile() {
    unawaited(_profileSub?.cancel());
    final uid = account?.uid;
    if (uid == null) return;
    _profileSub = backend.watchProfile().listen(
      (data) {
        if (account?.uid != uid) return;
        progress = _merge(progress, PlayerProgress.fromJson(data, now));
        _scheduleLife();
        notifyListeners();
        unawaited(store.saveProgress(scope, progress));
      },
      onError: (_) {
        syncError =
            'Kayıtların cihazında güvende. Bağlantı gelince yeniden eşitle.';
        notifyListeners();
      },
    );
  }

  Future<void> sync() {
    if (account == null) return Future.value();
    if (deletion?['uid'] == account!.uid) return Future.value();
    if (_syncing != null) {
      if (_syncUid != account!.uid) return _syncing!.then((_) => sync());
      _syncAgain = true;
      return _syncing!;
    }
    _syncUid = account!.uid;
    _syncing = _doSync().whenComplete(() {
      _syncing = null;
      _syncUid = null;
    });
    return _syncing!;
  }

  Future<void> _doSync() async {
    final uid = account!.uid, activeScope = scope;
    try {
      do {
        _syncAgain = false;
        final termsVersion = await store.metadata('terms:$uid');
        if (termsVersion != null) {
          await backend.call('acceptLegalTerms', {'version': termsVersion});
          await store.setMetadata('terms:$uid', null);
        }
        for (final transfer in await store.imports(uid)) {
          final result = await backend.call(
            'importProgress',
            Map<String, dynamic>.from(transfer['payload'] as Map),
          );
          if (account?.uid != uid) return;
          await store.removeImport(transfer['id'] as String);
          progress = _merge(
            progress,
            PlayerProgress.fromJson(
              Map<String, dynamic>.from(result['profile'] as Map),
              now,
            ),
          );
        }
        while (account?.uid == uid) {
          final runs = await store.pendingRuns(activeScope);
          if (runs.isEmpty) break;
          final result = await backend.call('importProgress', {
            'importId': '${runs.first['id']}_${runs.last['id']}_${runs.length}',
            'progress': progress.toJson(),
            'records': runs,
          });
          if (account?.uid != uid) return;
          await store.markUploaded(runs.map((r) => r['id'] as String).toList());
          progress = _merge(
            progress,
            PlayerProgress.fromJson(
              Map<String, dynamic>.from(result['profile'] as Map),
              now,
            ),
          );
        }
        if (account?.uid != uid) return;
        final result = await backend.call('importProgress', {
          'importId': newId(),
          'progress': progress.toJson(),
          'records': <dynamic>[],
        });
        progress = _merge(
          progress,
          PlayerProgress.fromJson(
            Map<String, dynamic>.from(result['profile'] as Map),
            now,
          ),
        );
      } while (_syncAgain && account?.uid == uid);
      if (account?.uid != uid) return;
      syncError = null;
      await store.saveProgress(activeScope, progress);
      notifyListeners();
    } catch (_) {
      if (account?.uid == uid) {
        syncError =
            'Kayıtların cihazında güvende. Bağlantı gelince yeniden eşitle.';
        notifyListeners();
      }
    }
  }

  Future<bool> deleteAccount() async {
    if (busy) return false;
    final uid = backend.account?.uid;
    if (uid == null) throw StateError('Önce hesabına giriş yap.');
    busy = true;
    notifyListeners();
    try {
      if (_syncing != null) await _syncing;
      if (!await backend.reauthenticateForDeletion()) return false;
      deletion = deletion?['uid'] == uid
          ? deletion
          : {'uid': uid, 'requestId': newId(), 'state': 'prepared'};
      await _saveDeletion();
      final result = await backend.call('requestAccountDeletion', {
        'requestId': deletion!['requestId'],
      });
      if (!['pending', 'processing', 'complete'].contains(result['state'])) {
        throw StateError(
          'Silme isteği henüz doğrulanamadı. Durumunu kontrol et.',
        );
      }
      deletion!['state'] = result['state'];
      await _saveDeletion();
      if (deletionAccepted) {
        await _profileSub?.cancel();
        _profileSub = null;
        await _clearDeletedAccount();
        scope = await store.guestScope();
        progress = await store.readProgress(
          scope,
          now,
          trustedTime: backend.hasServerTime,
        );
        syncError = null;
        _scheduleLife();
      }
      return deletionAccepted;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _clearDeletedAccount() async {
    final uid = deletion!['uid'] as String;
    await store.purgeAccount(uid);
    try {
      if (backend.account?.uid == uid) await backend.signOut();
    } finally {
      // Even a native sign-out failure must not leave deleted progress active
      // or let later settings writes recreate that user's local scope.
      scope = account == null
          ? await store.guestScope()
          : 'user:${account!.uid}';
      progress = await store.readProgress(
        scope,
        now,
        trustedTime: backend.hasServerTime,
      );
      syncError = null;
      _scheduleLife();
    }
  }

  Future<void> _saveDeletion() =>
      store.setMetadata('accountDeletion', jsonEncode(deletion));
  Future<void> _readDeletionStatus() async {
    if (deletion == null) return;
    try {
      final result = await backend.call('getDeletionStatus', {
        'uid': deletion!['uid'],
        'requestId': deletion!['requestId'],
      });
      if (['pending', 'processing', 'complete'].contains(result['state'])) {
        deletion!['state'] = result['state'];
        deletion!.remove('statusUnavailable');
        await _saveDeletion();
      } else if (result['state'] == 'unknown') {
        deletion!['statusUnavailable'] = true;
        await _saveDeletion();
      }
    } catch (_) {
      /* A network failure never changes pending into completed. */
    }
  }

  Future<void> refreshDeletionStatus() async {
    if (busy || deletion == null) return;
    busy = true;
    notifyListeners();
    try {
      if (deletionAccepted) await _clearDeletedAccount();
      await _readDeletionStatus();
      if (deletionAccepted) {
        await _clearDeletedAccount();
        scope = account == null
            ? await store.guestScope()
            : 'user:${account!.uid}';
        progress = await store.readProgress(
          scope,
          now,
          trustedTime: backend.hasServerTime,
        );
        _scheduleLife();
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> dismissCompletedDeletion() async {
    if (deletion?['state'] != 'complete') return;
    await store.setMetadata('accountDeletion', null);
    deletion = null;
    notifyListeners();
  }

  Future<void> resetGuestProgress() async {
    if (busy || account != null) return;
    await store.clearGuest(scope);
    scope = await store.guestScope();
    progress = await store.readProgress(scope, now);
    _scheduleLife();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _lifeTimer?.cancel();
    unawaited(_profileSub?.cancel());
    unawaited(_audio?.dispose());
    super.dispose();
  }
}
