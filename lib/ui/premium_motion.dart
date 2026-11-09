import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:confetti/confetti.dart';
import 'theme.dart';

abstract final class MotionTokens {
  static const press = Duration(milliseconds: 70);
  static const feedback = Duration(milliseconds: 240);
  static const flip = Duration(milliseconds: 340);
  static const counter = Duration(milliseconds: 260);
  static const radius = 14.0;
}

class _ReleaseSpring extends Simulation {
  _ReleaseSpring(double value, double velocity)
    : spring = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 450, damping: 28),
        value,
        1,
        velocity,
      );
  final SpringSimulation spring;
  @override
  double x(double time) => time >= .32 ? 1 : spring.x(time);
  @override
  double dx(double time) => time >= .32 ? 0 : spring.dx(time);
  @override
  bool isDone(double time) => time >= .32;
}

/// Adds pointer feedback without replacing the native button's activation,
/// semantics, keyboard support, or disabled/busy callback handling.
class SpringPress extends StatefulWidget {
  const SpringPress({super.key, required this.child, required this.enabled});
  final Widget child;
  final bool enabled;
  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress>
    with SingleTickerProviderStateMixin {
  late final scale = AnimationController.unbounded(vsync: this, value: 1);
  bool get reduced => MediaQuery.disableAnimationsOf(context);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduced || !TickerMode.valuesOf(context).enabled) {
      scale.stop();
      scale.value = 1;
    }
  }

  @override
  void didUpdateWidget(SpringPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      scale.stop();
      scale.value = 1;
    }
  }

  void release() {
    if (reduced || !widget.enabled) {
      scale.value = 1;
    } else {
      scale.animateWith(_ReleaseSpring(scale.value, scale.velocity));
    }
  }

  @override
  void dispose() {
    scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      if (widget.enabled && !reduced) {
        scale.animateTo(
          .97,
          duration: MotionTokens.press,
          curve: Curves.easeOut,
        );
      }
    },
    onPointerUp: (_) => release(),
    onPointerCancel: (_) => release(),
    child: AnimatedBuilder(
      animation: scale,
      child: widget.child,
      builder: (context, child) =>
          Transform.scale(scale: scale.value, child: child),
    ),
  );
}

class ScoreNumber extends StatelessWidget {
  const ScoreNumber(
    this.value, {
    super.key,
    this.prefix = '',
    this.suffix = '',
    this.style,
  });
  final int value;
  final String prefix, suffix;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$prefix$value$suffix',
    child: ExcludeSemantics(
      child: MediaQuery.disableAnimationsOf(context)
          ? Text('$prefix$value$suffix', style: style)
          : RepaintBoundary(
              child: AnimatedFlipCounter(
                value: value,
                prefix: prefix,
                suffix: suffix,
                duration: MotionTokens.counter,
                curve: Curves.easeOutCubic,
                textStyle: style,
              ),
            ),
    ),
  );
}

class StepFeedback extends StatelessWidget {
  const StepFeedback({
    super.key,
    required this.child,
    required this.wrong,
    required this.correct,
  });
  final Widget child;
  final bool wrong, correct;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || (!wrong && !correct)) {
      return child;
    }
    final feedback = Animate(
      key: ValueKey('step-feedback-$wrong-$correct'),
      effects: wrong
          ? [
              ShakeEffect(
                duration: MotionTokens.feedback,
                hz: 3,
                offset: const Offset(3, 0),
              ),
              TintEffect(
                duration: MotionTokens.feedback,
                color: AppColors.red,
                begin: .28,
                end: 0,
              ),
            ]
          : [
              ScaleEffect(
                duration: MotionTokens.feedback,
                begin: const Offset(.95, .95),
                end: const Offset(1, 1),
              ),
              TintEffect(
                duration: MotionTokens.feedback,
                color: AppColors.green,
                begin: .3,
                end: 0,
              ),
              CustomEffect(
                duration: MotionTokens.feedback,
                builder: (_, value, child) => CustomPaint(
                  foregroundPainter: _SuccessWave(value),
                  child: child,
                ),
              ),
            ],
      child: child,
    );
    return RepaintBoundary(child: feedback);
  }
}

class _SuccessWave extends CustomPainter {
  const _SuccessWave(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.longestSide * .7 * progress,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.green.withValues(alpha: .5 * (1 - progress)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SuccessWave oldDelegate) =>
      oldDelegate.progress != progress;
}

class ResultCelebration extends StatefulWidget {
  const ResultCelebration({
    super.key,
    required this.child,
    required this.enabled,
  });
  final Widget child;
  final bool enabled;
  @override
  State<ResultCelebration> createState() => _ResultCelebrationState();
}

class _ResultCelebrationState extends State<ResultCelebration>
    with WidgetsBindingObserver {
  final controller = ConfettiController(
    duration: const Duration(milliseconds: 120),
  );
  Timer? stop;
  bool started = false, visible = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void hide() {
    stop?.cancel();
    controller.stop();
    if (mounted && visible) setState(() => visible = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) hide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      if (widget.enabled &&
          !MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled) {
        visible = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !visible) return;
          controller.play();
          stop = Timer(const Duration(milliseconds: 900), hide);
        });
      }
    } else if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      visible = false;
      stop?.cancel();
      controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topCenter,
    clipBehavior: Clip.none,
    children: [
      widget.child,
      if (visible)
        Positioned(
          top: 110,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: ConfettiWidget(
                confettiController: controller,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: .04,
                numberOfParticles: 6,
                maxBlastForce: 9,
                minBlastForce: 4,
                minimumSize: const Size(3, 3),
                maximumSize: const Size(5, 7),
                gravity: .25,
                colors: const [
                  AppColors.green,
                  AppColors.gold,
                  AppColors.goldLight,
                ],
                shouldLoop: false,
              ),
            ),
          ),
        ),
    ],
  );
}
