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
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (value) => setState(() => selected = value),
      height: 70,
      backgroundColor: AppColors.ivory,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 10,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? AppColors.green
              : AppColors.muted,
        ),
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, size: 22, color: AppColors.muted),
          selectedIcon: Icon(
            Icons.home_outlined,
            size: 22,
            color: AppColors.green,
          ),
          label: 'Oyna',
        ),
        NavigationDestination(
          icon: Icon(Icons.style_outlined, size: 22, color: AppColors.muted),
          selectedIcon: Icon(
            Icons.style_outlined,
            size: 22,
            color: AppColors.green,
          ),
          label: 'Düello',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline, size: 22, color: AppColors.muted),
          selectedIcon: Icon(
            Icons.person_outline,
            size: 22,
            color: AppColors.green,
          ),
          label: 'Profil',
        ),
      ],
    ),
  );
}

class HomeView extends ConsumerWidget {
  const HomeView({super.key, required this.onProfile});
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), p = app.progress;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Brand(size: 34),
              IconButton(
                onPressed: onProfile,
                tooltip: 'Profil',
                icon: CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.paper,
                  child: Text(
                    app.account == null
                        ? '○'
                        : app.account!.name.characters.first.toUpperCase(),
                    style: AppColors.display(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text('KÜÇÜK BİR ODAK MOLASI', style: AppColors.eyebrow),
          const SizedBox(height: 13),
          Text('Biraz odak.\nBir adım ileri.', style: AppColors.display(34)),
          const SizedBox(height: 13),
          const Text(
            'Üç oyun. Her seferinde yeni bir hatırlama.',
            style: AppColors.caption,
          ),
          const SizedBox(height: 24),
          Container(
            height: 211,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF286A59), AppColors.dark],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(color: Color(0xFF123E38), offset: Offset(0, 7)),
                BoxShadow(
                  color: Color(0x20292722),
                  blurRadius: 15,
                  offset: Offset(0, 15),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  right: -7,
                  bottom: 30,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .001)
                      ..rotateX(.35)
                      ..rotateZ(-.28),
                    child: SizedBox(
                      width: 130,
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        mainAxisSpacing: 5,
                        crossAxisSpacing: 5,
                        childAspectRatio: 1.4,
                        children: List.generate(
                          15,
                          (i) => DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [1, 4, 6, 10, 13].contains(i)
                                    ? const [
                                        Color(0xFF9CCDA5),
                                        Color(0xFF367C5A),
                                      ]
                                    : const [
                                        Color(0xFF68927A),
                                        Color(0xFF335E49),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFF151C15),
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 21,
                  top: 23,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HAFIZA YOLU · LEVEL ${p.level.toString().padLeft(2, '0')}',
                        style: AppColors.eyebrow.copyWith(
                          color: AppColors.goldLight,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sıradaki adımını\nhatırla.',
                        style: AppColors.display(
                          24,
                        ).copyWith(color: AppColors.paper),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${p.life.at(app.now).count} / 4 canın hazır',
                        style: AppColors.caption.copyWith(
                          color: AppColors.goldLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 21,
                  bottom: 19,
                  child: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SoloScreen(GameKind.path, level: p.level),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.goldLight,
                      foregroundColor: AppColors.text,
                      minimumSize: const Size(148, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text('Devam et', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 22),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('HAFIZANA MEYDAN OKU', style: AppColors.eyebrow),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LevelsScreen()),
                ),
                child: const Text(
                  'Leveller',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
          _GameRow(
            kind: GameKind.sequence,
            title: 'Sıra Hafızası',
            caption: 'Gördüğünü sırayla hatırla.',
            art: 'kus',
          ),
          const Divider(),
          _GameRow(
            kind: GameKind.matching,
            title: 'Kart Eşleştirme',
            caption: 'Bir kart aç. Eşi aklında mı?',
            art: 'kelebek',
          ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.kind,
    required this.title,
    required this.caption,
    required this.art,
  });
  final GameKind kind;
  final String title, caption, art;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 65,
          height: 80,
          child: Stack(
            children: [
              Positioned(
                left: 15,
                top: 10,
                child: Transform.rotate(
                  angle: .17,
                  child: Container(
                    width: 47,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppColors.dark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.gold),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF8D744D),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                top: 2,
                child: Transform.rotate(
                  angle: -.15,
                  child: Container(
                    width: 49,
                    height: 65,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFE5ECE0)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.gold),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF89754E),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Image.asset('assets/art/$art.png', cacheWidth: 100),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppColors.display(20)),
              const SizedBox(height: 4),
              Text(caption, style: AppColors.caption.copyWith(fontSize: 11)),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SoloScreen(kind),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(44, 44),
                      ),
                      child: const Text(
                        'Antrenman →',
                        style: TextStyle(fontSize: 11, color: AppColors.green),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DuelPage(initialGame: kind),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                    ),
                    child: const Text(
                      'Düello',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class LevelsScreen extends ConsumerWidget {
  const LevelsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), p = app.progress;
    return GameScaffold(
      label: 'YOLCULUK',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Hafıza Yolu', style: AppColors.display(30)),
            const SizedBox(height: 6),
            const Text(
              'Aklında tut. Bir adım yüksel.',
              style: AppColors.caption,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                HeartRow(p.life.at(app.now).count),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Level ${p.level.toString().padLeft(2, '0')} · ${p.completedLevels}/30 tamamlandı',
                    textAlign: TextAlign.right,
                    style: AppColors.caption,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: p.completedLevels / 30,
              minHeight: 3,
              color: AppColors.gold,
              backgroundColor: AppColors.line,
            ),
            const SizedBox(height: 18),
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
              icon: Icons.north_east,
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
            label: 'İLERLEMENİ KORU',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 140,
              height: 140,
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE4EBDF),
              ),
              child: Transform.rotate(
                angle: -.12,
                child: const Brand(size: 110, wordmark: false),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            account == null ? 'MİSAFİR OYUNCU' : 'HESABINA BAĞLI',
            textAlign: TextAlign.center,
            style: AppColors.eyebrow,
          ),
          const SizedBox(height: 13),
          Text(
            account == null
                ? 'İlerlemen,\nseninle kalsın.'
                : 'Hoş geldin, ${account.name}.',
            textAlign: TextAlign.center,
            style: AppColors.display(31),
          ),
          const SizedBox(height: 14),
          Text(
            account == null
                ? 'Levellerini ve rekorlarını hesabına taşı.\nDüellolarda hafızanı karşılaştır.'
                : 'Oyunların ve ilerlemen hesabında bir arada.',
            textAlign: TextAlign.center,
            style: AppColors.caption,
          ),
          const SizedBox(height: 25),
          if (account == null && app.deletion == null) ...[
            IqumButton(
              'Google ile devam et',
              secondary: true,
              busy: app.busy,
              onPressed: () => login(context, ref, false),
            ),
            if (Theme.of(context).platform == TargetPlatform.iOS) ...[
              const SizedBox(height: 11),
              IqumButton(
                'Apple ile devam et',
                secondary: true,
                onPressed: app.busy ? null : () => login(context, ref, true),
              ),
            ],
            const SizedBox(height: 15),
            const Text(
              'Misafir ilerlemen girişten sonra korunur.',
              textAlign: TextAlign.center,
              style: AppColors.caption,
            ),
          ] else if (account != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat('${p.points}', 'Hesap puanı'),
                _Stat('${p.level}', 'Ulaştığın level'),
              ],
            ),
            const SizedBox(height: 20),
            if (app.syncError != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.goldLight.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(9),
                ),
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
              const Text(
                '✓ İlerlemen hesabına kaydedildi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.green, fontSize: 12),
              ),
          ],
          const SizedBox(height: 29),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Bilgilendirme ve gizlilik'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LegalCenterScreen(),
              ),
            ),
          ),
          if (account != null || app.deletion != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: Text(
                app.deletion != null ? 'Hesap silme durumu' : 'Hesabımı sil',
                style: const TextStyle(color: AppColors.red),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text('KİŞİSEL REKORLAR', style: AppColors.eyebrow),
          const SizedBox(height: 14),
          _SettingText('Sıra Hafızası', '${p.sequenceBest} / 27'),
          _SettingText(
            'Kart Eşleştirme',
            p.matchingBestMs == null
                ? 'Henüz oynanmadı'
                : clockText(p.matchingBestMs!),
          ),
          const SizedBox(height: 25),
          const Text('OYUN AYARLARI', style: AppColors.eyebrow),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Oyun sesleri', style: TextStyle(fontSize: 13)),
            value: p.sound,
            activeTrackColor: AppColors.green,
            onChanged: (value) => app.settings(sound: value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hafif titreşim', style: TextStyle(fontSize: 13)),
            value: p.haptics,
            activeTrackColor: AppColors.green,
            onChanged: (value) => app.settings(haptics: value),
          ),
          if (account != null && app.deletion == null)
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
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      int.tryParse(value) != null
          ? ScoreNumber(int.parse(value), style: AppColors.display(28))
          : Text(value, style: AppColors.display(28)),
      const SizedBox(height: 5),
      Text(label, style: AppColors.caption),
    ],
  );
}

class _SettingText extends StatelessWidget {
  const _SettingText(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppColors.caption,
          ),
        ),
      ],
    ),
  );
}
