import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static Color? _hex(String h) {
    try { return Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16)); }
    catch (_) { return null; }
  }

  static ThemeData make({required bool dark, String accent = '1A6BFF'}) {
    final a    = _hex(accent) ?? (dark ? AppColors.primaryDM : AppColors.primary);
    final bg   = dark ? AppColors.bgDark    : AppColors.bg;
    final surf = dark ? AppColors.cardDark  : AppColors.card;
    final s2   = dark ? AppColors.surface2Dark : AppColors.surface2;
    final ink  = dark ? AppColors.inkDark   : AppColors.ink;
    final div  = dark ? AppColors.separatorDark : AppColors.separator;

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: a, onPrimary: Colors.white,
        secondary: AppColors.primaryLight, onSecondary: Colors.white,
        error: dark ? AppColors.dangerDM : AppColors.danger, onError: Colors.white,
        surface: surf, onSurface: ink,
      ),
      textTheme: _txt(ink, dark),
      cardTheme: CardThemeData(
        color: surf, 
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.15 : 0.08),
      ),
      dividerColor: div,
      inputDecorationTheme: InputDecorationTheme(
        filled: true, 
        fillColor: s2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: div, width: 1)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: div, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: a, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: dark ? AppColors.dangerDM : AppColors.danger, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: dark ? AppColors.dangerDM : AppColors.danger, width: 2)),
        hintStyle: GoogleFonts.inter(color: dark ? AppColors.inkSoftDark : AppColors.inkMuted, fontSize: 14),
        errorStyle: GoogleFonts.inter(fontSize: 12, color: dark ? AppColors.dangerDM : AppColors.danger),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(width: 1.5),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 0.1),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.grey[400]),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? a : div),
      ),
    );
  }

  static ThemeData light(String accent) => make(dark: false, accent: accent);
  static ThemeData dark(String accent)  => make(dark: true,  accent: accent);

  static TextTheme _txt(Color ink, bool dark) {
    final m = dark ? AppColors.inkSoftDark : AppColors.inkMuted;
    const fallback = ['Arial', 'sans-serif'];
    return TextTheme(
      // Display - hero numbers, large KPIs
      displayLarge:   GoogleFonts.inter(textStyle: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: ink, letterSpacing: -1, fontFamilyFallback: fallback)),
      displayMedium:  GoogleFonts.inter(textStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.5, fontFamilyFallback: fallback)),
      displaySmall:   GoogleFonts.inter(textStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ink, fontFamilyFallback: fallback)),
      // Headlines - screen titles, section titles
      headlineLarge:  GoogleFonts.inter(textStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.5, fontFamilyFallback: fallback)),
      headlineMedium: GoogleFonts.inter(textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink, fontFamilyFallback: fallback)),
      headlineSmall:  GoogleFonts.inter(textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink, fontFamilyFallback: fallback)),
      // Titles - card headers, form labels
      titleLarge:     GoogleFonts.inter(textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink, fontFamilyFallback: fallback)),
      titleMedium:    GoogleFonts.inter(textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink, fontFamilyFallback: fallback)),
      titleSmall:     GoogleFonts.inter(textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink, fontFamilyFallback: fallback)),
      // Body - normal text, descriptions
      bodyLarge:      GoogleFonts.inter(textStyle: TextStyle(fontSize: 16, color: ink, height: 1.5, fontFamilyFallback: fallback)),
      bodyMedium:     GoogleFonts.inter(textStyle: TextStyle(fontSize: 14, color: ink, height: 1.4, fontFamilyFallback: fallback)),
      bodySmall:      GoogleFonts.inter(textStyle: TextStyle(fontSize: 12, color: m, height: 1.4, fontFamilyFallback: fallback)),
      // Labels - chips, badges, pills
      labelLarge:     GoogleFonts.inter(textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink, fontFamilyFallback: fallback)),
      labelMedium:    GoogleFonts.inter(textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: m, fontFamilyFallback: fallback)),
      labelSmall:     GoogleFonts.inter(textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: m, fontFamilyFallback: fallback)),
    );
  }
}
