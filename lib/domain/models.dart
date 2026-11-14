import 'dart:math';

enum GameKind { sequence, matching, path }

enum GamePhase {
  ready,
  preview,
  playing,
  feedback,
  roundOver,
  complete,
  failed,
}

const animals = <String, String>{
  'kus': 'Kuş',
  'tavsan': 'Tavşan',
  'balik': 'Balık',
  'kelebek': 'Kelebek',
  'kaplumbaga': 'Kaplumbağa',
  'kedi': 'Kedi',
  'tilki': 'Tilki',
  'fil': 'Fil',
  'at': 'At',
  'baykus': 'Baykuş',
  'salyangoz': 'Salyangoz',
  'denizati': 'Denizatı',
};
String newId() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

int intValue(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

class LifeState {
  const LifeState({this.count = 4, this.nextAt, required this.observedAt});
  static const interval = Duration(minutes: 30);
  final int count, observedAt;
  final int? nextAt;
  LifeState rebaseFuture(int now) {
    if (observedAt <= now) return this;
    final claimed =
        (nextAt ?? observedAt + interval.inMilliseconds) - observedAt;
    final remaining = claimed <= 0
        ? interval.inMilliseconds
        : min(claimed, interval.inMilliseconds);
    return LifeState(
      count: count,
      nextAt: count == 4 ? null : now + remaining,
      observedAt: now,
    );
  }

  LifeState at(int now) {
    final effective = max(now, observedAt);
    if (count >= 4) return LifeState(observedAt: effective);
    final next = nextAt ?? effective + interval.inMilliseconds;
    final recovered = effective < next
        ? 0
        : 1 + (effective - next) ~/ interval.inMilliseconds;
    final updated = min(4, count + recovered);
    return LifeState(
      count: updated,
      nextAt: updated == 4 ? null : next + recovered * interval.inMilliseconds,
      observedAt: effective,
    );
  }

  LifeState spend(int now) {
    final current = at(now);
    if (current.count == 0) return current;
    return LifeState(
      count: current.count - 1,
      nextAt: current.nextAt ?? current.observedAt + interval.inMilliseconds,
      observedAt: current.observedAt,
    );
  }

  LifeState merge(LifeState other, int now) {
    final a = at(now), b = other.at(now);
    final count = min(a.count, b.count);
    return LifeState(
      count: count,
      nextAt: count == 4 ? null : max(a.nextAt ?? now, b.nextAt ?? now),
      observedAt: max(a.observedAt, b.observedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'count': count,
    'nextAt': nextAt,
    'observedAt': observedAt,
  };
  factory LifeState.fromJson(
    Map<String, dynamic> json,
    int now, {
    bool trustedTime = false,
  }) {
    final life = LifeState(
      count: intValue(json['count'], 4).clamp(0, 4),
      nextAt: json['nextAt'] is num ? intValue(json['nextAt']) : null,
      observedAt: intValue(json['observedAt'], now),
    );
    return (trustedTime ? life.rebaseFuture(now) : life).at(now);
  }
}

/// Number of levels in every solo game.
const levelCount = 30;

/// Best stars per level as a 30-character string of digits 0–3
/// ("3210…"). Merging two devices keeps the higher digit of each level.
abstract final class LevelStars {
  static String clean(dynamic value) {
    final raw = value is String ? value : '';
    final digits = List.generate(levelCount, (i) {
      final c = i < raw.length ? raw.codeUnitAt(i) - 48 : 0;
      return c < 0 || c > 3 ? 0 : c;
    });
    return digits.join();
  }

  static int of(String stars, int level) =>
      level < 1 || level > stars.length ? 0 : stars.codeUnitAt(level - 1) - 48;

  static String raise(String stars, int level, int value) {
    final s = clean(stars);
    if (level < 1 || level > levelCount || of(s, level) >= value) return s;
    return s.replaceRange(level - 1, level, '${value.clamp(0, 3)}');
  }

  static String merge(String a, String b) {
    final x = clean(a), y = clean(b);
    return List.generate(
      levelCount,
      (i) => max(x.codeUnitAt(i), y.codeUnitAt(i)) - 48,
    ).join();
  }

  static int total(String stars) =>
      clean(stars).codeUnits.fold(0, (sum, c) => sum + c - 48);
}

/// Lifetime counters for one solo game. Counters only grow, so two devices
/// merge by keeping the larger value of each (never double counting).
class GameStats {
  const GameStats({
    this.played = 0,
    this.cleared = 0,
    this.failed = 0,
    this.timeMs = 0,
    this.perfect = 0,
  });
  final int played, cleared, failed, timeMs, perfect;
  int get successRate => played == 0 ? 0 : (cleared * 100 / played).round();
  GameStats add({bool cleared = false, int timeMs = 0, bool perfect = false}) =>
      GameStats(
        played: played + 1,
        cleared: this.cleared + (cleared ? 1 : 0),
        failed: failed + (cleared ? 0 : 1),
        timeMs: this.timeMs + max(0, timeMs),
        perfect: this.perfect + (perfect ? 1 : 0),
      );
  GameStats merge(GameStats o) => GameStats(
    played: max(played, o.played),
    cleared: max(cleared, o.cleared),
    failed: max(failed, o.failed),
    timeMs: max(timeMs, o.timeMs),
    perfect: max(perfect, o.perfect),
  );
  Map<String, dynamic> toJson() => {
    'played': played,
    'cleared': cleared,
    'failed': failed,
    'timeMs': timeMs,
    'perfect': perfect,
  };
  factory GameStats.fromJson(dynamic j) {
    final m = j is Map ? j : const {};
    int n(String k) => max(0, intValue(m[k]));
    return GameStats(
      played: n('played'),
      cleared: n('cleared'),
      failed: n('failed'),
      timeMs: n('timeMs'),
      perfect: n('perfect'),
    );
  }
}

class PlayerProgress {
  const PlayerProgress({
    required this.life,
    this.level = 1,
    this.completedLevels = 0,
    this.sequenceLevel = 1,
    this.matchingLevel = 1,
    this.stars = const {},
    this.stats = const {},
    this.points = 0,
    this.sequenceBest = 0,
    this.matchingBestMs,
    this.matchingBestAttempts,
    this.duelPlayed = 0,
    this.duelWon = 0,
    this.duelDrawn = 0,
    this.sound = true,
    this.haptics = true,
  });
  final LifeState life;

  /// Memory Path: next level to play and number of cleared levels.
  final int level, completedLevels;

  /// Sequence Memory / Card Matching: next level to play (1–30).
  final int sequenceLevel, matchingLevel;

  /// Best stars per level, keyed by [GameKind.name].
  final Map<String, String> stars;
  final Map<String, GameStats> stats;
  final int points, sequenceBest, duelPlayed, duelWon, duelDrawn;
  final int? matchingBestMs, matchingBestAttempts;
  final bool sound, haptics;

  int unlocked(GameKind game) => switch (game) {
    GameKind.path => level,
    GameKind.sequence => sequenceLevel,
    GameKind.matching => matchingLevel,
  };

  /// Stars shown for a level. Levels cleared before stars existed show one.
  int starsOf(GameKind game, int n) {
    final best = LevelStars.of(LevelStars.clean(stars[game.name]), n);
    final passed = game == GameKind.path
        ? n <= completedLevels
        : n < unlocked(game);
    return max(best, passed ? 1 : 0);
  }

  int cleared(GameKind game) => [
    for (var n = 1; n <= levelCount; n++)
      if (starsOf(game, n) > 0) n,
  ].length;
  int totalStars(GameKind game) => [
    for (var n = 1; n <= levelCount; n++) starsOf(game, n),
  ].fold(0, (a, b) => a + b);
  GameStats statsOf(GameKind game) => stats[game.name] ?? const GameStats();

  PlayerProgress copyWith({
    LifeState? life,
    int? level,
    int? completedLevels,
    int? sequenceLevel,
    int? matchingLevel,
    Map<String, String>? stars,
    Map<String, GameStats>? stats,
    int? points,
    int? sequenceBest,
    int? matchingBestMs,
    int? matchingBestAttempts,
    int? duelPlayed,
    int? duelWon,
    int? duelDrawn,
    bool? sound,
    bool? haptics,
  }) => PlayerProgress(
    life: life ?? this.life,
    level: level ?? this.level,
    completedLevels: completedLevels ?? this.completedLevels,
    sequenceLevel: sequenceLevel ?? this.sequenceLevel,
    matchingLevel: matchingLevel ?? this.matchingLevel,
    stars: stars ?? this.stars,
    stats: stats ?? this.stats,
    points: points ?? this.points,
    sequenceBest: sequenceBest ?? this.sequenceBest,
    matchingBestMs: matchingBestMs ?? this.matchingBestMs,
    matchingBestAttempts: matchingBestAttempts ?? this.matchingBestAttempts,
    duelPlayed: duelPlayed ?? this.duelPlayed,
    duelWon: duelWon ?? this.duelWon,
    duelDrawn: duelDrawn ?? this.duelDrawn,
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
  );
  Map<String, dynamic> toJson() => {
    'life': life.toJson(),
    'level': level,
    'completedLevels': completedLevels,
    'sequenceLevel': sequenceLevel,
    'matchingLevel': matchingLevel,
    'stars': {
      for (final g in GameKind.values) g.name: LevelStars.clean(stars[g.name]),
    },
    'stats': {for (final e in stats.entries) e.key: e.value.toJson()},
    'points': points,
    'sequenceBest': sequenceBest,
    'matchingBestMs': matchingBestMs,
    'matchingBestAttempts': matchingBestAttempts,
    'played': duelPlayed,
    'won': duelWon,
    'drawn': duelDrawn,
    'sound': sound,
    'haptics': haptics,
  };
  factory PlayerProgress.fromJson(
    Map<String, dynamic> j,
    int now, {
    bool trustedTime = false,
  }) {
    final starMap = j['stars'] is Map ? j['stars'] as Map : const {};
    final statMap = j['stats'] is Map ? j['stats'] as Map : const {};
    return PlayerProgress(
      life: LifeState.fromJson(
        Map<String, dynamic>.from(j['life'] as Map? ?? {}),
        now,
        trustedTime: trustedTime,
      ),
      level: intValue(j['level'], 1).clamp(1, levelCount),
      completedLevels: intValue(j['completedLevels']).clamp(0, levelCount),
      sequenceLevel: intValue(j['sequenceLevel'], 1).clamp(1, levelCount),
      matchingLevel: intValue(j['matchingLevel'], 1).clamp(1, levelCount),
      stars: {
        for (final g in GameKind.values)
          g.name: LevelStars.clean(starMap[g.name]),
      },
      stats: {
        for (final g in GameKind.values)
          if (statMap[g.name] is Map)
            g.name: GameStats.fromJson(statMap[g.name]),
      },
      points: max(0, intValue(j['points'])),
      sequenceBest: intValue(j['sequenceBest']).clamp(0, 27),
      matchingBestMs: j['matchingBestMs'] is num
          ? intValue(j['matchingBestMs'])
          : null,
      matchingBestAttempts: j['matchingBestAttempts'] is num
          ? intValue(j['matchingBestAttempts'])
          : null,
      duelPlayed: max(0, intValue(j['played'])),
      duelWon: max(0, intValue(j['won'])),
      duelDrawn: max(0, intValue(j['drawn'])),
      sound: j['sound'] != false,
      haptics: j['haptics'] != false,
    );
  }
}

/// Sequence Memory level: more cards and less study time as levels rise.
class SequenceLevel {
  SequenceLevel(this.number) : assert(number >= 1 && number <= levelCount);
  final int number;

  /// Every level is harder than the one before: the cards grow from 4 to
  /// 12 and the study time per card shrinks on every level (1.2 → 0.62 s).
  int get count => 4 + (number - 1) * 8 ~/ 29;
  int get columns => switch (count) {
    3 => 3,
    4 => 2,
    5 || 6 || 9 => 3,
    _ => 4,
  };
  int get rows => (count / columns).ceil();
  int get msPerCard => 1200 - (number - 1) * 20;
  int get previewMs => count * msPerCard;
  int get answerMs => count * 4000;
}

/// Card Matching level: board grows from 3 to 12 pairs. A move is one pair
/// turned over; the player has 1.5 moves per card on the table.
class MatchingLevel {
  MatchingLevel(this.number) : assert(number >= 1 && number <= levelCount);
  final int number;
  int get pairs => number <= 3
      ? 3
      : number <= 7
      ? 4
      : number <= 12
      ? 6
      : number <= 18
      ? 8
      : number <= 24
      ? 10
      : 12;
  int get cards => pairs * 2;
  int get columns => cards == 6 ? 3 : 4;
  int get rows => cards ~/ columns;
  int get moves => cards * 3 ~/ 2;

  /// Stars for a cleared board by the moves used.
  int starsFor(int attempts) => attempts <= (pairs * 1.75).ceil()
      ? 3
      : attempts <= (pairs * 2.25).ceil()
      ? 2
      : 1;
}

class LevelDefinition {
  LevelDefinition(this.number) : assert(number >= 1 && number <= 30);
  final int number;

  /// Every level is harder than the one before: each three levels add a
  /// row (one more step to remember) and within them the board widens
  /// from 3 to 5 columns (more places a step can hide). 3×3 … 5×12.
  int get columns => 3 + (number - 1) % 3;
  int get rows => 3 + (number - 1) ~/ 3;

  /// Study time: half a second per tile, rounded down to whole seconds
  /// (3×3 → 4 s, 5×12 → 30 s).
  int get previewMs => columns * rows ~/ 2 * 1000;

  /// The safe tile of each row, bottom to top. Rows are independent: a
  /// step never stays in the same column, and on boards of 4–5 columns it
  /// always jumps at least one column, so the route never reads as a line.
  /// Seeded by the level number: a retry shows the same route.
  List<int> get route {
    final rng = Random(number * 7919 + 17);
    final steps = <int>[rng.nextInt(columns)];
    for (var r = 1; r < rows; r++) {
      final previous = steps.last;
      final choices = [
        for (var c = 0; c < columns; c++)
          if (c != previous && (columns < 4 || (c - previous).abs() >= 2)) c,
      ];
      steps.add(choices[rng.nextInt(choices.length)]);
    }
    return steps;
  }
}

class RunRecord {
  RunRecord({
    required this.id,
    required this.game,
    required this.finishedAt,
    required this.data,
  });
  final String id;
  final GameKind game;
  final int finishedAt;
  final Map<String, dynamic> data;
  Map<String, dynamic> toJson() => {
    'id': id,
    'game': game.name,
    'finishedAt': finishedAt,
    'data': data,
  };
}
