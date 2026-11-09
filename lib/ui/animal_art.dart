import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

/// Optional local Rive artwork. Missing/invalid assets retain the existing art;
/// the native runtime is never initialized just to display a PNG.
class AnimalArt extends StatefulWidget {
  const AnimalArt(this.animal, {super.key});
  final String animal;
  @override
  State<AnimalArt> createState() => _AnimalArtState();
}

class _AnimalArtState extends State<AnimalArt> with WidgetsBindingObserver {
  static Future<Set<String>>? manifest;
  rive.File? file;
  rive.RiveWidgetController? controller;
  Timer? stop;
  int generation = 0;
  bool requested = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!requested &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      requested = true;
      unawaited(load());
    }
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      controller?.active = false;
      stop?.cancel();
    }
  }

  @override
  void didUpdateWidget(AnimalArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animal != widget.animal) {
      release();
      requested = false;
      didChangeDependencies();
    }
  }

  Future<void> load() async {
    final token = ++generation;
    rive.File? loaded;
    try {
      manifest ??= AssetManifest.loadFromAssetBundle(
        rootBundle,
      ).then((m) => m.listAssets().toSet());
      final path = 'assets/art/${widget.animal}.riv';
      if (!(await manifest!).contains(path) ||
          !mounted ||
          token != generation) {
        return;
      }
      loaded = await rive.File.asset(path, riveFactory: rive.Factory.flutter);
      if (!mounted || token != generation) {
        loaded?.dispose();
        return;
      }
      if (loaded == null) return;
      final next = rive.RiveWidgetController(loaded);
      file = loaded;
      controller = next;
      next.active =
          !MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled;
      setState(() {});
      stop = Timer(
        const Duration(milliseconds: 360),
        () => next.active = false,
      );
    } catch (_) {
      loaded
          ?.dispose(); /* Keep the recognisable PNG on any art/runtime failure. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      controller?.active = false;
      stop?.cancel();
    }
  }

  void release() {
    generation++;
    stop?.cancel();
    controller?.dispose();
    controller = null;
    file?.dispose();
    file = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => controller == null
      ? Image.asset(
          'assets/art/${widget.animal}.png',
          fit: BoxFit.contain,
          cacheWidth: 196,
        )
      : RepaintBoundary(
          child: rive.RiveWidget(
            controller: controller!,
            fit: rive.Fit.contain,
          ),
        );
}
