import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/domain/models.dart';
import 'package:iqum/domain/games.dart';

void main() {
  group('Life wallet', () {
    test('starts at four; errors preserve an already running refill', () {
      final start = LifeState(observedAt: 1000),
          one = start.spend(1000),
          two = one.spend(100000);
      expect(one.count, 3);
      expect(two.count, 2);
      expect(two.nextAt, 1801000);
      expect(two.at(1801000).count, 3);
      expect(two.at(3601000).count, 4);
      expect(two.at(9000000).nextAt, isNull);
    });
    test(
      'zero cannot be overspent and a backwards clock does not grant a heart',
      () {
        var life = LifeState(observedAt: 10000);
        for (var i = 0; i < 6; i++) {
          life = life.spend(10000);
        }
        expect(life.count, 0);
        expect(life.at(0).count, 0);
        expect(life.at(1810000).count, 1);
        expect(life.at(0).observedAt, 10000);
      },
    );
    test('merge uses fewer hearts and the later legitimate refill', () {
      final a = LifeState(count: 1, nextAt: 100000, observedAt: 1000),
          b = LifeState(count: 3, nextAt: 120000, observedAt: 1000);
      final merged = a.merge(b, 2000);
      expect(merged.count, 1);
      expect(merged.nextAt, 120000);
    });
  });
  test('all thirty levels are stable, connected and get harder', () {
    var oldPreview = 10000, oldCells = 0;
    for (var n = 1; n <= 30; n++) {
      final level = LevelDefinition(n), again = LevelDefinition(n);
      expect(level.route, again.route);
      expect(level.route.length, level.rows);
      expect(level.previewMs, lessThan(oldPreview));
      expect(level.rows * level.columns, greaterThanOrEqualTo(oldCells));
      for (var r = 0; r < level.rows; r++) {
        expect(level.route[r], inInclusiveRange(0, level.columns - 1));
        if (r > 0) {
          expect(
            (level.route[r] - level.route[r - 1]).abs(),
            lessThanOrEqualTo(1),
          );
        }
      }
      oldPreview = level.previewMs;
      oldCells = level.rows * level.columns;
    }
  });
  group('Matching training', () {
    test('duplicates are ignored and mismatch locks input for 900 ms', () {
      final game = MatchingGame(seed: 7), different = MatchingGame(seed: 7);
      expect(game.board, different.board);
      final other = game.board.indexWhere((a) => a != game.board[0]);
      expect(game.select(0, 1000), true);
      expect(game.select(0, 1100), false);
      expect(game.attempts, 0);
      game.select(other, 1200);
      expect(game.attempts, 1);
      expect(game.phase, GamePhase.feedback);
      expect(game.select(5, 1250), false);
      expect(game.tick(2099), false);
      expect(game.tick(2100), true);
      expect(game.opened, isEmpty);
    });
    test(
      'eight matches finish, remain open and restore without regenerating',
      () {
        final game = MatchingGame(seed: 12);
        var now = 1000;
        for (final animal in game.board.toSet()) {
          final indexes = [
            for (var i = 0; i < 16; i++)
              if (game.board[i] == animal) i,
          ];
          game.select(indexes[0], now);
          game.select(indexes[1], now + 5);
          now += 700;
          game.tick(now);
        }
        expect(game.phase, GamePhase.complete);
        expect(game.matched.length, 16);
        expect(game.attempts, 8);
        final restored = MatchingGame.restore(game.toJson(now), now + 99999);
        expect(restored.board, game.board);
        expect(restored.id, game.id);
        expect(restored.matched, game.matched);
      },
    );
    test('a saved mismatch resumes with the remaining reveal time', () {
      final game = MatchingGame(seed: 2);
      final other = game.board.indexWhere((a) => a != game.board[0]);
      game.select(0, 1000);
      game.select(other, 1100);
      final saved = game.toJson(1500),
          restored = MatchingGame.restore(saved, 100000);
      expect(restored.tick(100499), false);
      expect(restored.tick(100500), true);
    });
  });
  group('Sequence', () {
    test('preview ends, one error ends only that round, next round grows', () {
      final game = SequenceGame(seed: 10);
      game.start(1000);
      expect(game.phase, GamePhase.preview);
      game.tick(7000);
      expect(game.phase, GamePhase.playing);
      game.answer(game.pattern[0], 7100);
      final wrong = animals.keys.firstWhere((a) => a != game.pattern[1]);
      game.answer(wrong, 7200);
      expect(game.phase, GamePhase.roundOver);
      expect(game.total, 1);
      expect(game.answer(game.pattern[1], 7300), false);
      game.next();
      expect(game.round, 1);
      expect(game.pattern.length, 9);
    });
    test('suspension does not consume preview or answer time', () {
      final game = SequenceGame(seed: 3);
      game.start(1000);
      game.pause(2000);
      final restored = SequenceGame.restore(game.toJson(2000), 900000);
      expect(restored.phase, GamePhase.preview);
      expect(restored.deadline, 905000);
      restored.tick(905000);
      expect(restored.phase, GamePhase.playing);
      restored.tick(935000);
      expect(restored.phase, GamePhase.roundOver);
    });
    test('three perfect rounds record 27 answers and finish', () {
      final game = SequenceGame(seed: 20);
      var now = 0;
      for (var round = 0; round < 3; round++) {
        game.start(now);
        now += SequenceGame.previewSeconds[round] * 1000;
        game.tick(now);
        for (final animal in game.pattern) {
          game.answer(animal, ++now);
        }
        expect(game.phase, GamePhase.roundOver);
        game.next();
      }
      expect(game.phase, GamePhase.complete);
      expect(game.total, 27);
    });
  });
  test(
    'path rejects skipped rows, locks after one error and keeps the route',
    () {
      final game = PathGame(7);
      game.start(0);
      game.tick(7800);
      expect(game.step(1, 0), isNull);
      expect(game.step(0, (game.level.route[0] + 1) % 3), false);
      expect(game.step(0, game.level.route[0]), isNull);
      final route = game.level.route;
      game.retry();
      game.start(10000);
      game.tick(17800);
      expect(game.level.route, route);
      for (var r = 0; r < game.level.rows; r++) {
        expect(game.step(r, route[r]), true);
      }
      expect(game.phase, GamePhase.complete);
    },
  );
}
