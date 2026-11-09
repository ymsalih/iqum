import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ivory = Color(0xFFF5F8F5),
      paper = Color(0xFFFFFFFF),
      text = Color(0xFF183831),
      muted = Color(0xFF6A7C73),
      walnut = Color(0xFF1C4B45),
      dark = Color(0xFF123E38),
      gold = Color(0xFFD69A47),
      goldLight = Color(0xFFF0DAB1),
      green = Color(0xFF147D69),
      red = Color(0xFFCE6358),
      line = Color(0xFFDCE5DC);
  static TextStyle display([double size = 32]) => GoogleFonts.lora(
    fontSize: size,
    height: 1.15,
    letterSpacing: -.8,
    color: text,
  );
  static const eyebrow = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
    color: muted,
  );
  static const caption = TextStyle(fontSize: 12, height: 1.6, color: muted);
  static ThemeData get theme {
    GoogleFonts.config.allowRuntimeFetching = false;
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: ivory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        surface: ivory,
        error: red,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ivory,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: TextTheme(
        bodyMedium: GoogleFonts.manrope(color: text, fontSize: 14),
        bodySmall: caption,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: dark,
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: line,
    );
  }
}
