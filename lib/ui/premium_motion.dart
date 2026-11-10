import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:confetti/confetti.dart';
import 'theme.dart';

abstract final class MotionTokens {
  static const press = Duration(milliseconds: 70);
  static const feedback = Duration(milliseconds: 280);
  static const flip = Duration(milliseconds: 360);
  static const settle = Duration(milliseconds: 420);
  static const counter = Duration(milliseconds: 260);
  static const radius = 16.0;
  static const pressedScale = .965;
}

class _ReleaseSpring extends Simulation {
  _ReleaseSpring(double value, double velocity)
    : spring = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 520, damping: 24),
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

/// Pointer feedback without replacing the native button's activation,
/// semantics, keyboard support, or disabled/busy callback handling.
/// With [sink] the child also moves down into its lip while pressed, like a
/// physical key; the spring release adds a small overshoot.
class SpringPress extends StatefulWidget {
  const SpringPress({
    super.key,
    required this.child,
    required this.enabled,
    this.sink = 0,
  });
  final Widget child;
  final bool enabled;
  final double sink;
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
          MotionTokens.pressedScale,
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
      builder: (context, child) {
        final pressed = ((1 - scale.value) / (1 - MotionTokens.pressedScale))
            .clamp(-1.0, 1.0);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(0, widget.sink * pressed, 0, 1)
            ..scaleByDouble(scale.value, scale.value, 1, 1),
          child: child,
        );
      },
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
                curve: Curves.easeOutBack,
                textStyle: style,
              ),
            ),
    ),
  );
}

/// One-shot feedback for a stepped tile: wrong = shake + coral flash,
/// correct = quick squash-and-pop. Nothing repeats.
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
                hz: 5,
                offset: const Offset(5, 0),
              ),
              TintEffect(
                duration: MotionTokens.feedback,
                color: AppColors.red,
                begin: .35,
                end: 0,
              ),
            ]
          : [
              ScaleEffect(
                duration: MotionTokens.feedback,
                curve: Curves.easeOutBack,
                begin: const Offset(.86, .86),
                end: const Offset(1, 1),
              ),
            ],
      child: child,
    );
    return RepaintBoundary(child: feedback);
  }
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
    duration: const Duration(milliseconds: 160),
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
          top: 120,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: ConfettiWidget(
                confettiController: controller,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: .05,
                numberOfParticles: 9,
                maxBlastForce: 14,
                minBlastForce: 6,
                minimumSize: const Size(6, 4),
                maximumSize: const Size(10, 7),
                gravity: .3,
                colors: const [
                  AppColors.gold,
                  AppColors.sage,
                  AppColors.red,
                  AppColors.petrolMid,
                ],
                shouldLoop: false,
              ),
            ),
          ),
        ),
    ],
  );
}
