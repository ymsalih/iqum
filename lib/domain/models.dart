import 'dart:math';

enum GameKind { sequence, matching, path }

enum GamePhase { ready, preview, playing, feedback, roundOver, complete }

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

class PlayerProgress {
  const PlayerProgress({
    required this.life,
    this.level = 1,
    this.completedLevels = 0,
    this.points = 0,
    this.sequenceBest = 0,
    this.matchingBestMs,
    this.matchingBestAttempts,
    this.sound = true,
    this.haptics = true,
  });
  final LifeState life;
  final int level, completedLevels, points, sequenceBest;
  final int? matchingBestMs, matchingBestAttempts;
  final bool sound, haptics;
  PlayerProgress copyWith({
    LifeState? life,
    int? level,
    int? completedLevels,
    int? points,
    int? sequenceBest,
    int? matchingBestMs,
    int? matchingBestAttempts,
    bool? sound,
    bool? haptics,
  }) => PlayerProgress(
    life: life ?? this.life,
    level: level ?? this.level,
    completedLevels: completedLevels ?? this.completedLevels,
    points: points ?? this.points,
    sequenceBest: sequenceBest ?? this.sequenceBest,
    matchingBestMs: matchingBestMs ?? this.matchingBestMs,
    matchingBestAttempts: matchingBestAttempts ?? this.matchingBestAttempts,
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
  );
  Map<String, dynamic> toJson() => {
    'life': life.toJson(),
    'level': level,
    'completedLevels': completedLevels,
    'points': points,
    'sequenceBest': sequenceBest,
    'matchingBestMs': matchingBestMs,
    'matchingBestAttempts': matchingBestAttempts,
    'sound': sound,
    'haptics': haptics,
  };
  factory PlayerProgress.fromJson(
    Map<String, dynamic> j,
    int now, {
    bool trustedTime = false,
  }) => PlayerProgress(
    life: LifeState.fromJson(
      Map<String, dynamic>.from(j['life'] as Map? ?? {}),
      now,
      trustedTime: trustedTime,
    ),
    level: intValue(j['level'], 1).clamp(1, 30),
    completedLevels: intValue(j['completedLevels']).clamp(0, 30),
    points: max(0, intValue(j['points'])),
    sequenceBest: intValue(j['sequenceBest']).clamp(0, 27),
    matchingBestMs: j['matchingBestMs'] is num
        ? intValue(j['matchingBestMs'])
        : null,
    matchingBestAttempts: j['matchingBestAttempts'] is num
        ? intValue(j['matchingBestAttempts'])
        : null,
    sound: j['sound'] != false,
    haptics: j['haptics'] != false,
  );
}

class LevelDefinition {
  LevelDefinition(this.number) : assert(number >= 1 && number <= 30);
  final int number;
  int get columns => number <= 10
      ? 3
      : number <= 20
      ? 4
      : 5;
  int get rows => number <= 5
      ? 4
      : number <= 15
      ? 5
      : number <= 25
      ? 6
      : 8;
  int get previewMs => max(3000, 9000 - (number - 1) * 200);
  List<int> get route {
    var c = number % columns;
    return List.generate(rows, (r) {
      if (r > 0) c = (c + (number * 7 + r * 5) % 3 - 1).clamp(0, columns - 1);
      return c;
    });
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
