import 'premium_motion.dart';
import 'level_road.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/app_controller.dart';
import '../data/backend.dart';
import '../domain/models.dart';
import 'components.dart';
import 'duel_screen.dart';
import 'solo_screen.dart';
import 'theme.dart';
import 'legal_screen.dart';
import 'responsive.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int selected = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(appProvider).resume());
    }
  }

  static const _tabs = [
    (Icons.grid_view_rounded, 'Oyna'),
    (Icons.style_rounded, 'Düello'),
    (Icons.face_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: selected,
        children: [
          TickerMode(
            enabled: selected == 0,
            child: HomeView(onProfile: () => setState(() => selected = 2)),
          ),
          TickerMode(enabled: selected == 1, child: const DuelHub()),
          TickerMode(enabled: selected == 2, child: const AccountView()),
        ],
      ),
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line, width: 2)),
      ),
      child: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (value) => setState(() => selected = value),
        height: 68,
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.goldLight,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppColors.bodyFamily,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: states.contains(WidgetState.selected)
                ? AppColors.text
                : AppColors.muted,
          ),
        ),
        destinations: [
          for (final (icon, label) in _tabs)
            NavigationDestination(
              icon: Icon(icon, size: 24, color: AppColors.muted),
              selectedIcon: Icon(icon, size: 24, color: AppColors.text),
              label: label,
            ),
        ],
      ),
    ),
  );
}

class HomeView extends ConsumerWidget {
  const HomeView({super.key, required this.onProfile});
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), p = app.progress;
    final lives = p.life.at(app.now).count;
    final gutter = Responsive.gutter(context);
    final games = [
      _GameRow(
        kind: GameKind.sequence,
        title: 'Sıra Hafızası',
        caption: 'Gördüğünü sırayla hatırla.',
        art: 'kus',
        record: p.sequenceBest == 0 ? null : '${p.sequenceBest}/27',
      ),
      _GameRow(
        kind: GameKind.matching,
        title: 'Kart Eşleştirme',
        caption: 'Bir kart aç. Eşi aklında mı?',
        art: 'kelebek',
        record: p.matchingBestMs == null ? null : clockText(p.matchingBestMs!),
      ),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Brand(size: 32),
                ),
              ),
              const Spacer(),
              StatPill(
                label: '',
                icon: Icons.favorite_rounded,
                value: Text('$lives/4'),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Profil',
                child: ExcludeSemantics(
                  child: SpringPress(
                    enabled: true,
                    sink: 2,
                    child: GestureDetector(
                      onTap: onProfile,
                      child: Container(
                        width: 42,
                        height: 42,
                        margin: const EdgeInsets.only(bottom: 3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.petrol,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.dark, width: 2),
                          boxShadow: AppColors.lip(AppColors.dark, 3),
                        ),
                        child: app.account == null
                            ? const Icon(
                                Icons.face_rounded,
                                color: AppColors.goldLight,
                                size: 22,
                              )
                            : Text(
                                app.account!.name.characters.first
                                    .toUpperCase(),
                                style: AppColors.display(
                                  19,
                                ).copyWith(color: AppColors.goldLight),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Biraz odak.\nBir adım ileri.', style: AppColors.display(32)),
          const SizedBox(height: 6),
          const Text(
            'Üç oyun. Her seferinde yeni bir hatırlama.',
            style: AppColors.caption,
          ),
          const SizedBox(height: 18),
          _PathHero(progress: p, lives: lives),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Oyunlar', style: AppColors.display(22))),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LevelsScreen()),
                ),
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Leveller'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Side by side when there is room for two comfortable cards.
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 540
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: games[0]),
                      const SizedBox(width: 12),
                      Expanded(child: games[1]),
                    ],
                  )
                : Column(
                    children: [games[0], const SizedBox(height: 12), games[1]],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The main call to action: the current Memory Path level on the felt table.
class _PathHero extends StatelessWidget {
  const _PathHero({required this.progress, required this.lives});
  final PlayerProgress progress;
  final int lives;
  @override
  Widget build(BuildContext context) => Piece(
    color: AppColors.petrol,
    lip: AppColors.dark,
    border: AppColors.dark,
    radius: 26,
    depth: 6,
    padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final art = (constraints.maxWidth * .3).clamp(72.0, 120.0);
        // The text column sets the height (large text never clips); the
        // vignette is positioned beside it, so no intrinsic layout pass.
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(right: art + 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'HAFIZA YOLU',
                    style: AppColors.eyebrow.copyWith(
                      color: AppColors.goldLight,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Level ${progress.level.toString().padLeft(2, '0')}',
                      style: AppColors.display(
                        38,
                      ).copyWith(color: AppColors.paper),
                    ),
                  ),
                  const SizedBox(height: 2),
                  HeartRow(lives, size: 16),
                  const SizedBox(height: 2),
                  Text(
                    '$lives / 4 canın hazır',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppColors.caption.copyWith(
                      color: AppColors.goldLight,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: IqumButton(
                      'Devam et',
                      accent: true,
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SoloScreen(GameKind.path, level: progress.level),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 4,
              bottom: 4,
              width: art,
              child: const RepaintBoundary(
                child: CustomPaint(painter: _MiniPathPainter()),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Static 3×4 stepping-stone vignette with a lit route (painted once).
class _MiniPathPainter extends CustomPainter {
  const _MiniPathPainter();
  static const _route = [1, 2, 1, 0];
  @override
  void paint(Canvas canvas, Size size) {
    const gap = 7.0, depth = 4.0;
    final w = (size.width - 2 * gap) / 3,
        h = (size.height - 3 * gap - depth) / 4;
    final face = Paint(), lip = Paint();
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 3; c++) {
        final lit = _route[3 - r] == c, top = r == 0 && lit;
        face.color = top
            ? AppColors.gold
            : lit
            ? AppColors.sage
            : const Color(0xFF2C7D6E);
        lip.color = top
            ? AppColors.amberDeep
            : lit
            ? AppColors.sageDeep
            : AppColors.dark;
        final rect = Rect.fromLTWH(c * (w + gap), r * (h + gap), w, h);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.shift(const Offset(0, depth)),
            const Radius.circular(9),
          ),
          lip,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(9)),
          face,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MiniPathPainter oldDelegate) => false;
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.kind,
    required this.title,
    required this.caption,
    required this.art,
    this.record,
  });
  final GameKind kind;
  final String title, caption, art;
  final String? record;
  @override
  Widget build(BuildContext context) => Piece(
    border: AppColors.line,
    radius: 22,
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    child: Column(
      children: [
        _header(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SmallKey(
                label: 'Antrenman',
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => SoloScreen(kind)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SmallKey(
                label: 'Düello',
                icon: Icons.style_rounded,
                secondary: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DuelPage(initialGame: kind),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _header() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: 78,
        height: 92,
        child: Stack(
          children: [
            Positioned(
              left: 22,
              top: 6,
              child: Transform.rotate(
                angle: .16,
                child: Container(
                  width: 52,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.petrol,
                    image: const DecorationImage(
                      image: ResizeImage(
                        AssetImage('assets/brand/card-back.png'),
                        width: 120,
                      ),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.dark, width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 2,
              top: 2,
              child: Transform.rotate(
                angle: -.12,
                child: Container(
                  width: 56,
                  height: 74,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.dark, width: 2),
                    boxShadow: AppColors.lip(AppColors.shade, 3),
                  ),
                  child: Image.asset(
                    'assets/art/$art.png',
                    cacheWidth: 120,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppColors.display(21))),
                if (record != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 13,
                          color: AppColors.amberDeep,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          record!,
                          style: AppColors.eyebrow.copyWith(
                            color: AppColors.text,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Text(caption, style: AppColors.caption),
          ],
        ),
      ),
    ],
  );
}

/// Compact version of [IqumButton] for rows of choices.
class _SmallKey extends StatelessWidget {
  const _SmallKey({
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool secondary;
  @override
  Widget build(BuildContext context) => SpringPress(
    enabled: true,
    sink: 2,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lip(
          secondary ? AppColors.shade : AppColors.dark,
          3,
        ),
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? AppColors.paper : AppColors.petrol,
          foregroundColor: secondary ? AppColors.text : AppColors.paper,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: secondary
              ? const BorderSide(color: AppColors.line, width: 2)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppColors.title(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    ),
  );
}

class LevelsScreen extends ConsumerWidget {
  const LevelsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), p = app.progress;
    return GameScaffold(
      label: 'Hafıza Yolu',
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.gutter(context),
          4,
          Responsive.gutter(context),
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HeartRow(p.life.at(app.now).count, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${p.completedLevels}/30 tamamlandı',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppColors.body.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 12,
              padding: const EdgeInsets.all(2),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: AppColors.shade,
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                widthFactor: (p.completedLevels / 30).clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LevelRoad(
                level: p.level,
                onSelect: (n) => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SoloScreen(GameKind.path, level: n),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            IqumButton(
              'Level ${p.level} ile devam et',
              accent: true,
              icon: Icons.play_arrow_rounded,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SoloScreen(GameKind.path, level: p.level),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> ensureAccount(BuildContext context, WidgetRef ref) async {
  if (ref.read(appProvider).account != null) return true;
  return await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GameScaffold(
            label: 'İlerlemeni koru',
            child: AccountView(onSignedIn: () => Navigator.pop(context, true)),
          ),
        ),
      ) ??
      false;
}

class AccountView extends ConsumerWidget {
  const AccountView({super.key, this.onSignedIn});
  final VoidCallback? onSignedIn;
  Future<void> login(BuildContext context, WidgetRef ref, bool apple) async {
    try {
      final version = await requestLegalAcceptance(context);
      if (version == null || !context.mounted) return;
      if (await ref.read(appProvider).signIn(apple, legalVersion: version) &&
          context.mounted) {
        onSignedIn?.call();
      }
    } catch (e) {
      if (context.mounted) showError(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), p = app.progress, account = app.account;
    final gutter = Responsive.gutter(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 112,
              height: 112,
              margin: const EdgeInsets.only(bottom: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.petrol,
                border: Border.all(color: AppColors.dark, width: 3),
                boxShadow: AppColors.lip(AppColors.dark, 6),
              ),
              child: account == null
                  ? const Brand(size: 70, wordmark: false)
                  : Text(
                      account.name.characters.first.toUpperCase(),
                      style: AppColors.display(
                        50,
                      ).copyWith(color: AppColors.goldLight),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: account == null ? AppColors.shade : AppColors.sage,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                account == null ? 'MİSAFİR OYUNCU' : 'HESABINA BAĞLI',
                style: AppColors.eyebrow.copyWith(color: AppColors.text),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            account == null
                ? 'İlerlemen,\nseninle kalsın.'
                : 'Hoş geldin, ${account.name}.',
            textAlign: TextAlign.center,
            style: AppColors.display(29),
          ),
          const SizedBox(height: 8),
          Text(
            account == null
                ? 'Levellerini ve rekorlarını hesabına taşı.\nDüellolarda hafızanı karşılaştır.'
                : 'Oyunların ve ilerlemen hesabında bir arada.',
            textAlign: TextAlign.center,
            style: AppColors.caption,
          ),
          const SizedBox(height: 20),
          if (account == null && app.deletion == null) ...[
            IqumButton(
              'Google ile devam et',
              secondary: true,
              busy: app.busy,
              onPressed: () => login(context, ref, false),
            ),
            if (Theme.of(context).platform == TargetPlatform.iOS) ...[
              const SizedBox(height: 10),
              IqumButton(
                'Apple ile devam et',
                secondary: true,
                onPressed: app.busy ? null : () => login(context, ref, true),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Misafir ilerlemen girişten sonra korunur.',
              textAlign: TextAlign.center,
              style: AppColors.caption,
            ),
          ] else if (account != null) ...[
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    p.points,
                    'Hesap puanı',
                    Icons.emoji_events_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(p.level, 'Ulaştığın level', Icons.map_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (app.syncError != null)
              Piece(
                color: const Color(0xFFFFF1D6),
                lip: AppColors.goldLight,
                child: Column(
                  children: [
                    Text(app.syncError!, style: AppColors.caption),
                    TextButton(
                      onPressed: app.sync,
                      child: const Text('Yeniden eşitle'),
                    ),
                  ],
                ),
              )
            else
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_done_rounded,
                    color: AppColors.green,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'İlerlemen hesabına kaydedildi.',
                    style: TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 22),
          _Section(
            title: 'Kişisel rekorlar',
            children: [
              _SettingText(
                'Sıra Hafızası',
                '${p.sequenceBest} / 27',
                Icons.format_list_numbered_rounded,
              ),
              _SettingText(
                'Kart Eşleştirme',
                p.matchingBestMs == null
                    ? 'Henüz oynanmadı'
                    : clockText(p.matchingBestMs!),
                Icons.style_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Oyun ayarları',
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                secondary: const Icon(Icons.volume_up_rounded),
                title: const Text('Oyun sesleri'),
                value: p.sound,
                activeTrackColor: AppColors.green,
                onChanged: (value) => app.settings(sound: value),
              ),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                secondary: const Icon(Icons.vibration_rounded),
                title: const Text('Hafif titreşim'),
                value: p.haptics,
                activeTrackColor: AppColors.green,
                onChanged: (value) => app.settings(haptics: value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.info_rounded),
                title: const Text('Bilgilendirme ve gizlilik'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalCenterScreen(),
                  ),
                ),
              ),
              if (account != null || app.deletion != null)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: AppColors.red,
                  ),
                  title: Text(
                    app.deletion != null
                        ? 'Hesap silme durumu'
                        : 'Hesabımı sil',
                    style: const TextStyle(color: AppColors.red),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const DeleteAccountScreen(),
                    ),
                  ),
                ),
            ],
          ),
          if (account != null && app.deletion == null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: app.busy
                  ? null
                  : () async {
                      try {
                        await app.signOut();
                      } catch (e) {
                        if (context.mounted) {
                          showError(context, friendlyError(e));
                        }
                      }
                    },
              child: const Text(
                'Hesaptan çık',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title!, style: AppColors.title(17)),
        ),
      Piece(
        border: AppColors.line,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(children: children),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.icon);
  final int value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Piece(
    border: AppColors.line,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    child: Column(
      children: [
        Icon(icon, color: AppColors.amberDeep, size: 22),
        ScoreNumber(value, style: AppColors.display(30)),
        Text(label, style: AppColors.caption, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _SettingText extends StatelessWidget {
  const _SettingText(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    child: Row(
      children: [
        Icon(icon, color: AppColors.petrol, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: AppColors.body)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppColors.title(16),
          ),
        ),
      ],
    ),
  );
}
