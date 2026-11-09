import 'premium_motion.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/app_controller.dart';
import '../domain/games.dart';
import '../domain/models.dart';
import 'components.dart';
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
  bool _loaded = false, _done = false, _paused = false;
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
          ? 'HAFIZA YOLU'
          : 'ANTRENMAN · ${widget.kind == GameKind.matching ? 'KART EŞLEŞTİRME' : 'SIRA HAFIZASI'}',
      actions: [
        IconButton(
          onPressed: _loaded ? _restart : null,
          tooltip: 'Yeniden başla',
          icon: const Icon(Icons.restart_alt, size: 22),
        ),
        const SizedBox(width: 9),
      ],
      child: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
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
    return [
      Text('Eşini hatırla.', style: AppColors.display()),
      const SizedBox(height: 9),
      const Text(
        'Her açtığın kart, bir sonraki hamlene ipucu.',
        style: AppColors.caption,
      ),
      const SizedBox(height: 23),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('ANTRENMAN', style: AppColors.eyebrow),
          ValueListenableBuilder<int>(
            valueListenable: _elapsed,
            builder: (_, seconds, _) => Text(
              clockText(seconds * 1000),
              style: const TextStyle(color: AppColors.green, fontSize: 13),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Board(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 9,
            mainAxisSpacing: 11,
            childAspectRatio: .84,
          ),
          itemCount: 16,
          itemBuilder: (context, i) => MemoryTile(
            key: ValueKey('match-$i'),
            index: i,
            animal: g.board[i],
            open: g.opened.contains(i) || g.matched.contains(i),
            matched: g.matched.contains(i),
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
      GameNote(
        g.phase == GamePhase.feedback
            ? (g.lastMatched
                  ? 'Bir çift daha hatırladın.'
                  : 'Bu ikisi farklı. Yerlerini aklında tut.')
            : 'Bir kart aç. Eşi aklında mı?',
      ),
      const Divider(),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ScoreNumber(
            g.matched.length ~/ 2,
            prefix: 'Bulunan çiftler  ',
            suffix: ' / 8',
            style: AppColors.caption,
          ),
          Text('Deneme  ${g.attempts}', style: AppColors.caption),
        ],
      ),
      if (g.phase == GamePhase.complete)
        IqumButton('Sonucu kaydet', onPressed: _finish),
    ];
  }

  List<Widget> _sequence() {
    final g = sequence!,
        answering = g.phase == GamePhase.playing,
        preview = g.phase == GamePhase.preview;
    return [
      Text('Sırası aklında mı?', style: AppColors.display(30)),
      const SizedBox(height: 9),
      const Text(
        'Hayvanları soldan sağa, satır satır hatırla.',
        style: AppColors.caption,
      ),
      const SizedBox(height: 22),
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
        trailing: g.deadline == null ? '${g.pattern.length} KART' : null,
      ),
      Board(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: g.pattern.length == 12 ? 4 : 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 11,
            childAspectRatio: .95,
          ),
          itemCount: g.pattern.length,
          itemBuilder: (context, i) => MemoryTile(
            key: ValueKey('seq-${g.round}-$i'),
            index: i,
            number: i + 1,
            animal: g.pattern[i],
            open: preview || i < g.answered,
            matched: i < g.answered,
            highlight: answering && i == g.answered,
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
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 7,
          mainAxisSpacing: 7,
          childAspectRatio: 1,
          children: animals.entries
              .map(
                (a) => Semantics(
                  button: true,
                  label: a.value,
                  child: InkWell(
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
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAE2D2),
                        border: Border.all(color: const Color(0xFFD8CBB4)),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Image.asset(
                              'assets/art/${a.key}.png',
                              cacheWidth: 144,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              a.value,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      if (g.phase == GamePhase.ready)
        IqumButton(
          'Kartları göster',
          icon: Icons.arrow_forward,
          onPressed: () {
            g.start(now);
            setState(() {});
            unawaited(_save());
          },
        ),
      if (g.phase == GamePhase.roundOver || g.phase == GamePhase.complete)
        IqumButton(
          g.round == 2 ? 'Sonucu gör' : 'Sonraki tur',
          icon: Icons.arrow_forward,
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
      const SizedBox(height: 22),
      const Divider(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Tur ${g.round + 1} / 3', style: AppColors.caption),
          ScoreNumber(g.total, prefix: 'Doğru ', style: AppColors.caption),
        ],
      ),
    ];
  }

  List<Widget> _path(PlayerProgress progress) {
    final g = path!, level = g.level, life = progress.life.at(app.now);
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Level ${level.number.toString().padLeft(2, '0')}',
            style: AppColors.display(),
          ),
          HeartRow(life.count),
        ],
      ),
      const SizedBox(height: 22),
      ClockStrip(
        label: g.phase == GamePhase.preview
            ? 'Yolu aklında tut'
            : g.phase == GamePhase.playing
            ? 'Bir sonraki sıraya bas'
            : 'Bir adım sonrasını düşün.',
        deadline: g.phase == GamePhase.preview ? g.deadline : null,
        totalMs: level.previewMs,
        trailing: g.phase == GamePhase.preview ? null : '${level.rows} ADIM',
      ),
      Board(
        path: true,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 20),
              child: Text(
                'B İ T İ Ş',
                style: TextStyle(
                  color: AppColors.dark,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
            ),
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
                    mainAxisSpacing: 9,
                    childAspectRatio: width / math.max(44, width / 1.55),
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
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text(
          'B A Ş L A N G I Ç',
          textAlign: TextAlign.center,
          style: AppColors.eyebrow,
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
          icon: Icons.arrow_forward,
          onPressed: life.count == 0
              ? () => showNoHearts(context, app)
              : () {
                  g.start(now);
                  setState(() {});
                  unawaited(_save());
                },
        ),
      const SizedBox(height: 20),
      const Divider(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Adım ${g.row} / ${level.rows}', style: AppColors.caption),
          const Text('Hata −1 can', style: AppColors.caption),
        ],
      ),
    ];
  }
}

Future<void> showNoHearts(
  BuildContext context,
  AppController app,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppColors.ivory,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HeartRow(0, size: 26),
          const SizedBox(height: 22),
          Text('Kısa bir mola.', style: AppColors.display(30)),
          const SizedBox(height: 12),
          const Text(
            'Yolun burada seni bekliyor.\nDiğer oyunlarla hafızanı çalıştırabilirsin.',
            textAlign: TextAlign.center,
            style: AppColors.caption,
          ),
          const SizedBox(height: 22),
          const Text('SONRAKİ CAN', style: AppColors.eyebrow),
          const SizedBox(height: 12),
          StreamBuilder<int>(
            stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
            builder: (context, _) => Text(
              clockText(
                (app.progress.life.at(app.now).nextAt ?? app.now) - app.now,
              ),
              style: AppColors.display(34),
            ),
          ),
          const SizedBox(height: 24),
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
  Widget build(BuildContext context) => GameScaffold(
    label: 'SONUÇ',
    child: ResultCelebration(
      enabled: reward == null || reward == 100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(25, 25, 25, 32),
        child: Column(
          children: [
            Text(
              reward == null
                  ? 'TAMAMLANDI'
                  : reward == 100
                  ? 'DÜELLOYU KAZANDIN'
                  : reward == 50
                  ? 'BERABERE'
                  : 'YENİ BİR TUR, YENİ ŞANS',
              style: AppColors.eyebrow,
            ),
            const SizedBox(height: 30),
            Container(
              width: 116,
              height: 116,
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF7E8BF), Color(0xFFDFC38A)],
                ),
                border: Border.all(color: AppColors.gold),
                boxShadow: const [
                  BoxShadow(color: AppColors.gold, offset: Offset(0, 5)),
                ],
              ),
              child: const Brand(size: 68, wordmark: false),
            ),
            const SizedBox(height: 35),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppColors.display(35),
            ),
            const SizedBox(height: 15),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppColors.caption,
            ),
            const SizedBox(height: 30),
            Text(
              summary,
              style: AppColors.display(37).copyWith(color: AppColors.green),
            ),
            if (detail != null) ...[
              const SizedBox(height: 10),
              Text(detail!, style: AppColors.caption),
            ],
            const SizedBox(height: 22),
            if (reward != null)
              Chip(
                label: Text('+$reward hesap puanı'),
                backgroundColor: const Color(0xFFE8DFC9),
                side: BorderSide.none,
              ),
            const SizedBox(height: 30),
            IqumButton(
              nextLabel,
              icon: Icons.arrow_forward,
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
