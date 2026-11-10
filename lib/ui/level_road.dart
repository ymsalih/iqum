import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'components.dart';
import 'theme.dart';

/// Winding road climbing bottom-to-top through three chapters (meadow,
/// forest, summit) with 30 level stops. Scenery and road are one static
/// CustomPainter behind a RepaintBoundary: scrolling only moves pixels and
/// nothing animates. The current stop is centred on first open.
class LevelRoad extends StatefulWidget {
  const LevelRoad({
    super.key,
    required this.level,
    required this.onSelect,
    this.stars,
  });

  /// Next level to play; every level up to it is open.
  final int level;
  final ValueChanged<int> onSelect;

  /// Best stars of a level (0–3); null shows no stars.
  final int Function(int level)? stars;

  static const count = 30;
  static const spacing = 112.0;
  static const top = 170.0, bottom = 150.0;

  /// Extra room between chapters for the gate across the road.
  static const chapterGap = 64.0;
  static const extent = top + (count - 1) * spacing + 2 * chapterGap + bottom;
  static double position(num i) => .5 + .26 * math.sin(i * math.pi / 3.2);
  static double _ramp(num x) => x.clamp(0, 1).toDouble();
  static double stopY(num i) =>
      extent -
      bottom -
      i * spacing -
      chapterGap * (_ramp(i - 9) + _ramp(i - 19));
  @override
  State<LevelRoad> createState() => _LevelRoadState();
}

class _LevelRoadState extends State<LevelRoad> {
  late final ScrollController scroll = ScrollController(
    initialScrollOffset: math.max(0, (widget.level - 3) * LevelRoad.spacing),
  );
  void centerActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        final offset =
            LevelRoad.extent -
            LevelRoad.stopY(widget.level - 1) -
            scroll.position.viewportDimension / 2;
        scroll.jumpTo(offset.clamp(0, scroll.position.maxScrollExtent));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    centerActive();
  }

  @override
  void didUpdateWidget(LevelRoad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) centerActive();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 480,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _Zone.meadow.ground,
        border: Border.all(color: AppColors.dark, width: 3),
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.lip(AppColors.dark, 5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            key: const ValueKey('level-road-scroll'),
            controller: scroll,
            reverse: true,
            child: LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: LevelRoad.extent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _RoadPainter(widget.level)),
                      ),
                    ),
                    for (var i = 0; i < LevelRoad.count; i++)
                      _Stop(
                        number: i + 1,
                        current: widget.level,
                        stars: widget.stars?.call(i + 1) ?? 0,
                        center: Offset(
                          constraints.maxWidth * LevelRoad.position(i),
                          LevelRoad.stopY(i),
                        ),
                        onSelect: widget.onSelect,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.number,
    required this.current,
    required this.stars,
    required this.center,
    required this.onSelect,
  });
  final int number, current, stars;
  final Offset center;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final isCurrent = number == current,
        done = number < current || stars > 0,
        locked = number > current;
    final size = isCurrent ? 74.0 : 60.0;
    final (Color face, Color ring, Color ink, Color lip) = isCurrent
        ? (
            AppColors.gold,
            AppColors.goldLight,
            AppColors.text,
            AppColors.amberDeep,
          )
        : done
        ? (AppColors.petrolMid, AppColors.sage, AppColors.paper, AppColors.dark)
        : (
            const Color(0xFFF4EEE2),
            AppColors.paper,
            const Color(0xFF8C9A93),
            AppColors.shade,
          );
    const box = 112.0;
    return Positioned(
      left: center.dx - box / 2,
      top: center.dy - box / 2,
      width: box,
      height: box,
      child: Semantics(
        sortKey: OrdinalSortKey(number.toDouble()),
        label:
            'Level $number${locked
                ? ', kilitli'
                : isCurrent
                ? ', sıradaki'
                : ', tamamlandı, $stars yıldız'}',
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: AppColors.lip(lip, isCurrent ? 6 : 5),
                ),
                child: FilledButton(
                  key: ValueKey('level-$number'),
                  onPressed: locked ? null : () => onSelect(number),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: locked ? AppColors.line : AppColors.dark,
                        width: isCurrent ? 3.5 : 3,
                      ),
                    ),
                    backgroundColor: face,
                    foregroundColor: ink,
                    disabledBackgroundColor: face,
                    disabledForegroundColor: ink,
                  ),
                  // Inner ring: the coin's milled rim.
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ring.withValues(alpha: locked ? .9 : .7),
                        width: 2,
                      ),
                    ),
                    child: locked
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$number',
                                style: AppColors.display(
                                  18,
                                ).copyWith(color: ink, height: 1),
                              ),
                              const Icon(Icons.lock_rounded, size: 12),
                            ],
                          )
                        : Text(
                            '$number',
                            style: AppColors.display(
                              isCurrent ? 30 : 22,
                            ).copyWith(color: ink, height: 1.05),
                          ),
                  ),
                ),
              ),
            ),
            if (done && !isCurrent)
              Positioned(
                bottom: 2,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(5, 1, 5, 2),
                    decoration: BoxDecoration(
                      color: AppColors.dark,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: StarRow(math.max(1, stars), size: 13, light: true),
                  ),
                ),
              ),
            if (isCurrent) ...[
              const Positioned(
                top: -30,
                child: IgnorePointer(child: OwlMark(size: 50)),
              ),
              Positioned(
                bottom: -2,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SIRADAKİ',
                      style: AppColors.eyebrow.copyWith(
                        color: AppColors.goldLight,
                        fontSize: 9,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Zone {
  meadow('1. BÖLÜM · ÇAYIR', Color(0xFFDCEBDC), Color(0xFFC6DEC8)),
  forest('2. BÖLÜM · ORMAN', Color(0xFFCBE0CF), Color(0xFFB3D1B9)),
  summit('3. BÖLÜM · ZİRVE', Color(0xFFEDE4D0), Color(0xFFDCCFB2));

  const _Zone(this.title, this.ground, this.speck);
  final String title;
  final Color ground, speck;
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter(this.level);
  final int level;

  static Path ribbon(Size size, num from, num to) {
    final path = Path();
    final steps = ((to - from) * 24).ceil();
    for (var i = 0; i <= steps; i++) {
      final t = from + (to - from) * i / steps;
      final x = size.width * LevelRoad.position(t), y = LevelRoad.stopY(t);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path;
  }

  /// Horizontal distance from the road at height [t] (in level units).
  static double roadX(Size size, num t) => size.width * LevelRoad.position(t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // Chapter grounds with a soft wavy border between them.
    for (var k = 0; k < 3; k++) {
      final zone = _Zone.values[k];
      final low = k == 0 ? size.height : LevelRoad.stopY(10 * k - .5);
      final high = k == 2 ? 0.0 : LevelRoad.stopY(10 * k + 9.5);
      final ground = Path()..moveTo(0, low);
      for (double x = 0; x <= w; x += 8) {
        ground.lineTo(x, (k == 0 ? low : low + 7 * math.sin(x / 26)));
      }
      ground.lineTo(w, high);
      for (double x = w; x >= 0; x -= 8) {
        ground.lineTo(x, (k == 2 ? high : high + 7 * math.sin(x / 26)));
      }
      ground.close();
      canvas.drawPath(ground, Paint()..color = zone.ground);
      // Grass/stone specks, batched into one path per chapter.
      final specks = Path(), rng = math.Random(11 + k);
      for (var i = 0; i < 70; i++) {
        final x = rng.nextDouble() * w,
            y = high + rng.nextDouble() * (low - high);
        if ((x - roadX(size, _t(y))).abs() < 34) continue;
        specks.addOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: 4 + rng.nextDouble() * 6,
            height: 3 + rng.nextDouble() * 3,
          ),
        );
      }
      canvas.drawPath(specks, Paint()..color = zone.speck);
    }

    _scenery(canvas, size);

    // The road: dark kerb, sand surface, travelled part in sage.
    final road = ribbon(size, -1.3, LevelRoad.count - 1 + .9);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      road.shift(const Offset(0, 5)),
      stroke
        ..color = const Color(0x2610302B)
        ..strokeWidth = 42,
    );
    canvas.drawPath(
      road,
      stroke
        ..color = AppColors.dark
        ..strokeWidth = 42,
    );
    canvas.drawPath(
      road,
      stroke
        ..color = const Color(0xFFF3E7CB)
        ..strokeWidth = 34,
    );
    if (level > 1) {
      canvas.drawPath(
        ribbon(size, -1.3, level - 1),
        stroke
          ..color = AppColors.sage
          ..strokeWidth = 34,
      );
    }
    final dashes = Path();
    for (final metric in road.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 22) {
        dashes.addPath(metric.extractPath(d, d + 9), Offset.zero);
      }
    }
    canvas.drawPath(
      dashes,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = const Color(0xCCFFFFFF),
    );

    // Chapter gates across the road and the finish flag at the top.
    for (var k = 0; k < 3; k++) {
      _gate(
        canvas,
        size,
        LevelRoad.stopY(k == 0 ? -.95 : 10 * k - .5),
        _Zone.values[k].title,
      );
    }
    _finish(canvas, size);
  }

  /// Converts a canvas height back to road units (for keeping clear).
  static double _t(double y) =>
      (LevelRoad.extent - LevelRoad.bottom - y) / LevelRoad.spacing;

  void _scenery(Canvas canvas, Size size) {
    final rng = math.Random(5);
    final lips = Path(), greens = Path(), darks = Path(), trunks = Path();
    final flowers = Path(), rocks = Path(), rockLips = Path(), snow = Path();
    final water = Path();
    for (var i = 0; i < LevelRoad.count * 2; i++) {
      final t = i / 2 - .25;
      final y = LevelRoad.stopY(t) + (rng.nextDouble() - .5) * 30;
      final road = roadX(size, t);
      // Opposite side of the road, inside the frame.
      final left = road > size.width / 2;
      final x = left
          ? 22 + rng.nextDouble() * math.max(10, road - 90)
          : road +
                68 +
                rng.nextDouble() * math.max(10, size.width - road - 100);
      final chapter = (t / 10).floor().clamp(0, 2);
      final s = .8 + rng.nextDouble() * .5;
      final kind = rng.nextInt(3);
      if (chapter == 0) {
        if (kind == 0 && i % 9 == 4) {
          water.addOval(
            Rect.fromCenter(
              center: Offset(x, y),
              width: 70 * s,
              height: 30 * s,
            ),
          );
        } else if (kind == 0) {
          for (var f = 0; f < 5; f++) {
            flowers.addOval(
              Rect.fromCircle(
                center: Offset(
                  x + (f - 2) * 7 * s,
                  y + (f.isEven ? 0 : -6) * s,
                ),
                radius: 3.2 * s,
              ),
            );
          }
        } else {
          // Round tree on a lip.
          lips.addOval(
            Rect.fromCircle(center: Offset(x, y - 10 * s + 4), radius: 15 * s),
          );
          trunks.addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(x, y + 2 * s),
                width: 6 * s,
                height: 14 * s,
              ),
              const Radius.circular(2),
            ),
          );
          greens.addOval(
            Rect.fromCircle(center: Offset(x, y - 10 * s), radius: 15 * s),
          );
        }
      } else if (chapter == 1) {
        // Pines: two stacked triangles on a trunk.
        trunks.addRect(
          Rect.fromCenter(
            center: Offset(x, y + 6 * s),
            width: 6 * s,
            height: 12 * s,
          ),
        );
        for (final (dy, half) in [(0.0, 15.0), (-12.0, 11.0)]) {
          final tri = Path()
            ..moveTo(x - half * s, y + dy * s)
            ..lineTo(x + half * s, y + dy * s)
            ..lineTo(x, y + (dy - 20) * s)
            ..close();
          lips.addPath(tri, const Offset(0, 4));
          darks.addPath(tri, Offset.zero);
        }
      } else {
        // Rocks and small peaks with snow caps.
        if (kind == 0) {
          final peak = Path()
            ..moveTo(x - 26 * s, y + 8 * s)
            ..lineTo(x, y - 26 * s)
            ..lineTo(x + 26 * s, y + 8 * s)
            ..close();
          rockLips.addPath(peak, const Offset(0, 4));
          rocks.addPath(peak, Offset.zero);
          snow.addPath(
            Path()
              ..moveTo(x - 9 * s, y - 14 * s)
              ..lineTo(x, y - 26 * s)
              ..lineTo(x + 9 * s, y - 14 * s)
              ..lineTo(x + 3 * s, y - 11 * s)
              ..lineTo(x - 3 * s, y - 15 * s)
              ..close(),
            Offset.zero,
          );
        } else {
          final rock = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, y),
              width: 26 * s,
              height: 16 * s,
            ),
            Radius.circular(7 * s),
          );
          rockLips.addRRect(rock.shift(const Offset(0, 3)));
          rocks.addRRect(rock);
        }
      }
    }
    canvas.drawPath(water, Paint()..color = const Color(0xFF9FCFD0));
    canvas.drawPath(lips, Paint()..color = const Color(0xFF2F6B4E));
    canvas.drawPath(trunks, Paint()..color = const Color(0xFF8A5A33));
    canvas.drawPath(greens, Paint()..color = const Color(0xFF5DAA72));
    canvas.drawPath(darks, Paint()..color = const Color(0xFF2E7D5B));
    canvas.drawPath(flowers, Paint()..color = AppColors.gold);
    canvas.drawPath(rockLips, Paint()..color = const Color(0xFF8F8573));
    canvas.drawPath(rocks, Paint()..color = const Color(0xFFB8AE98));
    canvas.drawPath(snow, Paint()..color = AppColors.paper);
  }

  void _gate(Canvas canvas, Size size, double y, String title) {
    final label = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: title,
        style: const TextStyle(
          fontFamily: AppColors.bodyFamily,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          letterSpacing: .9,
          color: AppColors.goldLight,
        ),
      ),
    )..layout();
    final cx = size.width / 2, bw = label.width + 34, bh = 26.0;
    final posts = Paint()..color = AppColors.dark;
    for (final px in [cx - bw / 2 + 8, cx + bw / 2 - 8]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px - 3, y - bh / 2, 6, bh + 26),
          const Radius.circular(3),
        ),
        posts,
      );
    }
    // Ribbon banner with notched tails.
    Path banner(double dy) => Path()
      ..moveTo(cx - bw / 2 - 12, y - bh / 2 + dy)
      ..lineTo(cx + bw / 2 + 12, y - bh / 2 + dy)
      ..lineTo(cx + bw / 2 + 4, y + dy)
      ..lineTo(cx + bw / 2 + 12, y + bh / 2 + dy)
      ..lineTo(cx - bw / 2 - 12, y + bh / 2 + dy)
      ..lineTo(cx - bw / 2 - 4, y + dy)
      ..close();
    canvas.drawPath(banner(4), Paint()..color = AppColors.dark);
    canvas.drawPath(banner(0), Paint()..color = AppColors.petrol);
    canvas.drawPath(
      banner(0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.dark,
    );
    label.paint(canvas, Offset(cx - label.width / 2, y - label.height / 2));
  }

  void _finish(Canvas canvas, Size size) {
    final t = LevelRoad.count - 1 + .9;
    final x = roadX(size, t), y = LevelRoad.stopY(t);
    // A small hill, a pole and an amber pennant.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y + 6), width: 76, height: 26),
      Paint()..color = const Color(0xFFCDBF9F),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2.5, y - 70, 5, 74),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.dark,
    );
    final flag = Path()
      ..moveTo(x + 2, y - 70)
      ..lineTo(x + 46, y - 58)
      ..lineTo(x + 2, y - 44)
      ..close();
    canvas.drawPath(
      flag.shift(const Offset(0, 3)),
      Paint()..color = AppColors.amberDeep,
    );
    canvas.drawPath(flag, Paint()..color = AppColors.gold);
    canvas.drawCircle(
      Offset(x, y - 72),
      5,
      Paint()..color = AppColors.goldLight,
    );
  }

  @override
  bool shouldRepaint(_RoadPainter oldDelegate) => level != oldDelegate.level;
}
