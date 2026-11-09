import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'theme.dart';

/// Static ribbon, bottom-to-top progression; scrolling starts at the active stop.
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
        color: const Color(0xFFEBF2F0),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                      Positioned(
                        top: LevelRoad.stopY(i) - 31,
                        left: constraints.maxWidth * LevelRoad.position(i) - 31,
                        width: 62,
                        height: 62,
                        child: Semantics(
                          sortKey: OrdinalSortKey(i.toDouble()),
                          label:
                              'Level ${i + 1}${i + 1 > widget.level
                                  ? ', kilitli'
                                  : i + 1 < widget.level
                                  ? ', tamamlandı'
                                  : ', sıradaki'}',
                          child: FilledButton(
                            key: ValueKey('level-${i + 1}'),
                            onPressed: i + 1 <= widget.level
                                ? () => widget.onSelect(i + 1)
                                : null,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              elevation: i + 1 == widget.level ? 3 : 0,
                              shadowColor: const Color(0x300C4943),
                              shape: CircleBorder(
                                side: BorderSide(
                                  color: i + 1 == widget.level
                                      ? AppColors.gold
                                      : i + 1 < widget.level
                                      ? const Color(0xFF95C5B7)
                                      : const Color(0xFFCCD9D3),
                                  width: i + 1 == widget.level ? 2 : 1,
                                ),
                              ),
                              backgroundColor: i + 1 == widget.level
                                  ? AppColors.dark
                                  : const Color(0xFFDAEAE3),
                              foregroundColor: i + 1 == widget.level
                                  ? Colors.white
                                  : const Color(0xFF356F61),
                              disabledBackgroundColor: const Color(0xFFF1F5F2),
                              disabledForegroundColor: const Color(0xFF85968E),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${i + 1}'.padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: i + 1 == widget.level ? 22 : 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.5,
                                  ),
                                ),
                                if (i + 1 != widget.level)
                                  Icon(
                                    i + 1 > widget.level
                                        ? Icons.lock_outline_rounded
                                        : Icons.check,
                                    size: 11,
                                  ),
                              ],
                            ),
                          ),
                        ),
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

class _RoadPainter extends CustomPainter {
  const _RoadPainter(this.level);
  final int level;
  Path ribbon(Size size, int end) {
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
    final road = ribbon(size, 29);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      road,
      paint
        ..color = const Color(0xFFD4E0DA)
        ..strokeWidth = 13,
    );
    canvas.drawPath(
      road,
      paint
        ..color = const Color(0xFFF8FBF8)
        ..strokeWidth = 10,
    );
    if (level > 1) {
      canvas.drawPath(
        ribbon(size, level - 1),
        paint
          ..color = const Color(0xFF78ADA0)
          ..strokeWidth = 10,
      );
    }
    // Quiet milestone marks: no blur, particles, or repeating animation.
    final label = TextPainter(textDirection: TextDirection.ltr);
    for (final n in [1, 11, 21]) {
      label.text = TextSpan(
        text: n == 1
            ? '01 — ODAK'
            : n == 11
            ? '02 — RİTİM'
            : '03 — USTALIK',
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 10,
          letterSpacing: 1.8,
          color: AppColors.muted,
        ),
      );
      label.layout();
      label.paint(canvas, Offset(16, LevelRoad.stopY(n - 1) - 76));
    }
  }

  @override
  bool shouldRepaint(_RoadPainter oldDelegate) => level != oldDelegate.level;
}
