import 'package:flutter/material.dart';

class AppColors {
  // Minimalistic neutral palette
  static const bg           = Color(0xFFFAFAFA);   // very light gray-white
  static const card         = Color(0xFFFFFFFF);
  static const surface2     = Color(0xFFF5F5F5);   // subtle gray
  static const ink          = Color(0xFF1C1C1E);   // dark gray-black
  static const inkSoft      = Color(0xFF48484A);   // medium gray
  static const inkMuted     = Color(0xFF8E8E93);   // light gray
  static const separator    = Color(0xFFE5E5EA);   // very light separator
  static const primary      = Color(0xFF007AFF);   // iOS blue accent
  static const primaryDark  = Color(0xFF0051D5);   // darker blue
  static const primaryLight = Color(0xFF5AC8FA);   // lighter blue
  static const coolJar      = Color(0xFF3478F6);   // muted blue
  static const petJar       = Color(0xFF30D158);   // green accent
  static const success      = Color(0xFF34C759);   // iOS green
  static const warning      = Color(0xFFFF9500);   // iOS orange
  static const danger       = Color(0xFFFF3B30);   // iOS red
  static const orange       = Color(0xFFFF9500);   // consistent orange
  static const purple       = Color(0xFFAF52DE);   // muted purple

  // Dark theme - minimalistic dark palette
  static const bgDark        = Color(0xFF000000);   // pure black
  static const cardDark      = Color(0xFF1C1C1E);   // dark gray
  static const surface2Dark  = Color(0xFF2C2C2E);   // medium dark gray
  static const inkDark       = Color(0xFFFFFFFF);   // white text
  static const inkSoftDark   = Color(0xFFAEAEB2);   // light gray
  static const separatorDark = Color(0xFF38383A);   // dark separator
  static const primaryDM     = Color(0xFF0A84FF);   // iOS blue dark mode
  static const coolJarDM     = Color(0xFF64A2FF);   // muted blue dark
  static const petJarDM      = Color(0xFF63D86E);   // green dark mode
  static const successDM     = Color(0xFF30D158);   // iOS green dark
  static const warningDM     = Color(0xFFFF9F0A);   // iOS orange dark
  static const dangerDM      = Color(0xFFFF453A);   // iOS red dark

  static const primaryGradient = LinearGradient(colors: [primary, primaryLight], begin: Alignment.centerLeft, end: Alignment.centerRight);
  static const heroGradient    = LinearGradient(colors: [primaryDark, primary], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const coolGradient    = LinearGradient(colors: [coolJar, Color(0xFF64A2FF)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const petGradient     = LinearGradient(colors: [petJar, Color(0xFF63D86E)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const waterGradient   = LinearGradient(colors: [primaryDark, primary, primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight);

  // ── Water-themed accent presets ──────────────────────────────────────────────
  // Minimalistic accent presets
  static const waterThemes = <(String, String, String)>[
    ('007AFF', 'Ocean Blue',   '0A84FF'),   // default iOS blue
    ('3478F6', 'Sky Blue',     '64A2FF'),
    ('5AC8FA', 'Aqua',         '64D2FF'),
    ('30D158', 'Mint Green',   '63D86E'),
    ('34C759', 'Green',        '30D158'),
    ('0051D5', 'Deep Ocean',   '0A84FF'),
    ('AF52DE', 'Violet',       'BF5AF2'),
    ('FF9500', 'Sunset',       'FF9F0A'),
  ];

  // bool-based helpers
  static Color coolColor(bool dark) => dark ? coolJarDM : coolJar;
  static Color petColor(bool dark)  => dark ? petJarDM  : petJar;
  static Color successColor(bool dark) => dark ? successDM : success;
  static Color dangerColor(bool dark)  => dark ? dangerDM  : danger;
  static Color warningColor(bool dark) => dark ? warningDM : warning;
  static Color primaryColor(bool dark) => dark ? primaryDM : primary;
  static Color inkSoftColor(bool dark) => dark ? inkSoftDark : inkSoft;
  static Color cardColor(bool dark) => dark ? cardDark : card;
  static Color bgColor(bool dark) => dark ? bgDark : bg;

  // BuildContext-based helpers
  static bool isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
  static Color cool(BuildContext ctx) => isDark(ctx) ? coolJarDM : coolJar;
  static Color pet(BuildContext ctx)  => isDark(ctx) ? petJarDM  : petJar;
  static Color ok(BuildContext ctx)   => isDark(ctx) ? successDM : success;
  static Color err(BuildContext ctx)  => isDark(ctx) ? dangerDM  : danger;
  static Color warn(BuildContext ctx) => isDark(ctx) ? warningDM : warning;
  static Color pr(BuildContext ctx)   => isDark(ctx) ? primaryDM : primary;
  static Color cardBg(BuildContext ctx) => isDark(ctx) ? cardDark : card;
  static Color s2(BuildContext ctx)   => isDark(ctx) ? surface2Dark : surface2;
  static Color sep(BuildContext ctx)  => isDark(ctx) ? separatorDark : separator;
}
