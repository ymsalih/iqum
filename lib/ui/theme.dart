import 'package:flutter/material.dart';

/// IQUM "masa oyunu" design tokens: porcelain table, petrol felt boards,
/// measured amber highlights and tactile pieces with a solid bottom lip.
/// Lips are hard (blur-free) offsets so every piece costs one extra rect.
abstract final class AppColors {
  // Surfaces
  static const ivory =
          Color(0xFFF6F0E4), // app background (porcelain)
      paper =
          Color(0xFFFFFBF3), // raised porcelain pieces
      shade =
          Color(0xFFE6DAC6), // porcelain lip / pressed
      line = Color(0xFFE4D9C6);
  // Ink
  static const text = Color(0xFF10302B), muted = Color(0xFF5F716B);
  // Petrol felt
  static const petrol = Color(0xFF145249),
      walnut = Color(0xFF145249),
      petrolMid = Color(0xFF1B6B5E),
      dark = Color(0xFF0B2E2A);
  // Amber accent (used sparingly: current level, rewards, the main CTA)
  static const gold = Color(0xFFF2A93B),
      goldLight = Color(0xFFFFD58A),
      amberDeep = Color(0xFFB9741A);
  // Feedback
  static const green = Color(0xFF1F7A63),
      sage = Color(0xFF9FDDB6),
      sageDeep = Color(0xFF3E9B6C),
      red = Color(0xFFE0584A),
      redDeep = Color(0xFFA83A2E);

  static const displayFamily = 'Baloo2', bodyFamily = 'Nunito';

  /// Chunky rounded display type for titles and numbers.
  static TextStyle display([double size = 32]) => TextStyle(
    fontFamily: displayFamily,
    fontSize: size,
    fontWeight: FontWeight.w800,
    height: 1.08,
    letterSpacing: -.2,
    color: text,
  );

  /// Softer display weight for card titles and buttons.
  static TextStyle title([double size = 18]) => TextStyle(
    fontFamily: displayFamily,
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: text,
  );

  static const eyebrow = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
    color: muted,
  );
  static const caption = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: muted,
  );
  static const body = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: text,
  );

  /// Solid lip under a raised piece (no blur: cheap to rasterize).
  static List<BoxShadow> lip(Color color, [double depth = 4]) => [
    BoxShadow(color: color, offset: Offset(0, depth)),
  ];

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: petrol,
      primary: petrol,
      secondary: gold,
      surface: ivory,
      error: red,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: bodyFamily,
      scaffoldBackgroundColor: ivory,
      colorScheme: scheme,
      // Plain ripple: Material 3's sparkle splash runs a fragment shader.
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: ivory,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: title(17),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16, color: text),
        bodyMedium: TextStyle(fontSize: 14, color: text),
        bodySmall: caption,
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: text),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: green,
          textStyle: const TextStyle(
            fontFamily: bodyFamily,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark,
        behavior: SnackBarBehavior.floating,
        shape: rounded,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFamily,
          fontWeight: FontWeight.w700,
          color: paper,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ivory,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? paper : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? green : shade,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? green : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: petrol, width: 2),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: petrol,
        titleTextStyle: TextStyle(
          fontFamily: bodyFamily,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: text,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: petrol,
        linearTrackColor: shade,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 2),
      dividerColor: line,
    );
  }
}
