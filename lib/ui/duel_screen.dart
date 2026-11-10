import 'premium_motion.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/app_controller.dart';
import '../data/backend.dart';
import '../domain/models.dart';
import 'components.dart';
import 'responsive.dart';
import 'game_layout.dart';
import 'home_screen.dart';
import 'solo_screen.dart';
import 'theme.dart';

class DuelPage extends StatelessWidget {
  const DuelPage({super.key, this.initialGame = GameKind.matching});
  final GameKind initialGame;
  @override
  Widget build(BuildContext context) => GameScaffold(
    label: 'Düello',
    child: DuelHub(initialGame: initialGame),
  );
}

class DuelHub extends ConsumerStatefulWidget {
  const DuelHub({super.key, this.initialGame = GameKind.matching});
  final GameKind initialGame;
  @override
  ConsumerState<DuelHub> createState() => _DuelHubState();
}

class _DuelHubState extends ConsumerState<DuelHub> {
  late GameKind kind = widget.initialGame;
  final code = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> request(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (busy) return;
    if (!await ensureAccount(context, ref) || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await ref.read(appProvider).backend.call(name, {
        'gameType': kind.name,
        ...data,
      });
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => DuelMatchScreen(result['matchId'] as String),
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(appProvider).account;
    final gutter = Responsive.gutter(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hafızalar\nkarşılaşsın.', style: AppColors.display(32)),
          const SizedBox(height: 6),
          const Text(
            'Bir rakip bul ya da tanıdığın birini davet et.',
            style: AppColors.caption,
          ),
          const SizedBox(height: 18),
          _GamePicker(
            value: kind,
            onChanged: busy ? null : (value) => setState(() => kind = value),
          ),
          const SizedBox(height: 16),
          Piece(
            color: AppColors.petrol,
            lip: AppColors.dark,
            border: AppColors.dark,
            radius: 24,
            depth: 6,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Avatar(account?.name.characters.first ?? 'S', large: true),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.dark, width: 2),
                        boxShadow: AppColors.lip(AppColors.amberDeep, 3),
                      ),
                      child: Text('VS', style: AppColors.display(20)),
                    ),
                    const _Avatar('?', large: true, opponent: true),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  kind == GameKind.matching
                      ? 'Aynı tahtayı görür, sırayla kart açarsınız.\nEşini bulan puanı alır ve devam eder.'
                      : 'Aynı diziyi görür, aynı anda hatırlarsınız.\nÜç turun sonunda en iyi hafıza kazanır.',
                  textAlign: TextAlign.center,
                  style: AppColors.caption.copyWith(color: AppColors.goldLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          IqumButton(
            'Rastgele rakip bul',
            accent: true,
            busy: busy,
            icon: Icons.bolt_rounded,
            onPressed: () => request('findMatch'),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: Divider()),
              Flexible(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ya da arkadaşınla oyna',
                    textAlign: TextAlign.center,
                    style: AppColors.caption,
                  ),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          IqumButton(
            'Oda oluştur',
            secondary: true,
            icon: Icons.add_rounded,
            onPressed: busy ? null : () => request('createRoom'),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: code,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'ODA KODU',
                    counterText: '',
                    prefixIcon: Icon(Icons.key_rounded),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                  style: AppColors.display(
                    20,
                  ).copyWith(letterSpacing: 4, height: 1.2),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 92,
                child: IqumButton(
                  'Katıl',
                  onPressed: busy
                      ? null
                      : () {
                          if (code.text.length != 6) {
                            showError(
                              context,
                              'Lütfen altı karakterli oda kodunu gir.',
                            );
                            return;
                          }
                          unawaited(
                            request('joinRoom', {
                              'code': code.text.toUpperCase(),
                            }),
                          );
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            account == null
                ? 'Düello için hesabına giriş yapman gerekir.'
                : 'Galibiyet +100 · Beraberlik +50',
            textAlign: TextAlign.center,
            style: AppColors.caption,
          ),
          if (account != null)
            TextButton.icon(
              onPressed: busy ? null : () => request('resumeMatch'),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Devam eden maça dön'),
            ),
        ],
      ),
    );
  }
}

/// Two-option chunky toggle for the duel game type.
class _GamePicker extends StatelessWidget {
  const _GamePicker({required this.value, required this.onChanged});
  final GameKind value;
  final ValueChanged<GameKind>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.shade,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final (k, label, icon) in [
          (GameKind.matching, 'Kart Eşleştirme', Icons.style_rounded),
          (
            GameKind.sequence,
            'Sıra Hafızası',
            Icons.format_list_numbered_rounded,
          ),
        ])
          Expanded(
            child: Semantics(
              selected: value == k,
              button: true,
              child: GestureDetector(
                onTap: onChanged == null ? null : () => onChanged!(k),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  margin: EdgeInsets.only(bottom: value == k ? 3 : 0),
                  decoration: BoxDecoration(
                    color: value == k ? AppColors.paper : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: value == k
                        ? AppColors.lip(const Color(0xFFCDBFA6), 3)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 17,
                        color: value == k ? AppColors.green : AppColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: AppColors.body.copyWith(
                            fontSize: 13,
                            color: value == k
                                ? AppColors.text
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(
    this.letter, {
    this.large = false,
    this.opponent = false,
    this.active = false,
  });
  final String letter;
  final bool large, opponent, active;
  @override
  Widget build(BuildContext context) => Container(
    width: large ? 66 : 40,
    height: large ? 66 : 40,
    margin: const EdgeInsets.only(bottom: 3),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: opponent ? const Color(0xFFDDEFE3) : AppColors.goldLight,
      border: Border.all(
        color: active ? AppColors.gold : AppColors.dark,
        width: active ? 3.5 : 2.5,
      ),
      boxShadow: AppColors.lip(AppColors.dark, 3),
    ),
    child: Text(
      letter.toUpperCase(),
      style: AppColors.display(large ? 28 : 17),
    ),
  );
}

class DuelMatchScreen extends ConsumerStatefulWidget {
  const DuelMatchScreen(this.matchId, {super.key});
  final String matchId;
  @override
  ConsumerState<DuelMatchScreen> createState() => _DuelMatchScreenState();
}

class _DuelMatchScreenState extends ConsumerState<DuelMatchScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? match;
  StreamSubscription<Map<String, dynamic>>? subscription;
  Timer? pulse;

  /// When the second card of a pair has finished turning: until then the
  /// pair's result (sound, note, score) stays hidden. Display only.
  int _judgeAt = 0;
  Timer? _judge;
  bool get _judged => now >= _judgeAt;
  bool sending = false,
      finished = false,
      inFlight = false,
      paused = false,
      leaving = false;
  int lastAck = 0;
  String? connectionError;
  List<String>? lastPattern;
  AppController get app => ref.read(appProvider);
  int get now => app.now;
  int get me => (match?['members'] as List? ?? []).indexOf(app.account?.uid);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lastAck = now;
    subscription = app.backend
        .watchMatch(widget.matchId)
        .listen(
          _receive,
          onError: (Object e) {
            if (mounted) setState(() => connectionError = friendlyError(e));
          },
        );
    unawaited(_resume());
  }

  void _receive(Map<String, dynamic> data) {
    if (!mounted) return;
    final previous = match;
    setState(() => match = data);
    if (data['pattern'] is List) {
      lastPattern = (data['pattern'] as List).cast<String>();
    }
    if (previous != null &&
        previous['revision'] != data['revision'] &&
        (data['lastEvent'] == 'matched' || data['lastEvent'] == 'mismatch')) {
      final found = data['lastEvent'] == 'matched';
      _judgeAt = now + MotionTokens.flip.inMilliseconds;
      _judge?.cancel();
      _judge = Timer(MotionTokens.flip, () {
        if (!mounted) return;
        setState(() {});
        if (found) unawaited(app.feedback('success'));
      });
    }
    if (data['status'] == 'finished' && !finished) {
      finished = true;
      pulse?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult(data));
    }
  }

  Future<void> _resume() async {
    try {
      final result = await app.backend.call('resumeMatch', {
        'matchId': widget.matchId,
      });
      if (!mounted) return;
      if (result['match'] is Map) {
        _receive(Map<String, dynamic>.from(result['match'] as Map));
      }
      lastAck = now;
      setState(() => connectionError = null);
      pulse?.cancel();
      pulse = Timer.periodic(const Duration(seconds: 5), (_) => _heartbeat());
      await _heartbeat();
    } catch (e) {
      if (mounted) setState(() => connectionError = friendlyError(e));
    }
  }

  Future<void> _heartbeat() async {
    if (inFlight || paused || finished) return;
    inFlight = true;
    try {
      await app.backend
          .heartbeat(widget.matchId)
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        lastAck = now;
        if (connectionError != null) setState(() => connectionError = null);
      }
    } catch (_) {
      if (mounted) {
        setState(() => connectionError = 'Bağlantı yeniden kuruluyor.');
      }
    } finally {
      inFlight = false;
    }
  }

  Future<void> command(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (sending || me < 0) return;
    setState(() => sending = true);
    try {
      final result = await app.backend.call(name, {
        'matchId': widget.matchId,
        ...data,
      });
      if (mounted && result['match'] is Map) {
        _receive(Map<String, dynamic>.from(result['match'] as Map));
      }
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _leave() async {
    final active = match?['status'] == 'active';
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          active ? 'Maçtan ayrıl?' : 'Odadan ayrıl?',
          style: AppColors.display(24),
        ),
        content: Text(
          active
              ? 'Şimdi ayrılırsan bu maçı kaybedersin.'
              : 'Bekleme odasından çıkacaksın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
    if (leave == true) {
      setState(() => leaving = true);
      finished = true;
      pulse?.cancel();
      await command('leaveMatch');
      if (mounted) Navigator.pop(context);
    }
  }

  void _showResult(Map<String, dynamic> data) {
    if (!mounted || me < 0) return;
    unawaited(app.sync());
    final scores = (data['scores'] as List).map((v) => intValue(v)).toList();
    final rewards = (data['rewards'] as List? ?? [0, 0])
        .map((v) => intValue(v))
        .toList();
    final mine = me, opponent = 1 - me, points = rewards[mine];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          title: points == 100
              ? 'Bu tur senin.'
              : points == 50
              ? 'Hafızalar denk.'
              : 'Yeni bir tur, yeni şans.',
          subtitle: data['reason'] == 'disconnect'
              ? 'Karşılaşma bağlantı nedeniyle sona erdi.'
              : 'Bir sonraki karşılaşmada yeniden buluşun.',
          summary: '${scores[mine]} : ${scores[opponent]}',
          detail:
              'Sen · ${((data['players'] as List)[opponent] as Map)['name']}',
          reward: points,
          nextLabel: 'Yeni düello',
          onNext: (context) => Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => DuelPage(
                initialGame: data['gameType'] == 'matching'
                    ? GameKind.matching
                    : GameKind.sequence,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      paused = false;
      unawaited(_resume());
    } else {
      paused = true;
      pulse?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(subscription?.cancel());
    pulse?.cancel();
    _judge?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = match;
    final List<Widget> content = [];
    if (connectionError != null) {
      content.add(
        Piece(
          color: const Color(0xFFFFF1D6),
          lip: AppColors.goldLight,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: AppColors.amberDeep,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(connectionError!, style: AppColors.body),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClockStrip(
                label: 'Geri dönme süresi',
                deadline: lastAck + 15000,
                totalMs: 15000,
                now: () => now,
              ),
              TextButton(
                onPressed: _resume,
                child: const Text('Yeniden bağlan'),
              ),
            ],
          ),
        ),
      );
      content.add(const SizedBox(height: 14));
    }
    if (m != null) {
      if (m['status'] == 'waiting') {
        content.addAll(_waiting(m));
      } else if (m['status'] == 'cancelled') {
        content.addAll([
          Text('Bu karşılaşma sona erdi.', style: AppColors.display(29)),
          const GameNote(
            'Rakip bulunamadı veya bekleme süresi doldu. Puanın değişmedi.',
          ),
          IqumButton('Geri dön', onPressed: () => Navigator.pop(context)),
        ]);
      } else if (m['phase'] == 'countdown') {
        content.addAll([
          const SizedBox(height: 40),
          Text(
            'Hafızan hazır mı?',
            textAlign: TextAlign.center,
            style: AppColors.display(34),
          ),
          const GameNote('İki oyuncu da hazır. Oyun birlikte başlayacak.'),
          ClockStrip(
            label: 'Başlıyor',
            deadline: intValue(m['startAt']),
            totalMs: 3000,
            now: () => now,
          ),
        ]);
      }
    }
    final gutter = Responsive.gutter(context);
    final playing =
        m != null &&
        m['status'] != 'waiting' &&
        m['status'] != 'cancelled' &&
        m['phase'] != 'countdown';
    final game = !playing
        ? null
        : m['gameType'] == 'matching'
        ? _matching(m)
        : _sequence(m);
    return PopScope(
      canPop:
          leaving || (m?['status'] != 'active' && m?['status'] != 'waiting'),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: GameScaffold(
        label: m?['status'] == 'waiting'
            ? 'Düello lobisi'
            : m?['gameType'] == 'matching'
            ? 'Ortak tahta · Düello'
            : 'Eşzamanlı · Düello',
        child: m == null && connectionError == null
            ? const Center(child: CircularProgressIndicator())
            : game != null
            ? GameLayout(
                padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 16),
                aspect: game.fit.aspect,
                chrome: game.fit.chrome,
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...content, ...game.header],
                ),
                board: game.board,
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: game.footer,
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: content,
                ),
              ),
      ),
    );
  }

  List<Widget> _waiting(Map<String, dynamic> m) {
    final players = (m['players'] as List).cast<Map>();
    final ready = me >= 0 && players[me]['ready'] == true;
    return [
      Text(
        m['mode'] == 'private'
            ? 'Aynı masada buluşun.'
            : 'Bir hafıza daha aranıyor.',
        style: AppColors.display(30),
      ),
      const SizedBox(height: 4),
      Text(
        m['gameType'] == 'matching'
            ? 'Kart Eşleştirme · 2 oyuncu'
            : 'Sıra Hafızası · 2 oyuncu',
        style: AppColors.caption,
      ),
      const SizedBox(height: 18),
      if (m['mode'] == 'private')
        Piece(
          color: AppColors.petrol,
          lip: AppColors.dark,
          border: AppColors.dark,
          padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ODA KODU',
                      style: AppColors.eyebrow.copyWith(
                        color: AppColors.goldLight,
                      ),
                    ),
                    Text(
                      m['code'] as String,
                      style: AppColors.display(
                        32,
                      ).copyWith(letterSpacing: 6, color: AppColors.paper),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Oda kodunu kopyala',
                color: AppColors.goldLight,
                onPressed: () {
                  unawaited(
                    Clipboard.setData(ClipboardData(text: m['code'] as String)),
                  );
                  showError(context, 'Oda kodu kopyalandı.');
                },
                icon: const Icon(Icons.copy_rounded, size: 22),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      Piece(
        border: AppColors.line,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < 2; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    _Avatar(
                      i < players.length
                          ? (players[i]['name'] as String).characters.first
                          : '?',
                      opponent: i != me,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        i < players.length
                            ? (i == me ? 'Sen' : players[i]['name'] as String)
                            : 'Oyuncu bekleniyor',
                        style: AppColors.body,
                      ),
                    ),
                    if (i < players.length && players[i]['ready'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sage,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Hazır',
                          style: AppColors.eyebrow.copyWith(
                            color: AppColors.dark,
                            letterSpacing: .3,
                          ),
                        ),
                      )
                    else
                      const Text('…', style: AppColors.caption),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      ClockStrip(
        label: m['mode'] == 'private' ? 'Oda süresi' : 'Arama süresi',
        deadline: intValue(m['expiresAt']),
        totalMs: m['mode'] == 'private' ? 600000 : 30000,
        now: () => now,
      ),
      IqumButton(
        ready ? 'Rakibin bekleniyor' : 'Hazırım',
        accent: !ready,
        busy: sending,
        icon: ready ? null : Icons.check_rounded,
        onPressed: ready ? null : () => command('setReady'),
      ),
      const SizedBox(height: 12),
      IqumButton('Vazgeç', secondary: true, onPressed: _leave),
    ];
  }

  Widget _scores(Map<String, dynamic> m) {
    final players = (m['players'] as List).cast<Map>(),
        scores = (m['scores'] as List).map((s) => intValue(s)).toList(),
            // A found pair scores only once its second card has turned over.
            hidden =
            m['phase'] == 'feedback' && m['lastEvent'] == 'matched' && !_judged;
    int shown(int player) =>
        scores[player] - (hidden && m['turn'] == player ? 1 : 0);
    final turnIsMine = m['turn'] == me,
        sequential = m['gameType'] == 'matching';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Piece(
        color: AppColors.petrol,
        lip: AppColors.dark,
        border: AppColors.dark,
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _Avatar('S', active: sequential && turnIsMine),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sen',
                style: AppColors.body.copyWith(
                  color: sequential && turnIsMine
                      ? AppColors.goldLight
                      : AppColors.paper,
                ),
              ),
            ),
            DefaultTextStyle.merge(
              style: AppColors.display(30).copyWith(color: AppColors.paper),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScoreNumber(
                    shown(me < 0 ? 0 : me),
                    style: AppColors.display(
                      30,
                    ).copyWith(color: AppColors.paper),
                  ),
                  Text(
                    ' : ',
                    style: AppColors.display(
                      30,
                    ).copyWith(color: AppColors.goldLight),
                  ),
                  ScoreNumber(
                    shown(me < 0 ? 1 : 1 - me),
                    style: AppColors.display(
                      30,
                    ).copyWith(color: AppColors.paper),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                me < 0 ? 'Rakip' : players[1 - me]['name'] as String,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppColors.body.copyWith(
                  color: sequential && !turnIsMine
                      ? AppColors.goldLight
                      : AppColors.paper,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Avatar(
              me < 0
                  ? '?'
                  : (players[1 - me]['name'] as String).characters.first,
              opponent: true,
              active: sequential && !turnIsMine,
            ),
          ],
        ),
      ),
    );
  }

  _GameView _matching(Map<String, dynamic> m) {
    final revealed = Map<String, dynamic>.from(m['revealed'] as Map? ?? {}),
        matched = (m['matched'] as List? ?? []).map((e) => intValue(e)).toSet(),
        mine = m['turn'] == me,
        feedback = m['phase'] == 'feedback',
        judged = !feedback || _judged,
        mismatch = feedback && m['lastEvent'] == 'mismatch';
    return (
      fit: GameLayout.grid(columns: 4, rows: 4, tileAspect: .8),
      header: [
        Text('Eşini hatırla.', style: AppColors.display(28)),
        const Text(
          'Aynı tahta. İki hafıza. Sıra sende mi?',
          style: AppColors.caption,
        ),
        _scores(m),
        ClockStrip(
          label: feedback
              ? 'Kartları aklında tut'
              : mine
              ? 'Sıra sende'
              : 'Rakibin oynuyor',
          deadline: intValue(feedback ? m['feedbackUntil'] : m['turnDeadline']),
          totalMs: feedback ? 900 : 15000,
          now: () => now,
        ),
      ],
      board: Board(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 16,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 9,
            mainAxisSpacing: 10,
            childAspectRatio: .8,
          ),
          itemBuilder: (context, i) => MemoryTile(
            key: ValueKey('duel-$i'),
            index: i,
            animal: revealed['$i'] as String?,
            open: revealed.containsKey('$i'),
            matched: matched.contains(i),
            wrong:
                mismatch && revealed.containsKey('$i') && !matched.contains(i),
            onTap:
                mine &&
                    !feedback &&
                    !sending &&
                    !matched.contains(i) &&
                    !revealed.containsKey('$i')
                ? () => command('submitMove', {
                    'actionId': newId(),
                    'move': {'index': i},
                  })
                : null,
          ),
        ),
      ),
      footer: [
        GameNote(
          feedback && !judged
              ? 'İkinci kart açılıyor…'
              : feedback
              ? (m['lastEvent'] == 'matched'
                    ? 'Eşleşme +1 puan. Sıra aynı oyuncuda.'
                    : 'Eşleşmedi. Puan eksilmez; sıra değişir.')
              : m['lastEvent'] == 'timeout'
              ? '15 saniye doldu. Puan eksilmedi.'
              : 'Açılan kartları ikiniz de görüyorsunuz.',
        ),
        Center(
          child: StatPill(
            label: 'BULUNAN ÇİFT',
            icon: Icons.style_rounded,
            value: Text(
              '${matched.length ~/ 2 - (judged || m['lastEvent'] != 'matched' ? 0 : 1)}/8',
            ),
          ),
        ),
      ],
    );
  }

  _GameView _sequence(Map<String, dynamic> m) {
    final round = intValue(m['round']).clamp(0, 2),
        preview = m['phase'] == 'preview',
        answer = m['phase'] == 'answer',
        counts = [6, 9, 12],
        correct = (m['roundCorrect'] as List? ?? [0, 0])
            .map((n) => intValue(n))
            .toList(),
        done = (m['roundDone'] as List? ?? [false, false]),
        my = me < 0 ? 0 : me;
    final columns = counts[round] == 12 ? 4 : 3;
    return (
      fit: GameLayout.grid(
        columns: columns,
        rows: (counts[round] / columns).ceil(),
        tileAspect: .9,
      ),
      header: [
        Text('Sırası aklında mı?', style: AppColors.display(28)),
        Text(
          'Tur ${round + 1} / 3 · Aynı dizi, iki hafıza.',
          style: AppColors.caption,
        ),
        _scores(m),
        ClockStrip(
          label: preview
              ? 'Ezberleme zamanı'
              : answer
              ? (done[my] == true
                    ? 'Rakibin tamamlaması bekleniyor'
                    : 'Sıradaki hayvanı seç')
              : 'Bir sonraki tur hazırlanıyor',
          deadline: intValue(m['phaseDeadline']),
          totalMs: preview
              ? [6000, 8000, 10000][round]
              : answer
              ? [30000, 45000, 60000][round]
              : 2000,
          now: () => now,
        ),
      ],
      board: Board(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: counts[round],
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 10,
            childAspectRatio: .9,
          ),
          itemBuilder: (context, i) => MemoryTile(
            index: i,
            number: i + 1,
            animal: lastPattern != null && i < lastPattern!.length
                ? lastPattern![i]
                : null,
            open: preview || i < correct[my],
            matched: !preview && i < correct[my],
            highlight: answer && done[my] != true && i == correct[my],
          ),
        ),
      ),
      footer: [
        if (answer && done[my] != true) ...[
          const GameNote('Sıradaki kartın hayvanı hangisiydi?'),
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
                        onTap: sending
                            ? null
                            : () => command('submitMove', {
                                'actionId': newId(),
                                'move': {'animal': a.key},
                              }),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ] else
          GameNote(
            preview
                ? 'Hayvanları sırayla aklında tut.'
                : 'Bu turdaki doğru cevapların korundu.',
          ),
      ],
    );
  }
}

typedef _GameView = ({
  ({double aspect, Size chrome}) fit,
  List<Widget> header,
  Widget board,
  List<Widget> footer,
});
