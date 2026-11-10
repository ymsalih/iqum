import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

/// Animal artwork with optional Rive motion.
///
/// Each `assets/art/<animal>.riv` (built by design/rive/build_animals.cjs)
/// holds a default state machine: Entry → `reveal`, and a `match` trigger →
/// `celebrate`. Both are one-shot clips under 0.7 s. The controller is only
/// active while a clip plays, so an idle card costs nothing per frame.
/// Missing native runtime, missing file, reduced motion or hidden tabs all
/// fall back to the cached PNG of the same drawing.
class AnimalArt extends StatefulWidget {
  const AnimalArt(this.animal, {super.key, this.celebrate = false});
  final String animal;

  /// Plays the celebration clip when this flips from false to true (or on
  /// first load if already true).
  final bool celebrate;

  static const revealDuration = Duration(milliseconds: 620);
  static const celebrateDuration = Duration(milliseconds: 720);

  static Future<Set<String>>? _manifest;
  static final Map<String, Future<rive.File?>> _files = {};

  /// Files are tiny (~3 KB) and shared by every card showing that animal.
  static Future<rive.File?> _file(String animal) =>
      _files[animal] ??= () async {
        try {
          _manifest ??= AssetManifest.loadFromAssetBundle(
            rootBundle,
          ).then((m) => m.listAssets().toSet());
          final path = 'assets/art/$animal.riv';
          if (!(await _manifest!).contains(path)) return null;
          final data = await rootBundle.load(path);
          return await rive.File.decode(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            riveFactory: rive.Factory.flutter,
          );
        } catch (_) {
          return null; // Keep the PNG on any runtime/asset failure.
        }
      }();

  @override
  State<AnimalArt> createState() => _AnimalArtState();
}

class _AnimalArtState extends State<AnimalArt> with WidgetsBindingObserver {
  rive.RiveWidgetController? controller;
  Timer? stop;
  int generation = 0;
  bool requested = false;

  bool get motionAllowed =>
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!requested && motionAllowed) {
      requested = true;
      unawaited(load());
    }
    if (!motionAllowed) pause();
  }

  @override
  void didUpdateWidget(AnimalArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animal != widget.animal) {
      release();
      requested = false;
      didChangeDependencies();
    } else if (widget.celebrate && !oldWidget.celebrate) {
      celebrate();
    }
  }

  Future<void> load() async {
    final token = ++generation;
    final file = await AnimalArt._file(widget.animal);
    if (file == null || !mounted || token != generation || !motionAllowed) {
      return;
    }
    try {
      final next = rive.RiveWidgetController(file);
      controller = next;
      setState(() {});
      if (widget.celebrate) {
        celebrate();
      } else {
        play(AnimalArt.revealDuration);
      }
    } catch (_) {
      controller = null; // Malformed artwork: stay on the PNG.
    }
  }

  void play(Duration duration) {
    final c = controller;
    if (c == null || !mounted || !motionAllowed) return;
    stop?.cancel();
    c.active = true;
    stop = Timer(duration, pause);
  }

  void celebrate() {
    final c = controller;
    if (c == null) return;
    // The state machine trigger is the documented input of these files.
    // ignore: deprecated_member_use
    c.stateMachine.trigger('match')?.fire();
    play(AnimalArt.celebrateDuration);
  }

  void pause() {
    stop?.cancel();
    stop = null;
    controller?.active = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
  }

  void release() {
    generation++;
    pause();
    controller?.dispose();
    controller = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) {
      return Image.asset(
        'assets/art/${widget.animal}.png',
        fit: BoxFit.contain,
        cacheWidth: 196,
        excludeFromSemantics: true,
      );
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: rive.RiveWidget(
          controller: c,
          fit: rive.Fit.contain,
          hitTestBehavior: rive.RiveHitTestBehavior.none,
        ),
      ),
    );
  }
}
