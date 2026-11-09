import 'premium_motion.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/app_controller.dart';
import '../data/backend.dart';
import '../domain/models.dart';
import 'components.dart';
import 'home_screen.dart';
import 'solo_screen.dart';
import 'theme.dart';

class DuelPage extends StatelessWidget {
  const DuelPage({super.key, this.initialGame = GameKind.matching});
  final GameKind initialGame;
  @override
  Widget build(BuildContext context) => GameScaffold(
    label: 'İKİ KİŞİLİK',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('İKİ KİŞİLİK', style: AppColors.eyebrow),
          const SizedBox(height: 16),
          Text('Hafızalar\nkarşılaşsın.', style: AppColors.display(33)),
          const SizedBox(height: 12),
          const Text(
            'Bir rakip bul ya da tanıdığın birini davet et.',
            style: AppColors.caption,
          ),
          const SizedBox(height: 24),
          SegmentedButton<GameKind>(
            segments: const [
              ButtonSegment(
                value: GameKind.matching,
                label: Text('Kart Eşleştirme', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: GameKind.sequence,
                label: Text('Sıra Hafızası', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: {kind},
            showSelectedIcon: false,
            onSelectionChanged: busy
                ? null
                : (value) => setState(() => kind = value.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Avatar(account?.name.characters.first ?? 'S', large: true),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 26),
                child: Text(
                  'vs',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const _Avatar('?', large: true, opponent: true),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            kind == GameKind.matching
                ? 'Aynı tahtayı görür, sırayla kart açarsınız.\nEşini bulan puanı alır ve devam eder.'
                : 'Aynı diziyi görür, aynı anda hatırlarsınız.\nÜç turun sonunda en iyi hafıza kazanır.',
            textAlign: TextAlign.center,
            style: AppColors.caption,
          ),
          const SizedBox(height: 28),
          IqumButton(
            'Rastgele rakip bul',
            busy: busy,
            icon: Icons.arrow_forward,
            onPressed: () => request('findMatch'),
          ),
          const SizedBox(height: 23),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ya da arkadaşınla oyna',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 23),
          IqumButton(
            'Oda oluştur',
            secondary: true,
            icon: Icons.add,
            onPressed: busy ? null : () => request('createRoom'),
          ),
          const SizedBox(height: 12),
          Row(
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
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(letterSpacing: 3, fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  minimumSize: const Size(64, 50),
                ),
                child: const Text('Katıl'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            account == null
                ? 'Düello için hesabına giriş yapman gerekir.'
                : 'Galibiyet +100 · Beraberlik +50',
            textAlign: TextAlign.center,
            style: AppColors.caption,
          ),
          if (account != null)
            TextButton(
              onPressed: busy ? null : () => request('resumeMatch'),
              child: const Text(
                'Devam eden maça dön',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.letter, {this.large = false, this.opponent = false});
  final String letter;
  final bool large, opponent;
  @override
  Widget build(BuildContext context) => Container(
    width: large ? 64 : 36,
    height: large ? 64 : 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: opponent ? const Color(0xFFDFE5D7) : const Color(0xFFE8DDC5),
      border: Border.all(color: AppColors.gold),
      boxShadow: large
          ? const [BoxShadow(color: Color(0xFFBBAA87), offset: Offset(0, 4))]
          : null,
    ),
    child: Text(letter, style: AppColors.display(large ? 25 : 15)),
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
        data['lastEvent'] == 'matched') {
      unawaited(app.feedback('success'));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = match;
    final List<Widget> content = [];
    if (connectionError != null) {
      content.add(
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.goldLight.withValues(alpha: .35),
          child: Column(
            children: [
              Text(connectionError!, style: AppColors.caption),
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
      content.add(const SizedBox(height: 15));
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
          const SizedBox(height: 50),
          Text(
            'Hafızan hazır mı?',
            textAlign: TextAlign.center,
            style: AppColors.display(33),
          ),
          const GameNote('İki oyuncu da hazır. Oyun birlikte başlayacak.'),
          ClockStrip(
            label: 'Başlıyor',
            deadline: intValue(m['startAt']),
            totalMs: 3000,
            now: () => now,
          ),
        ]);
      } else if (m['gameType'] == 'matching') {
        content.addAll(_matching(m));
      } else {
        content.addAll(_sequence(m));
      }
    }
    return PopScope(
      canPop:
          leaving || (m?['status'] != 'active' && m?['status'] != 'waiting'),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: GameScaffold(
        label: m?['status'] == 'waiting'
            ? 'DÜELLO LOBİSİ'
            : m?['gameType'] == 'matching'
            ? 'ORTAK TAHTA · DÜELLO'
            : 'EŞZAMANLI · DÜELLO',
        child: m == null && connectionError == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
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
      const SizedBox(height: 12),
      Text(
        m['gameType'] == 'matching'
            ? 'Kart Eşleştirme · 2 oyuncu'
            : 'Sıra Hafızası · 2 oyuncu',
        style: AppColors.caption,
      ),
      const SizedBox(height: 25),
      if (m['mode'] == 'private')
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEAE3D5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                m['code'] as String,
                style: AppColors.display(27).copyWith(letterSpacing: 5),
              ),
              IconButton(
                tooltip: 'Oda kodunu kopyala',
                onPressed: () {
                  unawaited(
                    Clipboard.setData(ClipboardData(text: m['code'] as String)),
                  );
                  showError(context, 'Oda kodu kopyalandı.');
                },
                icon: const Icon(Icons.copy, size: 19),
              ),
            ],
          ),
        ),
      const SizedBox(height: 20),
      for (var i = 0; i < 2; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
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
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                i < players.length && players[i]['ready'] == true
                    ? 'Hazır'
                    : '…',
                style: const TextStyle(color: AppColors.green, fontSize: 12),
              ),
            ],
          ),
        ),
      const SizedBox(height: 20),
      ClockStrip(
        label: m['mode'] == 'private' ? 'Oda süresi' : 'Arama süresi',
        deadline: intValue(m['expiresAt']),
        totalMs: m['mode'] == 'private' ? 600000 : 30000,
        now: () => now,
      ),
      IqumButton(
        ready ? 'Rakibin bekleniyor' : 'Hazırım',
        busy: sending,
        onPressed: ready ? null : () => command('setReady'),
      ),
      const SizedBox(height: 12),
      IqumButton('Vazgeç', secondary: true, onPressed: _leave),
    ];
  }

  Widget _scores(Map<String, dynamic> m) {
    final players = (m['players'] as List).cast<Map>(),
        scores = (m['scores'] as List).map((s) => intValue(s)).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          const _Avatar('S'),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Sen',
              style: TextStyle(
                fontSize: 12,
                color: m['turn'] == me ? AppColors.green : AppColors.text,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScoreNumber(
                scores[me < 0 ? 0 : me],
                style: AppColors.display(25),
              ),
              Text(' : ', style: AppColors.display(25)),
              ScoreNumber(
                scores[me < 0 ? 1 : 1 - me],
                style: AppColors.display(25),
              ),
            ],
          ),
          const Spacer(),
          Flexible(
            child: Text(
              me < 0 ? 'Rakip' : players[1 - me]['name'] as String,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 9),
          _Avatar(
            me < 0 ? '?' : (players[1 - me]['name'] as String).characters.first,
            opponent: true,
          ),
        ],
      ),
    );
  }

  List<Widget> _matching(Map<String, dynamic> m) {
    final revealed = Map<String, dynamic>.from(m['revealed'] as Map? ?? {}),
        matched = (m['matched'] as List? ?? []).map((e) => intValue(e)).toSet(),
        mine = m['turn'] == me,
        feedback = m['phase'] == 'feedback';
    return [
      Text('Eşini hatırla.', style: AppColors.display()),
      const SizedBox(height: 8),
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
      Board(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 16,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 9,
            mainAxisSpacing: 11,
            childAspectRatio: .84,
          ),
          itemBuilder: (context, i) => MemoryTile(
            key: ValueKey('duel-$i'),
            index: i,
            animal: revealed['$i'] as String?,
            open: revealed.containsKey('$i'),
            matched: matched.contains(i),
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
      GameNote(
        feedback
            ? (m['lastEvent'] == 'matched'
                  ? 'Eşleşme +1 puan. Sıra aynı oyuncuda.'
                  : 'Eşleşmedi. Puan eksilmez; sıra değişir.')
            : m['lastEvent'] == 'timeout'
            ? '15 saniye doldu. Puan eksilmedi.'
            : 'Açılan kartları ikiniz de görüyorsunuz.',
      ),
      const Divider(),
      Text(
        'Bulunan çiftler ${matched.length ~/ 2} / 8',
        style: AppColors.caption,
      ),
    ];
  }

  List<Widget> _sequence(Map<String, dynamic> m) {
    final round = intValue(m['round']).clamp(0, 2),
        preview = m['phase'] == 'preview',
        answer = m['phase'] == 'answer',
        counts = [6, 9, 12],
        correct = (m['roundCorrect'] as List? ?? [0, 0])
            .map((n) => intValue(n))
            .toList(),
        done = (m['roundDone'] as List? ?? [false, false]),
        my = me < 0 ? 0 : me;
    return [
      Text('Sırası aklında mı?', style: AppColors.display(30)),
      const SizedBox(height: 8),
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
      Board(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: counts[round],
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: counts[round] == 12 ? 4 : 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 11,
            childAspectRatio: .95,
          ),
          itemBuilder: (context, i) => MemoryTile(
            index: i,
            number: i + 1,
            animal: lastPattern != null && i < lastPattern!.length
                ? lastPattern![i]
                : null,
            open: preview || i < correct[my],
            matched: !preview && i < correct[my],
          ),
        ),
      ),
      if (answer && done[my] != true) ...[
        const GameNote('Sıradaki kartın hayvanı hangisiydi?'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 7,
          mainAxisSpacing: 7,
          children: animals.entries
              .map(
                (a) => TextButton(
                  onPressed: sending
                      ? null
                      : () => command('submitMove', {
                          'actionId': newId(),
                          'move': {'animal': a.key},
                        }),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEAE2D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    padding: const EdgeInsets.all(4),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.asset(
                          'assets/art/${a.key}.png',
                          cacheWidth: 100,
                        ),
                      ),
                      FittedBox(
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
              )
              .toList(),
        ),
      ] else
        GameNote(
          preview
              ? 'Hayvanları sırayla aklında tut.'
              : 'Bu turdaki doğru cevapların korundu.',
        ),
    ];
  }
}
