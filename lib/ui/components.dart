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

const _cardBack = ResizeImage(
  AssetImage('assets/brand/card-back.png'),
  width: 220,
);

class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 32, this.wordmark = true, this.light});
  final double size;
  final bool wordmark;
  final bool? light;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/brand/mark.png',
        width: size,
        height: size,
        cacheWidth: (size * 3).round(),
        excludeFromSemantics: true,
      ),
      if (wordmark) ...[
        SizedBox(width: size * .18),
        Text(
          'IQUM',
          style: AppColors.display(
            size * .72,
          ).copyWith(color: light == true ? AppColors.paper : AppColors.text),
        ),
      ],
    ],
  );
}

/// Bilge, the IQUM owl, without its tile (for medallions and the splash).
class OwlMark extends StatelessWidget {
  const OwlMark({super.key, this.size = 64});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/owl.png',
    width: size,
    height: size,
    cacheWidth: (size * 3).round(),
    excludeFromSemantics: true,
  );
}

/// A raised game piece: flat face, solid lip underneath, optional outline.
class Piece extends StatelessWidget {
  const Piece({
    super.key,
    required this.child,
    this.color = AppColors.paper,
    this.lip = AppColors.shade,
    this.border,
    this.radius = 20,
    this.depth = 4,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color color, lip;
  final Color? border;
  final double radius, depth;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: depth),
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border == null ? null : Border.all(color: border!, width: 2),
      boxShadow: AppColors.lip(lip, depth),
    ),
    child: child,
  );
}

/// Compact HUD value: icon, small label and a chunky number.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.dark = false,
  });
  final String label;
  final Widget value;
  final IconData? icon;
  final bool dark;
  @override
  Widget build(BuildContext context) => Piece(
    color: dark ? AppColors.petrol : AppColors.paper,
    lip: dark ? AppColors.dark : AppColors.shade,
    radius: 14,
    depth: 3,
    padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 17,
            color: dark
                ? AppColors.goldLight
                : icon == Icons.favorite_rounded
                ? AppColors.red
                : AppColors.green,
          ),
          const SizedBox(width: 6),
        ],
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: AppColors.eyebrow.copyWith(
              letterSpacing: .4,
              color: dark ? AppColors.goldLight : AppColors.muted,
            ),
          ),
          const SizedBox(width: 7),
        ],
        DefaultTextStyle.merge(
          style: AppColors.display(
            18,
          ).copyWith(color: dark ? AppColors.paper : AppColors.text),
          child: value,
        ),
      ],
    ),
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
              Icons.favorite_rounded,
              size: size,
              color: i < count ? AppColors.red : AppColors.shade,
            ),
          ),
        ),
      ),
    ),
  );
}

enum ButtonTone { primary, secondary, accent }

/// Chunky key-like button: native FilledButton (semantics, focus, disabled
/// state) sitting on a solid lip; pressing sinks it into the lip.
class IqumButton extends StatelessWidget {
  const IqumButton(
    this.label, {
    super.key,
    this.onPressed,
    this.secondary = false,
    this.accent = false,
    this.busy = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, accent, busy;
  final IconData? icon;
  ButtonTone get tone => accent
      ? ButtonTone.accent
      : secondary
      ? ButtonTone.secondary
      : ButtonTone.primary;
  @override
  Widget build(BuildContext context) {
    final enabled = !busy && onPressed != null;
    final (face, ink, lip) = switch (tone) {
      ButtonTone.primary => (AppColors.petrol, AppColors.paper, AppColors.dark),
      ButtonTone.secondary => (
        AppColors.paper,
        AppColors.text,
        AppColors.shade,
      ),
      ButtonTone.accent => (
        AppColors.gold,
        AppColors.text,
        AppColors.amberDeep,
      ),
    };
    return SpringPress(
      enabled: enabled,
      sink: 3,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MotionTokens.radius),
          boxShadow: AppColors.lip(enabled ? lip : AppColors.shade, 4),
        ),
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: face,
            foregroundColor: ink,
            disabledBackgroundColor: AppColors.line,
            disabledForegroundColor: AppColors.muted,
            minimumSize: const Size(44, 54),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            side: tone == ButtonTone.secondary
                ? const BorderSide(color: AppColors.line, width: 2)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MotionTokens.radius),
            ),
            textStyle: AppColors.title(17),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
              if (icon != null) ...[
                const SizedBox(width: 10),
                Icon(icon, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
      title: Text(label),
      actions:
          actions ??
          [
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Brand(size: 30, wordmark: false),
            ),
          ],
    ),
    body: SafeArea(top: false, child: child),
  );
}

/// Petrol felt game table with a solid rim. No perspective transform: the
/// board stays axis-aligned so cards rasterize crisply and cheaply.
class Board extends StatelessWidget {
  const Board({super.key, required this.child, this.path = false});
  final Widget child;
  final bool path;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.petrolMid, AppColors.petrol],
        ),
        border: Border.all(color: AppColors.dark, width: 3),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.lip(AppColors.dark, 6),
      ),
      child: child,
    ),
  );
}

/// A two-sided game card with a perspective flip, lift and landing.
/// Matching pairs pop and the animal celebrates; a wrong pair shakes.
class MemoryTile extends StatefulWidget {
  const MemoryTile({
    super.key,
    required this.index,
    this.animal,
    this.open = false,
    this.matched = false,
    this.highlight = false,
    this.wrong = false,
    this.onTap,
    this.number,
  });
  final int index;
  final String? animal;
  final bool open, matched, highlight, wrong;
  final VoidCallback? onTap;
  final int? number;
  @override
  State<MemoryTile> createState() => _MemoryTileState();
}

enum _Fx { none, pop, shake }

class _MemoryTileState extends State<MemoryTile> with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: MotionTokens.flip,
    value: 0,
  );
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: MotionTokens.settle,
  );
  _Fx _effect = _Fx.none;
  bool _started = false, _celebrate = false;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (_reduced) {
        _flip.value = widget.open ? 1 : 0;
      } else if (widget.open) {
        _flip.forward();
      }
    }
  }

  /// Fraction of the [_fx] timeline spent waiting for the flip to land, so
  /// the reaction reads as a separate beat without any extra timer.
  double _fxDelay = 0;

  /// The verdict (colour, badge, celebration, pop or shake) waits one full
  /// flip, even on the card that was already open: its partner is still
  /// turning, and showing the result early would give the pair away.
  bool get _verdict => _fxDelay == 0 || _fx.value >= _fxDelay;

  void _play(_Fx effect) {
    if (_reduced) return;
    _effect = effect;
    final wait = MotionTokens.flip.inMilliseconds.toDouble();
    final total = wait + MotionTokens.settle.inMilliseconds;
    _fxDelay = wait / total;
    _fx.duration = Duration(milliseconds: total.round());
    _fx.forward(from: 0);
  }

  @override
  void didUpdateWidget(MemoryTile old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) {
      if (_reduced) {
        _flip.value = widget.open ? 1 : 0;
      } else {
        _flip.animateTo(widget.open ? 1 : 0, curve: Curves.easeInOutCubic);
      }
    }
    if (widget.matched && !old.matched) {
      _celebrate = true;
      _play(_Fx.pop);
    }
    if (widget.wrong && !old.wrong) _play(_Fx.shake);
    if (!widget.matched) _celebrate = false;
  }

  @override
  void dispose() {
    _flip.dispose();
    _fx.dispose();
    super.dispose();
  }

  Widget _face(bool front) {
    final w = widget, verdict = _verdict;
    final wrong = w.wrong && verdict, matched = w.matched && verdict;
    final Color face, lip, edge;
    if (!front) {
      face = AppColors.petrol;
      lip = AppColors.dark;
      edge = w.highlight ? AppColors.gold : AppColors.dark;
    } else if (wrong) {
      face = const Color(0xFFFFEDE8);
      lip = AppColors.redDeep;
      edge = AppColors.red;
    } else if (matched) {
      face = const Color(0xFFE5F6EB);
      lip = AppColors.sageDeep;
      edge = AppColors.sageDeep;
    } else {
      face = AppColors.paper;
      lip = AppColors.shade;
      edge = w.highlight ? AppColors.gold : AppColors.dark;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: face,
        image: front
            ? null
            : const DecorationImage(image: _cardBack, fit: BoxFit.cover),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: edge, width: w.highlight ? 3 : 2.2),
        boxShadow: AppColors.lip(lip, 4),
      ),
      child: Stack(
        children: [
          if (front && w.animal != null)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 7, 5, 5),
                child: AnimalArt(w.animal!, celebrate: _celebrate && verdict),
              ),
            ),
          if (w.number != null)
            Positioned(
              left: 4,
              top: 4,
              child: _Badge(
                '${w.number}',
                color: front ? AppColors.petrol : AppColors.goldLight,
                ink: front ? AppColors.paper : AppColors.text,
              ),
            ),
          if (front && matched)
            const Positioned(
              right: 4,
              top: 4,
              child: _Badge(
                '',
                icon: Icons.check_rounded,
                color: AppColors.sageDeep,
              ),
            ),
          if (front && wrong)
            const Positioned(
              right: 4,
              top: 4,
              child: _Badge(
                '',
                icon: Icons.close_rounded,
                color: AppColors.red,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: widget.onTap != null,
    label: widget.open
        ? '${animals[widget.animal] ?? 'Kart'}${widget.matched ? ', eşleşti' : ''}'
        : 'Kapalı kart ${widget.index + 1}',
    child: ExcludeSemantics(
      child: Bounceable(
        scaleFactor: _reduced ? 1 : .94,
        duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 200),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_flip, _fx]),
          builder: (context, _) {
            final t = _flip.value,
                front = t > .5,
                lift = math.sin(math.pi * t),
                angle = math.pi * (t - (front ? 1 : 0)),
                f = _fxDelay >= 1
                    ? 0.0
                    : ((_fx.value - _fxDelay) / (1 - _fxDelay)).clamp(0.0, 1.0);
            var dx = 0.0, scale = 1 + .07 * lift;
            if (_effect == _Fx.pop && f > 0 && f < 1) {
              scale *= 1 + .14 * math.sin(math.pi * f) * (1 - f * .4);
            } else if (_effect == _Fx.shake && f > 0 && f < 1) {
              dx = math.sin(f * math.pi * 6) * 6 * (1 - f);
            }
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0022)
                ..translateByDouble(dx, -9 * lift, 0, 1)
                ..scaleByDouble(scale, scale, 1, 1)
                ..rotateZ(.035 * lift)
                ..rotateY(angle),
              child: _face(front),
            );
          },
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.color, this.ink, this.icon});
  final String text;
  final Color color;
  final Color? ink;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
    child: icon != null
        ? Icon(icon, size: 13, color: AppColors.paper)
        : Text(
            text,
            style: TextStyle(
              fontFamily: AppColors.displayFamily,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              height: 1.2,
              color: ink ?? AppColors.paper,
            ),
          ),
  );
}

//// A face-down stepping stone of the memory path. Stepping on it turns it
/// over like the cards in the other games: sage with a check when it is on
/// the route, coral with a cross (and a shake) when it is not.
class PathTile extends StatefulWidget {
  const PathTile({
    super.key,
    required this.row,
    required this.column,
    this.stepped = false,
    this.wrong = false,
    this.active = false,
    this.lit = false,
    this.onTap,
  });
  final int row, column;
  final bool stepped, wrong, active;

  /// Shown face up in green while the route is being studied.
  final bool lit;
  final VoidCallback? onTap;
  @override
  State<PathTile> createState() => _PathTileState();
}

class _PathTileState extends State<PathTile> with TickerProviderStateMixin {
  bool get _open => widget.stepped || widget.wrong || widget.lit;
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: MotionTokens.flip,
    value: _open ? 1 : 0,
  );
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: MotionTokens.flip + MotionTokens.feedback,
  );
  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(PathTile old) {
    super.didUpdateWidget(old);
    final wasOpen = old.stepped || old.wrong || old.lit;
    if (wasOpen != _open) {
      if (_reduced) {
        _flip.value = _open ? 1 : 0;
      } else {
        _flip.animateTo(_open ? 1 : 0, curve: Curves.easeInOutCubic);
        // Steps react after landing; the study reveal just turns over.
        if (_open && !widget.lit) _fx.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _fx.dispose();
    super.dispose();
  }

  Widget _face(bool front) {
    final w = widget;
    final (Color face, Color lip, Color edge) = !front
        ? (
            AppColors.petrolMid,
            AppColors.dark,
            w.active ? AppColors.gold : AppColors.dark,
          )
        : w.wrong
        ? (AppColors.red, AppColors.redDeep, AppColors.redDeep)
        : (AppColors.sage, AppColors.sageDeep, AppColors.sageDeep);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: face,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: edge, width: w.active && !front ? 3 : 2),
        boxShadow: AppColors.lip(lip, 4),
      ),
      alignment: Alignment.center,
      child: front
          ? Icon(
              w.wrong
                  ? Icons.close_rounded
                  : w.stepped
                  ? Icons.check_rounded
                  : Icons.star_rounded,
              size: w.wrong || w.stepped ? 24 : 18,
              color: w.wrong
                  ? AppColors.paper
                  : w.stepped
                  ? AppColors.dark
                  : AppColors.sageDeep,
            )
          // A plain felt stone with one small amber stud.
          : Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Semantics(
      button: w.onTap != null,
      label:
          '${w.row + 1}. sıra ${w.column + 1}. karo'
          '${w.stepped
              ? ', doğru adım'
              : w.wrong
              ? ', yanlış adım'
              : ''}',
      child: ExcludeSemantics(
        child: Bounceable(
          scaleFactor: _reduced ? 1 : .93,
          duration: const Duration(milliseconds: 90),
          reverseDuration: const Duration(milliseconds: 200),
          onTap: w.onTap,
          child: AnimatedBuilder(
            animation: Listenable.merge([_flip, _fx]),
            builder: (context, _) {
              final t = _flip.value,
                  front = t > .5,
                  lift = math.sin(math.pi * t),
                  angle = math.pi * (t - (front ? 1 : 0));
              // Reaction after the flip lands: pop when right, shake when not.
              final split =
                  MotionTokens.flip.inMilliseconds /
                  (_fx.duration!.inMilliseconds);
              final f = ((_fx.value - split) / (1 - split)).clamp(0.0, 1.0);
              var dx = 0.0, scale = 1 + .06 * lift;
              if (_fx.isAnimating && f > 0) {
                if (w.wrong) {
                  dx = math.sin(f * math.pi * 6) * 5 * (1 - f);
                } else {
                  scale *= 1 + .1 * math.sin(math.pi * f);
                }
              }
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .0022)
                  ..translateByDouble(dx, -6 * lift, 0, 1)
                  ..scaleByDouble(scale, scale, 1, 1)
                  ..rotateY(angle),
                child: _face(front),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A chunky star on its own lip (result screen, level stops).
class ScoreStar extends StatelessWidget {
  const ScoreStar({super.key, required this.filled, this.size = 40});
  final bool filled;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size + size * .08,
    child: Stack(
      children: [
        Positioned(
          top: size * .08,
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: filled ? AppColors.amberDeep : AppColors.line,
          ),
        ),
        Icon(
          Icons.star_rounded,
          size: size,
          color: filled ? AppColors.gold : AppColors.shade,
        ),
      ],
    ),
  );
}

/// One to three stars; empty slots stay as outlines.
class StarRow extends StatelessWidget {
  const StarRow(this.count, {super.key, this.size = 16, this.light = false});
  final int count;
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count yıldız',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Icon(
            i < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < count
                ? AppColors.gold
                : light
                ? AppColors.goldLight.withValues(alpha: .5)
                : AppColors.line,
          ),
        ),
      ),
    ),
  );
}

// Chunky timer bar. Updates once per second with a short glide, never per
/// frame; turns coral in the last quarter.
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
  int get _now => widget.now?.call() ?? DateTime.now().millisecondsSinceEpoch;
  void update() {
    final value = math.max(0, (widget.deadline ?? 0) - _now);
    if ((value / 1000).ceil() != (remaining / 1000).ceil() && mounted) {
      setState(() => remaining = value);
    }
  }

  void bind() {
    timer?.cancel();
    remaining = math.max(0, (widget.deadline ?? 0) - _now);
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
  Widget build(BuildContext context) {
    final running = widget.deadline != null;
    final fraction = running
        ? (remaining / widget.totalMs).clamp(0.0, 1.0)
        : 1.0;
    final urgent = running && fraction <= .25;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                running ? Icons.timer_rounded : Icons.flag_rounded,
                size: 18,
                color: urgent ? AppColors.red : AppColors.green,
              ),
              const SizedBox(width: 7),
              Expanded(child: Text(widget.label, style: AppColors.body)),
              Text(
                widget.trailing ?? (running ? clockText(remaining) : ''),
                style: AppColors.display(
                  19,
                ).copyWith(color: urgent ? AppColors.red : AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.shade,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              widthFactor: fraction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: !running
                      ? AppColors.sage
                      : urgent
                      ? AppColors.red
                      : AppColors.gold,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GameNote extends StatelessWidget {
  const GameNote(this.text, {super.key, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (error) ...[
          const Icon(Icons.error_rounded, size: 18, color: AppColors.red),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppColors.body.copyWith(
              fontSize: 14,
              color: error ? AppColors.red : AppColors.muted,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Large porcelain answer key used by Sequence Memory (solo and duel).
class AnimalChoice extends StatelessWidget {
  const AnimalChoice({
    super.key,
    required this.animal,
    required this.label,
    this.onTap,
  });
  final String animal, label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: ExcludeSemantics(
      child: SpringPress(
        enabled: onTap != null,
        sink: 2,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line, width: 2),
              boxShadow: AppColors.lip(AppColors.shade, 3),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 5, 4, 3),
                child: Column(
                  children: [
                    Expanded(
                      child: Image.asset(
                        'assets/art/$animal.png',
                        cacheWidth: 144,
                        excludeFromSemantics: true,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: AppColors.body.copyWith(fontSize: 11),
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
