import 'dart:math';
import 'models.dart';

class MatchingGame {
  MatchingGame({int? seed}) : id = newId() {
    final selected = animals.keys.take(8).toList();
    board = [...selected, ...selected]..shuffle(Random(seed));
  }
  late String id;
  late List<String> board;
  final Set<int> matched = {};
  final List<int> opened = [];
  GamePhase phase = GamePhase.playing;
  int attempts = 0, elapsedMs = 0;
  int? feedbackUntil, lastTick;
  bool lastMatched = false;
  bool select(int index, int now) {
    tick(now);
    if (phase != GamePhase.playing ||
        index < 0 ||
        index >= 16 ||
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
    if (lastTick != null && phase != GamePhase.complete) {
      elapsedMs += max(0, now - lastTick!);
    }
    if (lastTick != null) lastTick = now;
    if (phase == GamePhase.feedback && now >= feedbackUntil!) {
      opened.clear();
      feedbackUntil = null;
      phase = matched.length == 16 ? GamePhase.complete : GamePhase.playing;
      if (phase == GamePhase.complete) lastTick = null;
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
    final g = MatchingGame(), board = (j['board'] as List).cast<String>();
    if (board.length != 16 ||
        board.any((a) => !animals.containsKey(a)) ||
        board.toSet().length != 8 ||
        board.toSet().any((a) => board.where((b) => a == b).length != 2)) {
      throw const FormatException('Invalid board');
    }
    g.id = j['id'] as String;
    g.board = board;
    g.matched.addAll(
      (j['matched'] as List)
          .map((e) => intValue(e))
          .where((i) => i >= 0 && i < 16),
    );
    g.opened.addAll(
      (j['opened'] as List)
          .map((e) => intValue(e))
          .where((i) => i >= 0 && i < 16),
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

class SequenceGame {
  SequenceGame({int? seed})
    : id = newId(),
      seed = seed ?? Random.secure().nextInt(1 << 30);
  String id;
  final int seed;
  int round = 0, answered = 0, total = 0, elapsedMs = 0;
  GamePhase phase = GamePhase.ready;
  int? deadline, lastTick;
  bool wrong = false;
  static const counts = [6, 9, 12],
      previewSeconds = [6, 8, 10],
      answerSeconds = [30, 45, 60];
  List<String> get pattern =>
      (animals.keys.toList()..shuffle(Random(seed + round)))
          .take(counts[round])
          .toList();
  void start(int now) {
    phase = GamePhase.preview;
    answered = 0;
    wrong = false;
    deadline = now + previewSeconds[round] * 1000;
    lastTick = now;
  }

  bool tick(int now) {
    if (phase == GamePhase.playing && lastTick != null) {
      elapsedMs += max(0, min(now, deadline!) - lastTick!);
    }
    if (lastTick != null) lastTick = now;
    if (deadline == null || now < deadline!) return false;
    if (phase == GamePhase.preview) {
      phase = GamePhase.playing;
      deadline = now + answerSeconds[round] * 1000;
      lastTick = now;
      return true;
    }
    if (phase == GamePhase.playing) {
      phase = GamePhase.roundOver;
      deadline = null;
      lastTick = null;
      return true;
    }
    return false;
  }

  bool answer(String animal, int now) {
    tick(now);
    if (phase != GamePhase.playing) return false;
    if (pattern[answered] != animal) {
      wrong = true;
      phase = GamePhase.roundOver;
      deadline = null;
      lastTick = null;
      return true;
    }
    answered++;
    total++;
    if (answered == counts[round]) {
      phase = GamePhase.roundOver;
      deadline = null;
      lastTick = null;
    }
    return true;
  }

  void next() {
    if (phase != GamePhase.roundOver) return;
    if (round == 2) {
      phase = GamePhase.complete;
      return;
    }
    round++;
    answered = 0;
    phase = GamePhase.ready;
    wrong = false;
  }

  void pause(int now) {
    tick(now);
    lastTick = null;
  }

  Map<String, dynamic> toJson(int now) => {
    'id': id,
    'seed': seed,
    'round': round,
    'answered': answered,
    'total': total,
    'elapsedMs': elapsedMs,
    'phase': phase.name,
    'remainingMs': deadline == null ? null : max(0, deadline! - now),
    'wrong': wrong,
  };
  factory SequenceGame.restore(Map<String, dynamic> j, int now) {
    final g = SequenceGame(seed: intValue(j['seed']));
    g.id = j['id'] as String;
    g.round = intValue(j['round']).clamp(0, 2);
    g.answered = intValue(j['answered']).clamp(0, counts[g.round]);
    g.total = intValue(j['total']).clamp(0, 27);
    g.elapsedMs = intValue(j['elapsedMs']);
    g.phase = GamePhase.values.byName(j['phase'] as String);
    g.wrong = j['wrong'] == true;
    if (g.phase == GamePhase.preview || g.phase == GamePhase.playing) {
      g.deadline = now + intValue(j['remainingMs']);
      g.lastTick = now;
    }
    return g;
  }
}

class PathGame {
  PathGame(int level) : level = LevelDefinition(level);
  final LevelDefinition level;
  String id = newId();
  GamePhase phase = GamePhase.ready;
  int row = 0;
  int? deadline, wrongColumn;
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
    'phase': phase.name,
    'row': row,
    'remainingMs': deadline == null ? null : max(0, deadline! - now),
    'wrongColumn': wrongColumn,
  };
  factory PathGame.restore(Map<String, dynamic> j, int now) {
    final g = PathGame(intValue(j['level'], 1).clamp(1, 30));
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
