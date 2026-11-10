import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'theme.dart';

/// Winding sand road climbing bottom-to-top with 30 level stops.
/// The road is one static CustomPainter behind a RepaintBoundary; only
/// scrolling moves pixels. The current stop is centred on first open.
class LevelRoad extends StatefulWidget {
  const LevelRoad({super.key, required this.level, required this.onSelect});
  final int level;
  final ValueChanged<int> onSelect;
  static const spacing = 104.0;
  static const extent = 30 * spacing + 32;
  static double position(num i) => .5 + .27 * math.sin(i * math.pi / 3);
  static double stopY(num i) => extent - 52 - i * spacing;
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
            52 +
            (widget.level - 1) * LevelRoad.spacing -
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
    if (oldWidget.level != widget.level) {
      centerActive();
    }
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
        color: const Color(0xFFE3EFE4),
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
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _RoadPainter(widget.level)),
                      ),
                    ),
                    for (var i = 0; i < 30; i++)
                      _Stop(
                        number: i + 1,
                        current: widget.level,
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
    required this.center,
    required this.onSelect,
  });
  final int number, current;
  final Offset center;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final isCurrent = number == current,
        done = number < current,
        locked = number > current;
    final size = isCurrent ? 70.0 : 58.0;
    final (Color face, Color ink, Color lip) = isCurrent
        ? (AppColors.gold, AppColors.text, AppColors.amberDeep)
        : done
        ? (AppColors.sage, AppColors.dark, AppColors.sageDeep)
        : (const Color(0xFFF4EEE2), const Color(0xFF8C9A93), AppColors.shade);
    return Positioned(
      top: center.dy - size / 2 - 3,
      left: center.dx - size / 2,
      width: size,
      height: size + 5,
      child: Semantics(
        sortKey: OrdinalSortKey(number.toDouble()),
        label:
            'Level $number${locked
                ? ', kilitli'
                : done
                ? ', tamamlandı'
                : ', sıradaki'}',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              bottom: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: AppColors.lip(lip, 5),
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
                        width: isCurrent ? 3 : 2.5,
                      ),
                    ),
                    backgroundColor: face,
                    foregroundColor: ink,
                    disabledBackgroundColor: face,
                    disabledForegroundColor: ink,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$number',
                        style: AppColors.display(
                          isCurrent ? 28 : 21,
                        ).copyWith(color: ink, height: 1),
                      ),
                      if (locked)
                        const Icon(Icons.lock_rounded, size: 12)
                      else if (done)
                        const Icon(Icons.check_rounded, size: 13),
                    ],
                  ),
                ),
              ),
            ),
            if (isCurrent)
              Positioned(
                top: -24,
                left: -12,
                right: -12,
                child: IgnorePointer(
                  child: Center(
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
              ),
          ],
        ),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter(this.level);
  final int level;
  Path ribbon(Size size, num end) {
    final path = Path();
    for (var i = 0; i <= end * 24; i++) {
      final t = i / 24;
      final x = size.width * LevelRoad.position(t), y = LevelRoad.stopY(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Quiet scenery: a few static dots of "grass"; no blur, no animation.
    final grass = Path();
    final rng = math.Random(7);
    for (var i = 0; i < 90; i++) {
      final x = rng.nextDouble() * size.width,
          y = rng.nextDouble() * size.height;
      grass.addOval(
        Rect.fromCircle(center: Offset(x, y), radius: 2 + rng.nextDouble() * 3),
      );
    }
    canvas.drawPath(grass, Paint()..color = const Color(0xFFCFE3D2));

    final road = ribbon(size, 29);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      road,
      stroke
        ..color = const Color(0xFFCDB993)
        ..strokeWidth = 34,
    );
    canvas.drawPath(
      road,
      stroke
        ..color = const Color(0xFFF1E5C9)
        ..strokeWidth = 26,
    );
    if (level > 1) {
      canvas.drawPath(
        ribbon(size, level - 1),
        stroke
          ..color = AppColors.sage
          ..strokeWidth = 26,
      );
    }
    // Dashed centre line along the whole road.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = const Color(0xBFFFFFFF);
    final dashes = Path();
    for (final metric in road.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 22) {
        dashes.addPath(metric.extractPath(d, d + 9), Offset.zero);
      }
    }
    canvas.drawPath(dashes, dash); // one draw call for the whole centre line
    // Chapter chips.
    final label = TextPainter(textDirection: TextDirection.ltr);
    final chip = Paint()..color = AppColors.petrol;
    for (final (n, text) in [
      (1, 'ODAK · 1–10'),
      (11, 'RİTİM · 11–20'),
      (21, 'USTALIK · 21–30'),
    ]) {
      label.text = TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: AppColors.bodyFamily,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: .8,
          color: AppColors.goldLight,
        ),
      );
      label.layout();
      final origin = Offset(12, LevelRoad.stopY(n - 1) - 82);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            origin.dx,
            origin.dy,
            label.width + 16,
            label.height + 8,
          ),
          const Radius.circular(9),
        ),
        chip,
      );
      label.paint(canvas, origin + const Offset(8, 4));
    }
  }

  @override
  bool shouldRepaint(_RoadPainter oldDelegate) => level != oldDelegate.level;
}
