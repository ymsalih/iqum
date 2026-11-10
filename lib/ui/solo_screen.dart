import 'premium_motion.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/app_controller.dart';
import '../domain/games.dart';
import '../domain/models.dart';
import 'components.dart';
import 'responsive.dart';
import 'theme.dart';

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
    if (widget.kind == GameKind.path) {
      await app.refreshLife();
      if (!mounted) return;
      if (app.progress.life.count == 0) {
        unawaited(showNoHearts(context, app));
      }
    }
  }

  void _restore(Map<String, dynamic>? data) {
    switch (widget.kind) {
      case GameKind.matching:
        matching = data == null
            ? MatchingGame()
            : MatchingGame.restore(data, now);
        if (matching!.attempts > 0 ||
            matching!.elapsedMs > 0 ||
            matching!.opened.isNotEmpty) {
          matching!.lastTick = now;
        }
        break;
      case GameKind.sequence:
        sequence = data == null
            ? SequenceGame()
            : SequenceGame.restore(data, now);
        break;
      case GameKind.path:
        path = data == null || intValue(data['level']) != widget.level
            ? PathGame(widget.level)
            : PathGame.restore(data, now);
        break;
    }
  }

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
    if (changed) {
      if (phase == GamePhase.complete) {
        unawaited(_finish());
      } else {
        setState(() {});
        unawaited(_save());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_loaded || _done) return;
    if (state != AppLifecycleState.resumed && !_paused) {
      _paused = true;
      _timer?.cancel();
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
    }
  }

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    final id = matching?.id ?? sequence?.id ?? path!.id;
    final data = matching != null
        ? <String, dynamic>{
            'elapsedMs': matching!.elapsedMs,
            'attempts': matching!.attempts,
          }
        : sequence != null
        ? <String, dynamic>{
            'correct': sequence!.total,
            'elapsedMs': sequence!.elapsedMs,
          }
        : <String, dynamic>{'level': path!.level.number};
    try {
      await _writes;
      await app.complete(
        RunRecord(id: id, game: widget.kind, finishedAt: app.now, data: data),
      );
    } catch (_) {
      _done = false;
      if (mounted) {
        showError(context, 'Sonuç kaydedilemedi. Tekrar deneyebilirsin.');
        setState(() {});
      }
      return;
    }
    if (!mounted) return;
    final summary = matching != null
        ? '8 / 8 çift'
        : sequence != null
        ? '${sequence!.total} / 27 doğru'
        : 'Level ${widget.level}';
    unawaited(app.feedback('success'));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          title: widget.kind == GameKind.path
              ? 'Bir adım daha ileri.'
              : 'Aklında kaldı.',
          subtitle: widget.kind == GameKind.path
              ? 'Yol tamamlandı. Sıradaki level seni bekliyor.'
              : 'Her deneme hafızanda yeni bir iz bırakır.',
          summary: summary,
          detail: matching != null
              ? '${clockText(matching!.elapsedMs)} · ${matching!.attempts} deneme'
              : null,
          nextLabel: widget.kind == GameKind.path
              ? (widget.level == 30 ? 'Levellere dön' : 'Sonraki level')
              : 'Tekrar oyna',
          onNext: (context) {
            if (widget.kind == GameKind.path && widget.level == 30) {
              Navigator.pop(context);
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SoloScreen(
                  widget.kind,
                  level: widget.kind == GameKind.path
                      ? widget.level + 1
                      : widget.level,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _restart() async {
    final restart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Yeniden başla', style: AppColors.display(24)),
        content: const Text(
          'Bu denemenin ilerlemesi sıfırlanacak. Rekorların korunacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yeniden başla'),
          ),
        ],
      ),
    );
    if (restart != true || !mounted) return;
    _restore(null);
    setState(() {});
    await _save();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
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
    return GameScaffold(
      label: widget.kind == GameKind.path
          ? 'Hafıza Yolu'
          : '${widget.kind == GameKind.matching ? 'Kart Eşleştirme' : 'Sıra Hafızası'} · Antrenman',
      actions: [
        IconButton(
          onPressed: _loaded ? _restart : null,
          tooltip: 'Yeniden başla',
          icon: const Icon(Icons.restart_alt_rounded, size: 24),
        ),
        const SizedBox(width: 9),
      ],
      child: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                Responsive.gutter(context),
                4,
                Responsive.gutter(context),
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.kind == GameKind.matching
                    ? _matching()
                    : widget.kind == GameKind.sequence
                    ? _sequence()
                    : _path(progress),
              ),
            ),
    );
  }

  List<Widget> _matching() {
    final g = matching!;
    final wrongPair = g.phase == GamePhase.feedback && !g.lastMatched;
    return [
      Text('Eşini hatırla.', style: AppColors.display(28)),
      const Text(
        'Her açtığın kart, bir sonraki hamlene ipucu.',
        style: AppColors.caption,
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        children: [
          StatPill(
            label: 'ÇİFT',
            icon: Icons.style_rounded,
            value: ScoreNumber(g.matched.length ~/ 2, suffix: '/8'),
          ),
          StatPill(
            label: '',
            icon: Icons.touch_app_rounded,
            value: Text('${g.attempts}'),
          ),
          StatPill(
            label: '',
            icon: Icons.timer_rounded,
            dark: true,
            value: ValueListenableBuilder<int>(
              valueListenable: _elapsed,
              builder: (_, seconds, _) => Text(clockText(seconds * 1000)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      FitBoard(
        aspect: .8,
        reserved: 300,
        child: Board(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 9,
              mainAxisSpacing: 10,
              childAspectRatio: .8,
            ),
            itemCount: 16,
            itemBuilder: (context, i) => MemoryTile(
              key: ValueKey('match-$i'),
              index: i,
              animal: g.board[i],
              open: g.opened.contains(i) || g.matched.contains(i),
              matched: g.matched.contains(i),
              wrong: wrongPair && g.opened.contains(i),
              onTap: g.phase == GamePhase.playing && !g.matched.contains(i)
                  ? () {
                      if (g.select(i, now)) {
                        setState(() {});
                        unawaited(
                          app.feedback(
                            g.opened.length == 2
                                ? (g.lastMatched ? 'success' : 'error')
                                : 'flip',
                          ),
                        );
                        unawaited(_save());
                      }
                    }
                  : null,
            ),
          ),
        ),
      ),
      GameNote(
        g.phase == GamePhase.feedback
            ? (g.lastMatched
                  ? 'Bir çift daha hatırladın.'
                  : 'Bu ikisi farklı. Yerlerini aklında tut.')
            : 'Bir kart aç. Eşi aklında mı?',
        error: wrongPair,
      ),
      if (g.phase == GamePhase.complete)
        IqumButton('Sonucu kaydet', accent: true, onPressed: _finish),
    ];
  }

  List<Widget> _sequence() {
    final g = sequence!,
        answering = g.phase == GamePhase.playing,
        preview = g.phase == GamePhase.preview,
        missed = g.phase == GamePhase.roundOver && g.wrong;
    return [
      Text('Sırası aklında mı?', style: AppColors.display(28)),
      const Text(
        'Hayvanları soldan sağa, satır satır hatırla.',
        style: AppColors.caption,
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          StatPill(
            label: 'TUR',
            icon: Icons.layers_rounded,
            value: Text('${g.round + 1}/3'),
          ),
          StatPill(
            label: 'DOĞRU',
            icon: Icons.check_circle_rounded,
            value: ScoreNumber(g.total),
          ),
        ],
      ),
      const SizedBox(height: 14),
      ClockStrip(
        label: preview
            ? 'Ezberleme zamanı'
            : answering
            ? 'Sıradaki hayvanı seç'
            : 'Tur ${g.round + 1} / 3',
        deadline: g.deadline,
        totalMs:
            (preview
                ? SequenceGame.previewSeconds[g.round]
                : SequenceGame.answerSeconds[g.round]) *
            1000,
        trailing: g.deadline == null ? '${g.pattern.length} kart' : null,
      ),
      FitBoard(
        aspect: _sequenceAspect(g.pattern.length),
        // While answering, keep room for the 12 answer keys below.
        reserved: answering ? 600 : 360,
        child: Board(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: g.pattern.length == 12 ? 4 : 3,
              crossAxisSpacing: 9,
              mainAxisSpacing: 10,
              childAspectRatio: .9,
            ),
            itemCount: g.pattern.length,
            itemBuilder: (context, i) => MemoryTile(
              key: ValueKey('seq-${g.round}-$i'),
              index: i,
              number: i + 1,
              animal: g.pattern[i],
              // After a miss, the card that was asked for turns over in coral
              // so the player sees what it was. The round is already over.
              open: preview || i < g.answered || (missed && i == g.answered),
              matched: i < g.answered,
              wrong: missed && i == g.answered,
              highlight: answering && i == g.answered,
            ),
          ),
        ),
      ),
      GameNote(
        preview
            ? 'Hayvanları ve yerlerini aklında tut.'
            : answering
            ? 'Kartlar kapandı. Sıradaki hayvan hangisiydi?'
            : g.phase == GamePhase.roundOver
            ? (g.wrong
                  ? 'Bu hayvan farklıydı. Doğru cevapların korundu.'
                  : g.answered == g.pattern.length
                  ? 'Bütün sırayı hatırladın.'
                  : 'Süren doldu. Doğru cevapların korundu.')
            : 'Hazır olduğunda kartları incele.',
        error: g.wrong,
      ),
      if (answering)
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 9,
              childAspectRatio: .95,
              children: animals.entries
                  .map(
                    (a) => AnimalChoice(
                      animal: a.key,
                      label: a.value,
                      onTap: () {
                        final previous = g.total;
                        if (g.answer(a.key, now)) {
                          setState(() {});
                          unawaited(
                            app.feedback(g.total > previous ? 'flip' : 'error'),
                          );
                          unawaited(_save());
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      if (g.phase == GamePhase.ready)
        IqumButton(
          'Kartları göster',
          accent: true,
          icon: Icons.visibility_rounded,
          onPressed: () {
            g.start(now);
            setState(() {});
            unawaited(_save());
          },
        ),
      if (g.phase == GamePhase.roundOver || g.phase == GamePhase.complete)
        IqumButton(
          g.round == 2 ? 'Sonucu gör' : 'Sonraki tur',
          icon: Icons.arrow_forward_rounded,
          onPressed: () {
            g.next();
            if (g.phase == GamePhase.complete) {
              unawaited(_finish());
            } else {
              setState(() {});
              unawaited(_save());
            }
          },
        ),
    ];
  }

  List<Widget> _path(PlayerProgress progress) {
    final g = path!, level = g.level, life = progress.life.at(app.now);
    return [
      Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Level ${level.number.toString().padLeft(2, '0')}',
                style: AppColors.display(30),
              ),
            ),
          ),
          const SizedBox(width: 10),
          HeartRow(life.count, size: 22),
        ],
      ),
      const SizedBox(height: 10),
      ClockStrip(
        label: g.phase == GamePhase.preview
            ? 'Yolu aklında tut'
            : g.phase == GamePhase.playing
            ? 'Bir sonraki sıraya bas'
            : 'Bir adım sonrasını düşün.',
        deadline: g.phase == GamePhase.preview ? g.deadline : null,
        totalMs: level.previewMs,
        trailing: g.phase == GamePhase.preview
            ? null
            : 'Adım ${g.row}/${level.rows}',
      ),
      FitBoard(
        aspect: level.columns * 1.45 / level.rows,
        reserved: 340,
        child: Board(
          path: true,
          child: Column(
            children: [
              const _BoardLabel(Icons.flag_rounded, 'BİTİŞ'),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      (constraints.maxWidth - (level.columns - 1) * 8) /
                      level.columns;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: level.columns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 4,
                      childAspectRatio: width / math.max(48, width / 1.45),
                    ),
                    itemCount: level.rows * level.columns,
                    itemBuilder: (context, index) {
                      final row = level.rows - 1 - index ~/ level.columns,
                          col = index % level.columns;
                      return PathTile(
                        key: ValueKey('path-$row-$col'),
                        row: row,
                        column: col,
                        lit:
                            g.phase == GamePhase.preview &&
                            level.route[row] == col,
                        stepped: row < g.row && level.route[row] == col,
                        current: row == g.row - 1,
                        wrong:
                            g.phase == GamePhase.feedback &&
                            row == g.row &&
                            col == g.wrongColumn,
                        active: g.phase == GamePhase.playing && row == g.row,
                        onTap:
                            g.phase == GamePhase.playing &&
                                row == g.row &&
                                life.count > 0
                            ? () async {
                                final correct = g.step(row, col);
                                if (correct == null) return;
                                setState(() {});
                                if (!correct) {
                                  g.deadline = now + 900;
                                  await _writes;
                                  try {
                                    await app.spendHeart(
                                      pathSession: g.toJson(now),
                                    );
                                  } catch (_) {
                                    g.retry();
                                    if (context.mounted) {
                                      showError(
                                        context,
                                        'Can durumu kaydedilemedi. Tekrar deneyebilirsin.',
                                      );
                                    }
                                    return;
                                  }
                                  unawaited(app.feedback('error'));
                                  if (context.mounted &&
                                      app.progress.life.count == 0) {
                                    unawaited(showNoHearts(context, app));
                                  }
                                } else {
                                  unawaited(app.feedback('flip'));
                                }
                                if (g.phase == GamePhase.complete) {
                                  await _finish();
                                } else {
                                  await _save();
                                }
                              }
                            : null,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              const _BoardLabel(Icons.directions_walk_rounded, 'BAŞLANGIÇ'),
            ],
          ),
        ),
      ),
      GameNote(
        g.phase == GamePhase.preview
            ? 'Yeşil karoları sırayla aklında tut.'
            : g.phase == GamePhase.playing
            ? 'En alttan başla. Sadece sıradaki karoyu seç.'
            : g.phase == GamePhase.feedback
            ? 'Yanlış adım. −1 can. Aynı yol yeniden başlayacak.'
            : 'Önce yolu incele. Sonra aklında kalanla ilerle.',
        error: g.phase == GamePhase.feedback,
      ),
      if (g.phase == GamePhase.ready || g.phase == GamePhase.feedback)
        IqumButton(
          life.count == 0 ? 'Canların yenileniyor' : 'Yolu ezberle',
          accent: life.count > 0,
          icon: life.count == 0
              ? Icons.hourglass_bottom_rounded
              : Icons.visibility_rounded,
          onPressed: life.count == 0
              ? () => showNoHearts(context, app)
              : () {
                  g.start(now);
                  setState(() {});
                  unawaited(_save());
                },
        ),
      const SizedBox(height: 12),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.heart_broken_rounded, size: 16, color: AppColors.red),
          SizedBox(width: 6),
          Text('Hata −1 can', style: AppColors.caption),
        ],
      ),
    ];
  }
}

/// Board width / height for the sequence layouts (3×2, 3×3, 4×3 cards).
double _sequenceAspect(int count) {
  final columns = count == 12 ? 4 : 3, rows = (count / columns).ceil();
  return columns * .9 / rows;
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
            'Yolun burada seni bekliyor.\nDiğer oyunlarla hafızanı çalıştırabilirsin.',
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
            'Diğer oyunları keşfet',
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
    this.nextLabel = 'Tekrar oyna',
    required this.onNext,
  });
  final String title, subtitle, summary, nextLabel;
  final String? detail;
  final int? reward;
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
                  reward == null
                      ? 'TAMAMLANDI'
                      : reward == 100
                      ? 'DÜELLOYU KAZANDIN'
                      : reward == 50
                      ? 'BERABERE'
                      : 'YENİ BİR TUR, YENİ ŞANS',
                  style: AppColors.eyebrow.copyWith(color: AppColors.text),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: 170,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (won) ...const [
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
                        child: const Brand(size: 66, wordmark: false),
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
