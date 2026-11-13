import 'dart:math';
import 'models.dart';

/// Stars for a cleared level by the failed attempts before it (3, 2, 1).
int starsAfter(int fails) => max(1, 3 - fails);

/// One Card Matching level. A move is one pair turned over; when the moves
/// run out before every pair is found the level is failed.
class MatchingGame {
  MatchingGame({this.level = 1, int? seed, this.fails = 0})
    : id = newId(),
      spec = MatchingLevel(level) {
    final rng = Random(seed);
    final selected = (animals.keys.toList()..shuffle(rng))
        .take(spec.pairs)
        .toList();
    board = [...selected, ...selected]..shuffle(rng);
  }
  late String id;
  final int level;
  final MatchingLevel spec;
  int fails;
  late List<String> board;
  final Set<int> matched = {};
  final List<int> opened = [];
  GamePhase phase = GamePhase.playing;
  int attempts = 0, elapsedMs = 0;
  int? feedbackUntil, lastTick;
  bool lastMatched = false;
  int get movesLeft => max(0, spec.moves - attempts);
  int get stars => spec.starsFor(attempts);

  bool select(int index, int now) {
    tick(now);
    if (phase != GamePhase.playing ||
        index < 0 ||
        index >= board.length ||
        matched.contains(index) ||
        opened.contains(index)) {
      return false;
    }
    lastTick ??= now;
    opened.add(index);
    if (opened.length == 2) {
      attempts++;
      lastMatched = board[opened[0]] == board[opened[1]];
      if (lastMatched) matched.addAll(opened);
      phase = GamePhase.feedback;
      feedbackUntil = now + (lastMatched ? 600 : 900);
    }
    return true;
  }

  bool tick(int now) {
    final running = phase != GamePhase.complete && phase != GamePhase.failed;
    if (lastTick != null && running) {
      elapsedMs += max(0, now - lastTick!);
    }
    if (lastTick != null) lastTick = now;
    if (phase == GamePhase.feedback && now >= feedbackUntil!) {
      opened.clear();
      feedbackUntil = null;
      phase = matched.length == board.length
          ? GamePhase.complete
          : attempts >= spec.moves
          ? GamePhase.failed
          : GamePhase.playing;
      if (phase != GamePhase.playing) lastTick = null;
      return true;
    }
    return false;
  }

  void pause(int now) {
    tick(now);
    lastTick = null;
  }

  Map<String, dynamic> toJson(int now) => {
    'id': id,
    'level': level,
    'fails': fails,
    'board': board,
    'matched': matched.toList(),
    'opened': opened,
    'phase': phase.name,
    'attempts': attempts,
    'elapsedMs': elapsedMs,
    'feedbackMs': feedbackUntil == null ? null : max(0, feedbackUntil! - now),
    'lastMatched': lastMatched,
  };
  factory MatchingGame.restore(Map<String, dynamic> j, int now) {
    final g = MatchingGame(
      level: intValue(j['level'], 1).clamp(1, levelCount),
      fails: max(0, intValue(j['fails'])),
    );
    final board = (j['board'] as List).cast<String>();
    if (board.length != g.spec.cards ||
        board.any((a) => !animals.containsKey(a)) ||
        board.toSet().length != g.spec.pairs ||
        board.toSet().any((a) => board.where((b) => a == b).length != 2)) {
      throw const FormatException('Invalid board');
    }
    final size = board.length;
    g.id = j['id'] as String;
    g.board = board;
    g.matched.addAll(
      (j['matched'] as List)
          .map((e) => intValue(e))
          .where((i) => i >= 0 && i < size),
    );
    g.opened.addAll(
      (j['opened'] as List)
          .map((e) => intValue(e))
          .where((i) => i >= 0 && i < size),
    );
    g.phase = GamePhase.values.byName(j['phase'] as String);
    g.attempts = intValue(j['attempts']);
    g.elapsedMs = intValue(j['elapsedMs']);
    g.lastMatched = j['lastMatched'] == true;
    if (g.phase == GamePhase.feedback) {
      g.feedbackUntil = now + intValue(j['feedbackMs']);
    }
    return g;
  }
}

/// One Sequence Memory level: study the cards, then name them in order.
/// A wrong animal or the clock running out fails the level.
class SequenceGame {
  SequenceGame({this.level = 1, int? seed, this.fails = 0})
    : id = newId(),
      spec = SequenceLevel(level),
      seed = seed ?? Random.secure().nextInt(1 << 30);
  String id;
  final int level, seed;
  final SequenceLevel spec;
  int fails;
  int answered = 0, elapsedMs = 0;
  GamePhase phase = GamePhase.ready;
  int? deadline, lastTick;
  bool wrong = false, timedOut = false;
  late final List<String> pattern =
      (animals.keys.toList()..shuffle(Random(seed))).take(spec.count).toList();
  int get stars => starsAfter(fails);

  void start(int now) {
    if (phase != GamePhase.ready) return;
    phase = GamePhase.preview;
    answered = 0;
    deadline = now + spec.previewMs;
    lastTick = now;
  }

  void _end(GamePhase result) {
    phase = result;
    deadline = null;
    lastTick = null;
  }

  bool tick(int now) {
    if (phase == GamePhase.playing && lastTick != null) {
      elapsedMs += max(0, min(now, deadline!) - lastTick!);
    }
    if (lastTick != null) lastTick = now;
    if (deadline == null || now < deadline!) return false;
    if (phase == GamePhase.preview) {
      phase = GamePhase.playing;
      deadline = now + spec.answerMs;
      lastTick = now;
      return true;
    }
    if (phase == GamePhase.playing) {
      timedOut = true;
      _end(GamePhase.failed);
      return true;
    }
    return false;
  }

  bool answer(String animal, int now) {
    tick(now);
    if (phase != GamePhase.playing) return false;
    if (pattern[answered] != animal) {
      wrong = true;
      _end(GamePhase.failed);
      return true;
    }
    answered++;
    if (answered == spec.count) _end(GamePhase.complete);
    return true;
  }

  void pause(int now) {
    tick(now);
    lastTick = null;
  }

  Map<String, dynamic> toJson(int now) => {
    'id': id,
    'level': level,
    'fails': fails,
    'seed': seed,
    'answered': answered,
    'elapsedMs': elapsedMs,
    'phase': phase.name,
    'remainingMs': deadline == null ? null : max(0, deadline! - now),
    'wrong': wrong,
    'timedOut': timedOut,
  };
  factory SequenceGame.restore(Map<String, dynamic> j, int now) {
    if (j['level'] == null) throw const FormatException('Old session');
    final g = SequenceGame(
      level: intValue(j['level'], 1).clamp(1, levelCount),
      seed: intValue(j['seed']),
      fails: max(0, intValue(j['fails'])),
    );
    g.id = j['id'] as String;
    g.answered = intValue(j['answered']).clamp(0, g.spec.count);
    g.elapsedMs = intValue(j['elapsedMs']);
    g.phase = GamePhase.values.byName(j['phase'] as String);
    g.wrong = j['wrong'] == true;
    g.timedOut = j['timedOut'] == true;
    if (g.phase == GamePhase.preview || g.phase == GamePhase.playing) {
      g.deadline = now + intValue(j['remainingMs']);
      g.lastTick = now;
    }
    return g;
  }
}

class PathGame {
  PathGame(int level, {this.fails = 0}) : level = LevelDefinition(level);
  final LevelDefinition level;
  String id = newId();
  int fails;
  GamePhase phase = GamePhase.ready;
  int row = 0;
  int? deadline, wrongColumn;
  int get stars => starsAfter(fails);

  void start(int now) {
    row = 0;
    wrongColumn = null;
    phase = GamePhase.preview;
    deadline = now + level.previewMs;
  }

  bool tick(int now) {
    if (phase == GamePhase.preview && now >= deadline!) {
      phase = GamePhase.playing;
      deadline = null;
      return true;
    }
    return false;
  }

  bool? step(int nextRow, int column) {
    if (phase != GamePhase.playing ||
        nextRow != row ||
        column < 0 ||
        column >= level.columns) {
      return null;
    }
    if (level.route[row] != column) {
      phase = GamePhase.feedback;
      wrongColumn = column;
      fails++;
      return false;
    }
    row++;
    if (row == level.rows) phase = GamePhase.complete;
    return true;
  }

  void retry() {
    row = 0;
    wrongColumn = null;
    phase = GamePhase.ready;
    deadline = null;
  }

  Map<String, dynamic> toJson(int now) => {
    'id': id,
    'level': level.number,
    'fails': fails,
    'phase': phase.name,
    'row': row,
    'remainingMs': deadline == null ? null : max(0, deadline! - now),
    'wrongColumn': wrongColumn,
  };
  factory PathGame.restore(Map<String, dynamic> j, int now) {
    final g = PathGame(
      intValue(j['level'], 1).clamp(1, 30),
      fails: max(0, intValue(j['fails'])),
    );
    g.id = j['id'] as String;
    g.row = intValue(j['row']).clamp(0, g.level.rows);
    g.phase = GamePhase.values.byName(j['phase'] as String);
    g.wrongColumn = j['wrongColumn'] as int?;
    if (g.phase == GamePhase.preview) {
      g.deadline = now + intValue(j['remainingMs']);
    }
    return g;
  }
}
