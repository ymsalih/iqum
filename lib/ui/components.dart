import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'premium_motion.dart';
import 'animal_art.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'theme.dart';

String clockText(int milliseconds) {
  final seconds = math.max(0, (milliseconds / 1000).ceil());
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

void showError(BuildContext context, String message) {
  if (message.isNotEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 32, this.wordmark = true});
  final double size;
  final bool wordmark;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/brand/mark.png',
        width: size,
        height: size,
        excludeFromSemantics: true,
      ),
      if (wordmark) ...[
        const SizedBox(width: 9),
        Text(
          'IQUM',
          style: AppColors.display(size * .64).copyWith(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
      ],
    ],
  );
}

class HeartRow extends StatelessWidget {
  const HeartRow(this.count, {super.key, this.size = 18});
  final int count;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count can',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Icon(
              Icons.favorite,
              size: size,
              color: i < count ? AppColors.red : const Color(0xFFCAC1B5),
            ),
          ),
        ),
      ),
    ),
  );
}

class IqumButton extends StatelessWidget {
  const IqumButton(
    this.label, {
    super.key,
    this.onPressed,
    this.secondary = false,
    this.busy = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, busy;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SpringPress(
    enabled: !busy && onPressed != null,
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? AppColors.paper : AppColors.green,
          foregroundColor: secondary ? AppColors.text : AppColors.paper,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size(44, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: secondary ? const BorderSide(color: AppColors.line) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MotionTokens.radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
            if (icon != null) ...[
              const SizedBox(width: 14),
              Icon(icon, size: 18),
            ],
          ],
        ),
      ),
    ),
  );
}

class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.label,
    required this.child,
    this.actions,
  });
  final String label;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: Text(label, style: AppColors.eyebrow.copyWith(fontSize: 9)),
      actions:
          actions ??
          [
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Brand(size: 30, wordmark: false),
            ),
          ],
    ),
    body: SafeArea(top: false, child: child),
  );
}

class Board extends StatelessWidget {
  const Board({super.key, required this.child, this.path = false});
  final Widget child;
  final bool path;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: path
              ? const [Color(0xFFE2EEE6), Color(0xFFC9DED2)]
              : const [Color(0xFF276257), Color(0xFF143F39)],
        ),
        border: Border.all(color: const Color(0xFF7B9A84)),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Color(0xFF22241D), offset: Offset(0, 7)),
          BoxShadow(
            color: Color(0x20292722),
            blurRadius: 18,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0007)
          ..rotateX(path ? 0.12 : 0.04),
        child: child,
      ),
    ),
  );
}

class MemoryTile extends StatefulWidget {
  const MemoryTile({
    super.key,
    required this.index,
    this.animal,
    this.open = false,
    this.matched = false,
    this.highlight = false,
    this.onTap,
    this.number,
  });
  final int index;
  final String? animal;
  final bool open, matched, highlight;
  final VoidCallback? onTap;
  final int? number;
  @override
  State<MemoryTile> createState() => _MemoryTileState();
}

class _MemoryTileState extends State<MemoryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: MotionTokens.flip,
    value: 0,
  );
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _animation.value = widget.open ? 1 : 0;
      } else if (widget.open) {
        _animation.forward();
      }
    }
  }

  @override
  void didUpdateWidget(MemoryTile old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _animation.value = widget.open ? 1 : 0;
      } else {
        _animation.animateTo(widget.open ? 1 : 0, curve: Curves.easeInOutCubic);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: widget.onTap != null,
    label: widget.open
        ? '${animals[widget.animal] ?? 'Kart'}${widget.matched ? ', eşleşti' : ''}'
        : 'Kapalı kart ${widget.index + 1}',
    child: ExcludeSemantics(
      child: Bounceable(
        scaleFactor: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
        duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 180),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final front = _animation.value > .5,
                angle = math.pi * (_animation.value - (front ? 1 : 0));
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0025)
                ..translateByDouble(
                  0,
                  -6 * math.sin(math.pi * _animation.value),
                  0,
                  1,
                )
                ..rotateZ(.025 * math.sin(math.pi * _animation.value))
                ..rotateY(angle),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: front
                        ? (widget.matched
                              ? const [Color(0xFFE4F4E7), Color(0xFFACD8BA)]
                              : const [Color(0xFFFFFFFF), Color(0xFFE5ECE0)])
                        : const [Color(0xFF347968), Color(0xFF184E42)],
                  ),
                  border: Border.all(
                    color: widget.highlight
                        ? AppColors.goldLight
                        : front
                        ? const Color(0xFFD2DEC9)
                        : const Color(0xFF87B39B),
                    width: widget.highlight ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: front
                          ? const Color(0xFFA1B69B)
                          : const Color(0xFF10372E),
                      offset: const Offset(0, 4),
                    ),
                    const BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 5,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      left: 4,
                      right: 4,
                      top: 4,
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: front
                                ? const Color(0x559B8052)
                                : const Color(0x44A28C5D),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: front ? 0.9 : 0.4,
                        heightFactor: front ? 0.84 : 0.45,
                        child: front && widget.animal != null
                            ? AnimalArt(widget.animal!)
                            : Image.asset(
                                'assets/brand/mark-light.png',
                                opacity: const AlwaysStoppedAnimation(.65),
                              ),
                      ),
                    ),
                    if (widget.number != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 3,
                        child: Text(
                          '${widget.number}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: front
                                ? const Color(0xFF736145)
                                : AppColors.goldLight,
                          ),
                        ),
                      ),
                    if (widget.matched)
                      const Positioned(
                        right: 4,
                        bottom: 3,
                        child: Icon(
                          Icons.check,
                          size: 11,
                          color: AppColors.green,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class PathTile extends StatelessWidget {
  const PathTile({
    super.key,
    required this.row,
    required this.column,
    this.lit = false,
    this.stepped = false,
    this.wrong = false,
    this.current = false,
    this.active = false,
    this.onTap,
  });
  final int row, column;
  final bool lit, stepped, wrong, current, active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label:
        '${row + 1}. sıra ${column + 1}. karo${stepped ? ', doğru adım' : ''}',
    child: ExcludeSemantics(
      child: StepFeedback(
        wrong: wrong,
        correct: stepped,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(
              0,
              stepped || wrong ? 3 : 0,
              0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: wrong
                    ? const [Color(0xFFFF819B), Color(0xFFCE6358)]
                    : lit || stepped
                    ? const [Color(0xFF83C9A1), Color(0xFF288365)]
                    : const [Color(0xFFFAFCF6), Color(0xFFBDCDB5)],
              ),
              border: Border.all(
                color: active ? AppColors.goldLight : const Color(0xFFADA080),
              ),
              boxShadow: [
                BoxShadow(
                  color: wrong
                      ? const Color(0xFF542E28)
                      : const Color(0xFF383C2D),
                  offset: Offset(0, stepped || wrong ? 2 : 5),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x22E4D5B0)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Center(
                child: wrong
                    ? const Icon(Icons.close, size: 20, color: AppColors.paper)
                    : stepped
                    ? Icon(
                        current ? Icons.adjust : Icons.circle,
                        size: current ? 15 : 4,
                        color: AppColors.goldLight,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ClockStrip extends StatefulWidget {
  const ClockStrip({
    super.key,
    required this.label,
    this.deadline,
    this.totalMs = 15000,
    this.trailing,
    this.now,
  });
  final String label;
  final int? deadline;
  final int totalMs;
  final String? trailing;
  final int Function()? now;
  @override
  State<ClockStrip> createState() => _ClockStripState();
}

class _ClockStripState extends State<ClockStrip> {
  Timer? timer;
  int remaining = 0;
  void update() {
    final value = math.max(
      0,
      (widget.deadline ?? 0) -
          (widget.now?.call() ?? DateTime.now().millisecondsSinceEpoch),
    );
    if ((value / 1000).ceil() != (remaining / 1000).ceil() && mounted) {
      setState(() => remaining = value);
    }
  }

  void bind() {
    timer?.cancel();
    remaining = math.max(
      0,
      (widget.deadline ?? 0) -
          (widget.now?.call() ?? DateTime.now().millisecondsSinceEpoch),
    );
    if (widget.deadline != null) {
      timer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => update(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    bind();
  }

  @override
  void didUpdateWidget(ClockStrip old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) bind();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.label, style: const TextStyle(fontSize: 12)),
          ),
          Text(
            widget.trailing ??
                (widget.deadline == null ? '' : clockText(remaining)),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: widget.deadline == null
              ? 1
              : (remaining / widget.totalMs).clamp(0, 1),
          minHeight: 3,
          color: AppColors.gold,
          backgroundColor: AppColors.line,
        ),
      ),
      const SizedBox(height: 22),
    ],
  );
}

class GameNote extends StatelessWidget {
  const GameNote(this.text, {super.key, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppColors.caption.copyWith(
        color: error ? AppColors.red : AppColors.muted,
      ),
    ),
  );
}
