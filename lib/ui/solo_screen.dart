import 'premium_motion.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/app_controller.dart';
import '../domain/games.dart';
import '../domain/models.dart';
import 'components.dart';
import 'game_layout.dart';
import 'responsive.dart';
import 'theme.dart';

const gameTitles = {
  GameKind.path: 'Hafıza Yolu',
  GameKind.sequence: 'Sıra Hafızası',
  GameKind.matching: 'Kart Eşleştirme',
};

/// One level of a solo game. Every game is played level by level; a failed
/// attempt costs one heart, a cleared level earns one to three stars.
class SoloScreen extends ConsumerStatefulWidget {
  const SoloScreen(this.kind, {super.key, this.level = 1});
  final GameKind kind;
  final int level;
  @override
  ConsumerState<SoloScreen> createState() => _SoloScreenState();
}

class _SoloScreenState extends ConsumerState<SoloScreen>
    with WidgetsBindingObserver {
  MatchingGame? matching;
  SequenceGame? sequence;
  PathGame? path;
  Timer? _timer;
  bool _loaded = false, _done = false, _paused = false, _disposed = false;
  bool _failing = false;

  /// When the second card of a pair has finished turning. Until then the
  /// pair's result (sound, note, counter) stays hidden.
  int _judgeAt = 0;
  Timer? _judge;

  /// "Get ready" count (3, 2, 1) before a level's study phase starts by
  /// itself; null when no countdown is running.
  int? _countdown;
  Timer? _countTimer;

  /// Memory Path and Sequence Memory open straight into their study phase.
  void _autoStart() {
    if (_disposed || _paused || _countTimer != null || !_loaded) return;
    final waiting =
        path?.phase == GamePhase.ready || sequence?.phase == GamePhase.ready;
    if (!waiting || _hearts == 0) return;
    setState(() => _countdown = 3);
    _countTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted || _paused) return;
      final next = (_countdown ?? 1) - 1;
      if (next > 0) {
        setState(() => _countdown = next);
        return;
      }
      timer.cancel();
      _countTimer = null;
      _countdown = null;
      if (path?.phase == GamePhase.ready) {
        path!.start(now);
      } else if (sequence?.phase == GamePhase.ready) {
        sequence!.start(now);
      }
      setState(() {});
      unawaited(_save());
    });
  }

  void _stopCountdown() {
    _countTimer?.cancel();
    _countTimer = null;
    _countdown = null;
  }

  late String _scope;
  Map<String, dynamic>? _pausedSnapshot;
  Future<void> _writes = Future.value();
  final ValueNotifier<int> _elapsed = ValueNotifier(0);
  late final AppController app = ref.read(appProvider);
  int get now => app.now;
  GamePhase get phase => switch (widget.kind) {
    GameKind.matching => matching!.phase,
    GameKind.sequence => sequence!.phase,
    GameKind.path => path!.phase,
  };
  int get _hearts => app.progress.life.at(app.now).count;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    _scope = app.scope;
    final snapshot = await app.store.readSession(_scope, widget.kind);
    try {
      _restore(snapshot);
    } catch (_) {
      await app.store.discardInvalidSession(_scope, widget.kind);
      _restore(null);
    }
    if (!mounted) return;
    if (phase == GamePhase.complete) {
      await app.store.clearSession(_scope, widget.kind);
      _restore(null);
    }
    setState(() => _loaded = true);
    _runTimer();
    await app.refreshLife();
    if (!mounted) return;
    if (_hearts == 0 && !_inProgress) {
      unawaited(showNoHearts(context, app));
    } else {
      _autoStart();
    }
  }

  void _restore(Map<String, dynamic>? data) {
    // A saved attempt continues only on the level it belongs to.
    final same = data != null && intValue(data['level'], 1) == widget.level;
    switch (widget.kind) {
      case GameKind.matching:
        matching = same
            ? MatchingGame.restore(data, now)
            : MatchingGame(level: widget.level);
        if (matching!.attempts > 0 ||
            matching!.elapsedMs > 0 ||
            matching!.opened.isNotEmpty) {
          if (matching!.phase == GamePhase.playing ||
              matching!.phase == GamePhase.feedback) {
            matching!.lastTick = now;
          }
        }
        _elapsed.value = matching!.elapsedMs ~/ 1000;
        break;
      case GameKind.sequence:
        sequence = same
            ? SequenceGame.restore(data, now)
            : SequenceGame(level: widget.level);
        break;
      case GameKind.path:
        path = same ? PathGame.restore(data, now) : PathGame(widget.level);
        break;
    }
  }

  /// True while an attempt is running: leaving keeps it, restarting burns it.
  bool get _inProgress => switch (widget.kind) {
    GameKind.matching =>
      (matching!.phase == GamePhase.playing ||
              matching!.phase == GamePhase.feedback) &&
          (matching!.attempts > 0 || matching!.opened.isNotEmpty),
    GameKind.sequence =>
      sequence!.phase == GamePhase.preview ||
          sequence!.phase == GamePhase.playing,
    GameKind.path => false,
  };

  Map<String, dynamic> _snapshot() => switch (widget.kind) {
    GameKind.matching => matching!.toJson(now),
    GameKind.sequence => sequence!.toJson(now),
    GameKind.path => path!.toJson(now),
  };
  Future<void> _save() {
    if (!_loaded || _done) return _writes;
    final snapshot = _snapshot();
    final store = app.store;
    _runTimer();
    _writes = _writes.then(
      (_) => store.saveSession(_scope, widget.kind, snapshot),
    );
    return _writes;
  }

  void _runTimer() {
    _timer?.cancel();
    // The final save in dispose must not restart the 100 ms game tick.
    if (_disposed) return;
    final running =
        matching?.lastTick != null ||
        sequence?.phase == GamePhase.preview ||
        sequence?.phase == GamePhase.playing ||
        path?.phase == GamePhase.preview ||
        path?.phase == GamePhase.feedback;
    if (!_paused && running) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _tick(),
      );
    }
  }

  void _tick() {
    if (!_loaded || _done || !mounted || _paused) return;
    var changed = switch (widget.kind) {
      GameKind.matching => matching!.tick(now),
      GameKind.sequence => sequence!.tick(now),
      GameKind.path => path!.tick(now),
    };
    if (matching != null) _elapsed.value = matching!.elapsedMs ~/ 1000;
    if (path?.phase == GamePhase.feedback &&
        path?.deadline != null &&
        now >= path!.deadline!) {
      path!.retry();
      changed = true;
    }
    if (changed) _changed();
  }

  /// Routes a state change: finish, fail (costs a heart) or just save.
  void _changed() {
    if (phase == GamePhase.complete) {
      unawaited(_finish());
    } else if (phase == GamePhase.failed) {
      setState(() {});
      unawaited(_fail());
    } else {
      setState(() {});
      unawaited(_save());
      if (phase == GamePhase.ready) _autoStart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_loaded || _done) return;
    if (state != AppLifecycleState.resumed && !_paused) {
      _paused = true;
      _timer?.cancel();
      _stopCountdown();
      matching?.pause(now);
      sequence?.pause(now);
      _pausedSnapshot = _snapshot();
      unawaited(_save());
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      _restore(_pausedSnapshot);
      _runTimer();
      unawaited(app.refreshLife());
      setState(() {});
      _autoStart();
    }
  }

  /// A failed level: one heart and the failed attempt, saved together.
  Future<void> _fail() async {
    if (_failing) return;
    _failing = true;
    _timer?.cancel();
    // Matching already sounded the miss when the last pair was judged.
    if (widget.kind != GameKind.matching) unawaited(app.feedback('error'));
    try {
      await _writes;
      await app.spendHeart(
        game: widget.kind,
        session: _snapshot(),
        elapsedMs: matching?.elapsedMs ?? sequence?.elapsedMs ?? 0,
      );
    } catch (_) {
      if (mounted) {
        showError(context, 'Can durumu kaydedilemedi. Tekrar deneyebilirsin.');
      }
    } finally {
      _failing = false;
    }
    if (mounted) {
      setState(() {});
      if (_hearts == 0) unawaited(showNoHearts(context, app));
    }
  }

  /// A new attempt at the same level (earlier failures lower the stars).
  void _retry() {
    if (_hearts == 0) {
      unawaited(showNoHearts(context, app));
      return;
    }
    switch (widget.kind) {
      case GameKind.matching:
        matching = MatchingGame(
          level: widget.level,
          fails: matching!.fails + 1,
        );
        _elapsed.value = 0;
        break;
      case GameKind.sequence:
        sequence = SequenceGame(
          level: widget.level,
          fails: sequence!.fails + 1,
        );
        break;
      case GameKind.path:
        path = PathGame(widget.level, fails: path!.fails);
        break;
    }
    setState(() {});
    unawaited(_save());
    _autoStart();
  }

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    final RunRecord record;
    final String detail;
    final int stars;
    switch (widget.kind) {
      case GameKind.matching:
        final g = matching!;
        stars = g.stars;
        detail =
            '${g.attempts} / ${g.spec.moves} hamle · ${clockText(g.elapsedMs)}';
        record = RunRecord(
          id: g.id,
          game: widget.kind,
          finishedAt: now,
          data: {
            'level': g.level,
            'pairs': g.spec.pairs,
            'attempts': g.attempts,
            'elapsedMs': g.elapsedMs,
            'stars': stars,
          },
        );
        break;
      case GameKind.sequence:
        final g = sequence!;
        stars = g.stars;
        detail = '${g.spec.count} kart · ${clockText(g.elapsedMs)}';
        record = RunRecord(
          id: g.id,
          game: widget.kind,
          finishedAt: now,
          data: {
            'level': g.level,
            'correct': g.spec.count,
            'elapsedMs': g.elapsedMs,
            'stars': stars,
          },
        );
        break;
      case GameKind.path:
        final g = path!;
        stars = g.stars;
        detail = '${g.level.rows} adım · ${g.level.columns} sütun';
        record = RunRecord(
          id: g.id,
          game: widget.kind,
          finishedAt: now,
          data: {'level': g.level.number, 'stars': stars},
        );
        break;
    }
    try {
      await _writes;
      await app.complete(record);
    } catch (_) {
      _done = false;
      if (mounted) {
        showError(context, 'Sonuç kaydedilemedi. Tekrar deneyebilirsin.');
        setState(() {});
      }
      return;
    }
    if (!mounted) return;
    unawaited(app.feedback('success'));
    final last = widget.level == levelCount;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          eyebrow:
              '${gameTitles[widget.kind]!.toUpperCase()} · LEVEL ${widget.level}',
          title: stars == 3
              ? 'Kusursuz!'
              : stars == 2
              ? 'Harika iş.'
              : 'Level geçildi.',
          subtitle: last
              ? 'Bütün levelleri tamamladın. Yıldızlarını artırmak için tekrar oyna.'
              : stars == 3
              ? 'Hiç hata yapmadan geçtin.'
              : 'Daha az hatayla daha çok yıldız toplarsın.',
          summary: 'Level ${widget.level}',
          detail: detail,
          stars: stars,
          nextLabel: last ? 'Levellere dön' : 'Sonraki level',
          onNext: (context) {
            if (last) {
              Navigator.pop(context);
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    SoloScreen(widget.kind, level: widget.level + 1),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _restart() async {
    final burns = _inProgress;
    final restart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Yeniden başla', style: AppColors.display(24)),
        content: Text(
          burns
              ? 'Devam eden deneme yanmış sayılır ve 1 can gider.'
              : 'Level baştan başlayacak. Yıldızların ve rekorların korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(burns ? '1 can ver, baştan başla' : 'Yeniden başla'),
          ),
        ],
      ),
    );
    if (restart != true || !mounted) return;
    if (burns) {
      if (matching != null) matching!.phase = GamePhase.failed;
      if (sequence != null) {
        sequence!.phase = GamePhase.failed;
        sequence!.deadline = null;
        sequence!.lastTick = null;
      }
      await _fail();
      if (!mounted) return;
      _retry();
      return;
    }
    switch (widget.kind) {
      case GameKind.matching:
        matching = MatchingGame(level: widget.level, fails: matching!.fails);
        _elapsed.value = 0;
        break;
      case GameKind.sequence:
        sequence = SequenceGame(level: widget.level, fails: sequence!.fails);
        break;
      case GameKind.path:
        path = PathGame(widget.level, fails: path!.fails);
        break;
    }
    _stopCountdown();
    setState(() {});
    await _save();
    _autoStart();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _judge?.cancel();
    _countTimer?.cancel();
    if (_loaded && !_done) {
      matching?.pause(now);
      sequence?.pause(now);
      unawaited(_save());
    }
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(appProvider).progress;
    final gutter = Responsive.gutter(context);
    final _Screen? screen = !_loaded
        ? null
        : switch (widget.kind) {
            GameKind.matching => _matching(progress),
            GameKind.sequence => _sequence(progress),
            GameKind.path => _path(progress),
          };
    return GameScaffold(
      label: '${gameTitles[widget.kind]} · Level ${widget.level}',
      actions: [
        IconButton(
          onPressed: _loaded ? _restart : null,
          tooltip: 'Yeniden başla',
          icon: const Icon(Icons.restart_alt_rounded, size: 24),
        ),
        const SizedBox(width: 9),
      ],
      child: screen == null
          ? const Center(child: CircularProgressIndicator())
          : GameLayout(
              padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 14),
              aspect: screen.fit.aspect,
              chrome: screen.fit.chrome,
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_levelHeader(progress), ...screen.header],
              ),
              board: screen.board,
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: screen.footer,
              ),
            ),
    );
  }

  Widget _levelHeader(PlayerProgress progress) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Level ${widget.level.toString().padLeft(2, '0')}',
              style: AppColors.display(30),
            ),
          ),
        ),
        const SizedBox(width: 10),
        HeartRow(progress.life.at(app.now).count, size: 22),
      ],
    ),
  );

  /// Shared footer when an attempt failed: why, and a new attempt.
  List<Widget> _failedFooter(String reason) => [
    GameNote('$reason −1 can.', error: true),
    IqumButton(
      _hearts == 0 ? 'Canların yenileniyor' : 'Tekrar dene',
      accent: _hearts > 0,
      icon: _hearts == 0
          ? Icons.hourglass_bottom_rounded
          : Icons.replay_rounded,
      onPressed: _failing ? null : _retry,
    ),
  ];

  _Screen _matching(PlayerProgress progress) {
    final g = matching!, spec = g.spec;
    final judged = g.phase != GamePhase.feedback || app.now >= _judgeAt;
    final wrongPair = g.phase == GamePhase.feedback && !g.lastMatched;
    final pairs =
        g.matched.length ~/ 2 -
        (!judged && g.phase == GamePhase.feedback && g.lastMatched ? 1 : 0);
    final low = g.movesLeft <= math.max(2, spec.pairs ~/ 2);
    final canPlay =
        g.phase == GamePhase.playing && (_hearts > 0 || _inProgress);
    return (
      fit: GameLayout.grid(
        columns: spec.columns,
        rows: spec.rows,
        tileAspect: .8,
      ),
      header: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            StatPill(
              label: 'ÇİFT',
              icon: Icons.style_rounded,
              value: ScoreNumber(pairs, suffix: '/${spec.pairs}'),
            ),
            StatPill(
              label: 'HAMLE',
              icon: Icons.touch_app_rounded,
              dark: low,
              value: Text('${g.movesLeft}/${spec.moves}'),
            ),
            StatPill(
              label: '',
              icon: Icons.timer_rounded,
              value: ValueListenableBuilder<int>(
                valueListenable: _elapsed,
                builder: (_, seconds, _) => Text(clockText(seconds * 1000)),
              ),
            ),
          ],
        ),
      ],
      board: Board(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: spec.columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 10,
            childAspectRatio: .8,
          ),
          itemCount: spec.cards,
          itemBuilder: (context, i) => MemoryTile(
            key: ValueKey('match-${g.id}-$i'),
            index: i,
            animal: g.board[i],
            open: g.opened.contains(i) || g.matched.contains(i),
            matched: g.matched.contains(i),
            wrong: wrongPair && g.opened.contains(i),
            onTap: canPlay && !g.matched.contains(i)
                ? () {
                    if (g.select(i, now)) {
                      setState(() {});
                      unawaited(app.feedback('flip'));
                      if (g.opened.length == 2) {
                        _judgeAt = now + MotionTokens.flip.inMilliseconds;
                        _judge?.cancel();
                        _judge = Timer(MotionTokens.flip, () {
                          if (!mounted) return;
                          setState(() {});
                          unawaited(
                            app.feedback(g.lastMatched ? 'success' : 'error'),
                          );
                        });
                      }
                      _runTimer();
                      unawaited(_save());
                    }
                  }
                : null,
          ),
        ),
      ),
      footer: g.phase == GamePhase.failed
          ? _failedFooter('Hamlelerin bitti.')
          : [
              GameNote(
                g.phase == GamePhase.feedback && !judged
                    ? 'İkinci kart açılıyor…'
                    : g.phase == GamePhase.feedback
                    ? (g.lastMatched
                          ? 'Bir çift daha hatırladın.'
                          : 'Bu ikisi farklı. Yerlerini aklında tut.')
                    : g.attempts == 0
                    ? '${spec.moves} hamlede ${spec.pairs} çifti bul. '
                          'Az hamle, çok yıldız.'
                    : low
                    ? 'Son ${g.movesLeft} hamle. Dikkatli seç.'
                    : 'Bir kart aç. Eşi aklında mı?',
                error: wrongPair && judged,
              ),
              if (_hearts == 0 && !_inProgress)
                IqumButton(
                  'Canların yenileniyor',
                  icon: Icons.hourglass_bottom_rounded,
                  onPressed: () => showNoHearts(context, app),
                ),
            ],
    );
  }

  _Screen _sequence(PlayerProgress progress) {
    final g = sequence!,
        spec = g.spec,
        answering = g.phase == GamePhase.playing,
        preview = g.phase == GamePhase.preview,
        failed = g.phase == GamePhase.failed;
    final keyColumns = MediaQuery.sizeOf(context).width >= 340 ? 6 : 4;
    return (
      fit: GameLayout.grid(
        columns: spec.columns,
        rows: spec.rows,
        tileAspect: .9,
      ),
      header: [
        _Callout(
          state: failed
              ? _CallState.burned
              : _countdown != null
              ? _CallState.ready
              : preview
              ? _CallState.study
              : answering
              ? _CallState.play
              : _hearts == 0
              ? _CallState.resting
              : _CallState.ready,
          countdown: _countdown,
          study: 'Kartları ezberle!',
          studyHint:
              '${spec.count} hayvanı ve sırasını süre bitene kadar aklında tut.',
          play: 'Sıra sende!',
          playHint: 'Kartları sırayla bul: ${g.answered}/${spec.count}',
          burned: g.timedOut ? 'Süre doldu! −1 can' : 'Yanlış hayvan! −1 can',
        ),
        ClockStrip(
          now: () => app.now,
          label: preview
              ? 'Ezber süresi'
              : answering
              ? 'Cevap süresi'
              : '${spec.count} kart',
          deadline: g.deadline,
          totalMs: preview ? spec.previewMs : spec.answerMs,
          trailing: g.deadline == null
              ? '${(spec.previewMs / 1000).toStringAsFixed(1).replaceAll('.', ',')} sn'
              : null,
        ),
      ],
      board: Board(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: spec.columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 10,
            childAspectRatio: .9,
          ),
          itemCount: spec.count,
          itemBuilder: (context, i) => MemoryTile(
            key: ValueKey('seq-${g.id}-$i'),
            index: i,
            number: i + 1,
            animal: g.pattern[i],
            // After a miss, the card that was asked for turns over in coral
            // so the player sees what it was.
            open: preview || i < g.answered || (failed && i == g.answered),
            matched: i < g.answered,
            wrong: failed && i == g.answered,
            highlight: answering && i == g.answered,
          ),
        ),
      ),
      footer: [
        if (failed)
          ..._failedFooter(g.timedOut ? 'Süre doldu.' : 'Bu hayvan farklıydı.')
        else if (answering) ...[
          const GameNote('Kartlar kapandı. Sıradaki hayvan hangisiydi?'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: keyColumns,
            crossAxisSpacing: 7,
            mainAxisSpacing: 8,
            childAspectRatio: keyColumns == 6 ? .82 : .95,
            children: animals.entries
                .map(
                  (a) => AnimalChoice(
                    animal: a.key,
                    label: a.value,
                    onTap: () {
                      if (g.answer(a.key, now)) {
                        if (!g.wrong) unawaited(app.feedback('flip'));
                        if (g.phase == GamePhase.failed) {
                          setState(() {});
                          unawaited(_fail());
                        } else {
                          _changed();
                        }
                      }
                    },
                  ),
                )
                .toList(),
          ),
        ] else ...[
          GameNote(
            g.fails == 0
                ? 'Hatasız geçersen 3 yıldız. Yanlış cevap veya süre −1 can.'
                : 'Yanlış cevap veya süre −1 can.',
          ),
          if (_hearts == 0 && !preview)
            IqumButton(
              'Canların yenileniyor',
              icon: Icons.hourglass_bottom_rounded,
              onPressed: () => showNoHearts(context, app),
            ),
        ],
      ],
    );
  }

  _Screen _path(PlayerProgress progress) {
    final g = path!, level = g.level, hearts = _hearts;
    const tileAspect = 1.3;
    final preview = g.phase == GamePhase.preview;
    final fit = GameLayout.grid(
      columns: level.columns,
      rows: level.rows,
      tileAspect: tileAspect,
      spacingX: 8,
      spacingY: 6,
      frame: const Size(30, 38 + 2 * 28),
    );
    // The route is shown on the table itself: its tiles lie face up in
    // green while the clock runs, then turn over and only memory is left.
    final board = Board(
      path: true,
      child: Column(
        children: [
          const _BoardLabel(Icons.flag_rounded, 'BİTİŞ'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: level.columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 6,
              childAspectRatio: tileAspect,
            ),
            itemCount: level.rows * level.columns,
            itemBuilder: (context, index) {
              final row = level.rows - 1 - index ~/ level.columns,
                  col = index % level.columns;
              return PathTile(
                key: ValueKey('path-$row-$col'),
                row: row,
                column: col,
                lit: preview && level.route[row] == col,
                stepped: row < g.row && level.route[row] == col,
                wrong:
                    g.phase == GamePhase.feedback &&
                    row == g.row &&
                    col == g.wrongColumn,
                active: g.phase == GamePhase.playing && row == g.row,
                onTap:
                    g.phase == GamePhase.playing && row == g.row && hearts > 0
                    ? () => _step(row, col)
                    : null,
              );
            },
          ),
          const SizedBox(height: 8),
          const _BoardLabel(Icons.directions_walk_rounded, 'BAŞLANGIÇ'),
        ],
      ),
    );
    return (
      fit: fit,
      header: [
        _Callout(
          state: g.phase == GamePhase.feedback
              ? _CallState.burned
              : _countdown != null
              ? _CallState.ready
              : preview
              ? _CallState.study
              : g.phase == GamePhase.playing
              ? _CallState.play
              : hearts == 0
              ? _CallState.resting
              : _CallState.ready,
          countdown: _countdown,
          study: 'Yolu ezberle!',
          studyHint: 'Yeşil karolar süre bitince kapanacak.',
          play: 'Sıra sende!',
          playHint: 'En alttan başla: adım ${g.row}/${level.rows}',
          burned: 'Yanlış karo! −1 can',
          burnedHint: 'Aynı yol yeniden gösterilecek.',
        ),
        ClockStrip(
          now: () => app.now,
          label: preview
              ? 'Ezber süresi'
              : '${level.columns}×${level.rows} tahta · '
                    '${level.previewMs ~/ 1000} sn ezber',
          deadline: preview ? g.deadline : null,
          totalMs: level.previewMs,
          trailing: preview ? null : 'Adım ${g.row}/${level.rows}',
        ),
      ],
      board: board,
      footer: [
        GameNote(
          g.phase == GamePhase.playing
              ? 'Her sıradan yalnızca bir karo güvenli. Yanlış karo −1 can.'
              : 'Hatasız geçersen 3 yıldız.',
        ),
        if (hearts == 0 && g.phase != GamePhase.playing)
          IqumButton(
            'Canların yenileniyor',
            icon: Icons.hourglass_bottom_rounded,
            onPressed: () => showNoHearts(context, app),
          ),
      ],
    );
  }

  Future<void> _step(int row, int col) async {
    final g = path!;
    final correct = g.step(row, col);
    if (correct == null) return;
    setState(() {});
    if (!correct) {
      g.deadline = now + 1100;
      await _writes;
      try {
        await app.spendHeart(pathSession: g.toJson(now), game: GameKind.path);
      } catch (_) {
        g.retry();
        if (mounted) {
          showError(
            context,
            'Can durumu kaydedilemedi. Tekrar deneyebilirsin.',
          );
        }
        return;
      }
      _runTimer();
      unawaited(app.feedback('error'));
      if (mounted && _hearts == 0) unawaited(showNoHearts(context, app));
    } else {
      unawaited(app.feedback('flip'));
    }
    if (g.phase == GamePhase.complete) {
      await _finish();
    } else {
      await _save();
    }
  }
}

typedef _Screen = ({
  ({double aspect, Size chrome}) fit,
  List<Widget> header,
  Widget board,
  List<Widget> footer,
});

enum _CallState { ready, study, play, burned, resting }

/// The call at the top of a memory level: "get ready 3-2-1", "memorise!",
/// "your turn!" or "burned". Each change pops in once; nothing loops.
class _Callout extends StatelessWidget {
  const _Callout({
    required this.state,
    required this.study,
    required this.studyHint,
    required this.play,
    required this.playHint,
    required this.burned,
    this.burnedHint,
    this.countdown,
  });
  final _CallState state;
  final int? countdown;
  final String study, studyHint, play, playHint, burned;
  final String? burnedHint;

  @override
  Widget build(BuildContext context) {
    final (
      Color face,
      Color lip,
      Color ink,
      Color soft,
      IconData icon,
    ) = switch (state) {
      _CallState.ready => (
        AppColors.petrol,
        AppColors.dark,
        AppColors.paper,
        AppColors.goldLight,
        Icons.timer_rounded,
      ),
      _CallState.study => (
        AppColors.gold,
        AppColors.amberDeep,
        AppColors.text,
        AppColors.dark,
        Icons.visibility_rounded,
      ),
      _CallState.play => (
        AppColors.sage,
        AppColors.sageDeep,
        AppColors.text,
        AppColors.dark,
        Icons.directions_run_rounded,
      ),
      _CallState.burned => (
        AppColors.red,
        AppColors.redDeep,
        AppColors.paper,
        AppColors.paper,
        Icons.heart_broken_rounded,
      ),
      _CallState.resting => (
        AppColors.shade,
        AppColors.line,
        AppColors.text,
        AppColors.muted,
        Icons.hourglass_bottom_rounded,
      ),
    };
    final (String title, String? hint) = switch (state) {
      _CallState.ready => ('Hazır ol!', studyHint),
      _CallState.study => (study, studyHint),
      _CallState.play => (play, playHint),
      _CallState.burned => (burned, burnedHint),
      _CallState.resting => (
        'Kısa bir mola',
        'Canın yenilenince level seni bekliyor.',
      ),
    };
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedSwitcher(
        duration: reduced ? Duration.zero : MotionTokens.feedback,
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween(begin: .9, end: 1.0).animate(animation),
          child: child,
        ),
        child: Piece(
          key: ValueKey('$state-$countdown'),
          color: face,
          lip: lip,
          border: lip,
          radius: 18,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Icon(icon, color: soft, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppColors.display(21).copyWith(color: ink),
                    ),
                    if (hint != null)
                      Text(
                        hint,
                        style: AppColors.caption.copyWith(
                          color: soft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (state == _CallState.ready && countdown != null)
                Text(
                  '$countdown',
                  style: AppColors.display(
                    36,
                  ).copyWith(color: AppColors.goldLight, height: 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardLabel extends StatelessWidget {
  const _BoardLabel(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 16, color: AppColors.goldLight),
      const SizedBox(width: 5),
      Text(text, style: AppColors.eyebrow.copyWith(color: AppColors.goldLight)),
    ],
  );
}

Future<void> showNoHearts(
  BuildContext context,
  AppController app,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HeartRow(0, size: 30),
          const SizedBox(height: 16),
          Text('Kısa bir mola.', style: AppColors.display(30)),
          const SizedBox(height: 8),
          const Text(
            'Levelin burada seni bekliyor.\nHer 30 dakikada bir can yenilenir. Düelloda can harcanmaz.',
            textAlign: TextAlign.center,
            style: AppColors.caption,
          ),
          const SizedBox(height: 18),
          Piece(
            color: AppColors.petrol,
            lip: AppColors.dark,
            border: AppColors.dark,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
            child: Column(
              children: [
                Text(
                  'SONRAKİ CAN',
                  style: AppColors.eyebrow.copyWith(color: AppColors.goldLight),
                ),
                StreamBuilder<int>(
                  stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                  builder: (context, _) => Text(
                    clockText(
                      (app.progress.life.at(app.now).nextAt ?? app.now) -
                          app.now,
                    ),
                    style: AppColors.display(
                      36,
                    ).copyWith(color: AppColors.paper),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          IqumButton(
            'Ana sayfaya dön',
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    ),
  ),
);

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.summary,
    this.detail,
    this.reward,
    this.eyebrow,
    this.stars,
    this.nextLabel = 'Tekrar oyna',
    required this.onNext,
  });
  final String title, subtitle, summary, nextLabel;
  final String? detail, eyebrow;

  /// Duel points (100 win, 50 draw, 0 loss) or null for a solo level.
  final int? reward;

  /// Stars earned on a solo level (1–3).
  final int? stars;
  final void Function(BuildContext) onNext;
  @override
  Widget build(BuildContext context) {
    final won = reward == null || reward == 100;
    return GameScaffold(
      label: 'Sonuç',
      child: ResultCelebration(
        enabled: won,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: won ? AppColors.goldLight : AppColors.shade,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  eyebrow ??
                      (reward == null
                          ? 'TAMAMLANDI'
                          : reward == 100
                          ? 'DÜELLOYU KAZANDIN'
                          : reward == 50
                          ? 'BERABERE'
                          : 'YENİ BİR TUR, YENİ ŞANS'),
                  textAlign: TextAlign.center,
                  style: AppColors.eyebrow.copyWith(color: AppColors.text),
                ),
              ),
              const SizedBox(height: 18),
              if (stars != null) ...[
                _EarnedStars(stars!),
                const SizedBox(height: 6),
              ],
              SizedBox(
                width: 170,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (won && stars == null) ...const [
                      Positioned(
                        left: 4,
                        top: 18,
                        child: Icon(
                          Icons.star_rounded,
                          size: 30,
                          color: AppColors.gold,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 4,
                        child: Icon(
                          Icons.star_rounded,
                          size: 40,
                          color: AppColors.gold,
                        ),
                      ),
                      Positioned(
                        right: 18,
                        bottom: 12,
                        child: Icon(
                          Icons.star_rounded,
                          size: 22,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ],
                    Container(
                      width: 128,
                      height: 128,
                      margin: const EdgeInsets.only(bottom: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: won ? AppColors.gold : AppColors.shade,
                        border: Border.all(color: AppColors.dark, width: 3),
                        boxShadow: AppColors.lip(
                          won ? AppColors.amberDeep : AppColors.muted,
                          6,
                        ),
                      ),
                      child: Container(
                        width: 98,
                        height: 98,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: won ? AppColors.goldLight : AppColors.paper,
                            width: 4,
                          ),
                        ),
                        child: const OwlMark(size: 88),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppColors.display(34),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppColors.caption,
              ),
              const SizedBox(height: 18),
              Piece(
                color: AppColors.petrol,
                lip: AppColors.dark,
                border: AppColors.dark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    Text(
                      summary,
                      style: AppColors.display(
                        40,
                      ).copyWith(color: AppColors.paper),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: AppColors.caption.copyWith(
                          color: AppColors.goldLight,
                        ),
                      ),
                  ],
                ),
              ),
              if (reward != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.lip(AppColors.gold, 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 18,
                        color: AppColors.amberDeep,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+$reward hesap puanı',
                        style: AppColors.body.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 26),
              IqumButton(
                nextLabel,
                accent: true,
                icon: Icons.arrow_forward_rounded,
                onPressed: () => onNext(context),
              ),
              const SizedBox(height: 12),
              IqumButton(
                'Ana sayfaya dön',
                secondary: true,
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The stars of a cleared level: the middle one larger, raised like a podium.
class _EarnedStars extends StatelessWidget {
  const _EarnedStars(this.count);
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count yıldız kazandın',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == 1 ? 14 : 0),
              child: ScoreStar(filled: i < count, size: i == 1 ? 62 : 46),
            ),
        ],
      ),
    ),
  );
}
