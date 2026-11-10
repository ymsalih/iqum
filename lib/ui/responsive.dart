import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Layout rules shared by every screen.
///
/// * Phones (320–480 dp wide) use the full width with a gutter that grows
///   with the screen.
/// * Tablets and other wide windows show the portrait game as a centred
///   column of at most [maxWidth]; the felt-coloured margins are static.
/// * Text can scale up to 1.3× for accessibility; layouts are tested there.
abstract final class Responsive {
  static const maxWidth = 640.0;
  static const maxTextScale = 1.3;

  static double gutter(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w < 360
        ? 14
        : w < 420
        ? 18
        : 22;
  }

  static bool compactHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 640;
}

/// Wraps the whole app (MaterialApp.builder): clamps text scaling and, on
/// wide screens, centres a phone-width column and reports that width through
/// MediaQuery so every descendant lays out for the column it really gets.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
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

/// Sizes a game board so the whole board fits the visible height when
/// possible. [aspect] is the board's width / height; [reserved] is the
/// height taken by the app bar, HUD and controls around it.
class FitBoard extends StatelessWidget {
  const FitBoard({
    super.key,
    required this.aspect,
    required this.reserved,
    required this.child,
    this.minWidth = 260,
  });
  final double aspect, reserved, minWidth;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final visible = media.size.height - media.padding.vertical - reserved;
      final width = math.min(
        constraints.maxWidth,
        math.max(minWidth, visible * aspect),
      );
      return Center(
        child: SizedBox(width: width, child: child),
      );
    },
  );
}
