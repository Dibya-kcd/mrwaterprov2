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
        color: surf, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      dividerColor: div,
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: s2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: div)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: div)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: a, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: dark ? AppColors.dangerDM : AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: dark ? AppColors.dangerDM : AppColors.danger, width: 1.8)),
        hintStyle: GoogleFonts.inter(color: dark ? AppColors.inkSoftDark : AppColors.inkMuted),
        errorStyle: GoogleFonts.inter(fontSize: 11, color: dark ? AppColors.dangerDM : AppColors.danger),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    return TextTheme(
      // Display — hero numbers, large KPIs
      displayLarge:   GoogleFonts.inter(fontSize: 44, fontWeight: FontWeight.w800, color: ink),
      displayMedium:  GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: ink),
      // Headlines — screen titles, section titles
      headlineLarge:  GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: ink),
      headlineMedium: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      headlineSmall:  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
      // Titles — card headers, form labels
      titleLarge:     GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
      titleMedium:    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
      titleSmall:     GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
      // Body — normal text, descriptions
      bodyLarge:      GoogleFonts.inter(fontSize: 15, color: ink),
      bodyMedium:     GoogleFonts.inter(fontSize: 14, color: ink),
      bodySmall:      GoogleFonts.inter(fontSize: 12, color: m),
      // Labels — chips, badges, pills
      labelLarge:     GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
      labelMedium:    GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .4, color: m),
      labelSmall:     GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: .5, color: m),
    );
  }
}
