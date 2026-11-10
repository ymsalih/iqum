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
  group('Matching levels', () {
    test('board grows from 3 to 12 pairs with 1.5 moves per card', () {
      var pairs = 0;
      for (var n = 1; n <= levelCount; n++) {
        final level = MatchingLevel(n);
        expect(level.pairs, greaterThanOrEqualTo(pairs));
        expect(level.moves, level.cards * 3 ~/ 2);
        expect(level.columns * level.rows, level.cards);
        pairs = level.pairs;
      }
      expect(MatchingLevel(1).pairs, 3);
      expect(MatchingLevel(13).cards, 16);
      expect(MatchingLevel(13).moves, 24);
      expect(MatchingLevel(30).pairs, 12);
    });
    test('duplicates are ignored and mismatch locks input for 900 ms', () {
      final game = MatchingGame(level: 13, seed: 7),
          different = MatchingGame(level: 13, seed: 7);
      expect(game.board, different.board);
      expect(game.board.length, 16);
      final other = game.board.indexWhere((a) => a != game.board[0]);
      expect(game.select(0, 1000), true);
      expect(game.select(0, 1100), false);
      expect(game.attempts, 0);
      game.select(other, 1200);
      expect(game.attempts, 1);
      expect(game.movesLeft, 23);
      expect(game.phase, GamePhase.feedback);
      expect(game.select(5, 1250), false);
      expect(game.tick(2099), false);
      expect(game.tick(2100), true);
      expect(game.opened, isEmpty);
    });
    test('a perfect board finishes with three stars and restores intact', () {
      final game = MatchingGame(level: 13, seed: 12);
      var now = 1000;
      for (final animal in game.board.toSet()) {
        final indexes = [
          for (var i = 0; i < game.board.length; i++)
            if (game.board[i] == animal) i,
        ];
        game.select(indexes[0], now);
        game.select(indexes[1], now + 5);
        now += 700;
        game.tick(now);
      }
      expect(game.phase, GamePhase.complete);
      expect(game.attempts, 8);
      expect(game.stars, 3);
      final restored = MatchingGame.restore(game.toJson(now), now + 99999);
      expect(restored.board, game.board);
      expect(restored.level, 13);
      expect(restored.matched, game.matched);
    });
    test('running out of moves fails the level', () {
      final game = MatchingGame(level: 1, seed: 3);
      expect(game.spec.moves, 9);
      final a = game.board[0];
      final other = game.board.indexWhere((x) => x != a);
      var now = 0;
      for (var i = 0; i < 9; i++) {
        game.select(0, now);
        game.select(other, now + 1);
        now += 1000;
        game.tick(now);
      }
      expect(game.phase, GamePhase.failed);
      expect(game.select(1, now), false);
    });
    test('an old 16-card session without a level is rejected', () {
      final old = MatchingGame(level: 13, seed: 1).toJson(0)..remove('level');
      expect(() => MatchingGame.restore(old, 0), throwsFormatException);
    });
  });
  group('Sequence levels', () {
    test('cards grow from 3 to 12 and study time per card shrinks', () {
      var count = 0;
      for (var n = 1; n <= levelCount; n++) {
        final level = SequenceLevel(n);
        expect(level.count, greaterThanOrEqualTo(count));
        expect(level.columns * level.rows, greaterThanOrEqualTo(level.count));
        count = level.count;
      }
      expect(SequenceLevel(1).count, 3);
      expect(SequenceLevel(30).count, 12);
      expect(SequenceLevel(3).previewMs, lessThan(SequenceLevel(1).previewMs));
    });
    test('a wrong animal fails the level', () {
      final game = SequenceGame(level: 10, seed: 10);
      game.start(1000);
      expect(game.phase, GamePhase.preview);
      game.tick(1000 + game.spec.previewMs);
      expect(game.phase, GamePhase.playing);
      game.answer(game.pattern[0], 20000);
      final wrong = animals.keys.firstWhere((a) => a != game.pattern[1]);
      game.answer(wrong, 20100);
      expect(game.phase, GamePhase.failed);
      expect(game.wrong, true);
      expect(game.answer(game.pattern[1], 20200), false);
    });
    test('the answer clock running out fails the level', () {
      final game = SequenceGame(level: 1, seed: 3);
      game.start(0);
      game.tick(game.spec.previewMs);
      game.tick(game.spec.previewMs + game.spec.answerMs);
      expect(game.phase, GamePhase.failed);
      expect(game.timedOut, true);
    });
    test('suspension does not consume preview time', () {
      final game = SequenceGame(level: 4, seed: 3);
      game.start(1000);
      game.pause(2000);
      final restored = SequenceGame.restore(game.toJson(2000), 900000);
      expect(restored.phase, GamePhase.preview);
      expect(restored.deadline, 900000 + game.spec.previewMs - 1000);
      expect(restored.pattern, game.pattern);
    });
    test('a perfect level completes; stars fall with earlier failures', () {
      final game = SequenceGame(level: 30, seed: 20, fails: 1);
      game.start(0);
      game.tick(game.spec.previewMs);
      var now = game.spec.previewMs;
      for (final animal in game.pattern) {
        game.answer(animal, ++now);
      }
      expect(game.phase, GamePhase.complete);
      expect(game.answered, 12);
      expect(game.stars, 2);
    });
  });
  test('level stars keep the best digit and merge per level', () {
    var stars = LevelStars.clean('');
    expect(stars.length, levelCount);
    stars = LevelStars.raise(stars, 2, 3);
    stars = LevelStars.raise(stars, 2, 1);
    expect(LevelStars.of(stars, 2), 3);
    expect(LevelStars.merge(stars, '12'), '13${'0' * 28}');
    expect(LevelStars.total('321x'), 6);
  });
  test(
    'path rejects skipped rows, locks after one error and keeps the route',
    () {
      final game = PathGame(7);
      game.start(0);
      game.tick(7800);
      expect(game.step(1, 0), isNull);
      expect(game.step(0, (game.level.route[0] + 1) % 3), false);
      expect(game.fails, 1);
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
      expect(game.stars, 2);
    },
  );
}
