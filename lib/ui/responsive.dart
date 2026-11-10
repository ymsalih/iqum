import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Layout rules shared by every screen.
///
/// * Phones (320–480 dp wide) use the full width with a gutter that grows
///   with the screen.
/// * Tablets keep the portrait phone layout but draw it larger, so it fills
///   the screen instead of sitting small in the middle ([tabletScale]).
/// * Anything still wider than [maxWidth] (a landscape tablet, a desktop
///   window) shows the game as a centred column; the felt margins are static.
/// * Text can scale up to 1.3× for accessibility; layouts are tested there.
abstract final class Responsive {
  static const maxWidth = 640.0;
  static const maxTextScale = 1.3;

  /// The phone-sized canvas a tablet is scaled down to, before drawing it
  /// back up: an iPad then shows the portrait layout at about 1.2–1.6×.
  static const tabletCanvas = Size(560, 860);
  static const maxTabletScale = 1.6;

  static double tabletScale(Size screen) {
    if (screen.shortestSide < 600) return 1;
    return math
        .min(
          screen.width / tabletCanvas.width,
          screen.height / tabletCanvas.height,
        )
        .clamp(1.0, maxTabletScale)
        .toDouble();
  }

  static double gutter(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w < 360
        ? 14
        : w < 420
        ? 18
        : 22;
  }
}

/// Wraps the whole app (MaterialApp.builder): clamps text scaling, enlarges
/// the layout on tablets and, on screens still too wide, centres a
/// phone-width column. MediaQuery always reports the space a descendant
/// really gets, so every screen lays out for it.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = Responsive.tabletScale(media.size);
    if (scale == 1) return _column(media);
    // Lay the app out on a smaller canvas and draw it scaled up: vector
    // text and shapes stay sharp, touches are mapped back by the transform.
    final size = media.size / scale;
    final inner = media.copyWith(
      size: size,
      devicePixelRatio: media.devicePixelRatio * scale,
      padding: media.padding / scale,
      viewPadding: media.viewPadding / scale,
      viewInsets: media.viewInsets / scale,
      systemGestureInsets: media.systemGestureInsets / scale,
    );
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(data: inner, child: _column(inner)),
      ),
    );
  }

  Widget _column(MediaQueryData media) {
    final clamped = media.copyWith(
      textScaler: media.textScaler.clamp(
        maxScaleFactor: Responsive.maxTextScale,
      ),
    );
    if (media.size.width <= Responsive.maxWidth) {
      return MediaQuery(data: clamped, child: child);
    }
    final side = (media.size.width - Responsive.maxWidth) / 2;
    return ColoredBox(
      color: AppColors.petrol,
      child: Center(
        child: SizedBox(
          width: Responsive.maxWidth,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.ivory,
              border: Border.symmetric(
                vertical: BorderSide(color: AppColors.dark, width: 3),
              ),
            ),
            child: MediaQuery(
              data: clamped.copyWith(
                size: Size(Responsive.maxWidth, media.size.height),
                padding: media.padding.copyWith(
                  left: math.max(0, media.padding.left - side),
                  right: math.max(0, media.padding.right - side),
                ),
                viewPadding: media.viewPadding.copyWith(
                  left: math.max(0, media.viewPadding.left - side),
                  right: math.max(0, media.viewPadding.right - side),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
