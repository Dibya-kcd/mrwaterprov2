import 'package:flutter/material.dart';

class AppColors {
  static const bg           = Color(0xFFF0F7FF);   // light blue-white
  static const card         = Color(0xFFFFFFFF);
  static const surface2     = Color(0xFFE3F0FF);
  static const ink          = Color(0xFF0A1628);
  static const inkSoft      = Color(0xFF2D4A7A);
  static const inkMuted     = Color(0xFF6B82A8);
  static const separator    = Color(0xFFCCDFF5);
  static const primary      = Color(0xFF1A6BFF);
  static const primaryDark  = Color(0xFF0A1F6E);
  static const primaryLight = Color(0xFF00C4FF);
  static const coolJar      = Color(0xFF0096C7);
  static const petJar       = Color(0xFF2EC4B6);
  static const success      = Color(0xFF06D6A0);
  static const warning      = Color(0xFFFFD166);
  static const danger       = Color(0xFFEF476F);
  static const orange       = Color(0xFFFF8C42);
  static const purple       = Color(0xFF7B61FF);

  static const bgDark        = Color(0xFF0A0F1A);   // deep ocean dark
  static const cardDark      = Color(0xFF0F1722);
  static const surface2Dark  = Color(0xFF182034);
  static const inkDark       = Color(0xFFD6E8FF);
  static const inkSoftDark   = Color(0xFF7A9CC0);
  static const separatorDark = Color(0xFF1E2D45);
  static const primaryDM     = Color(0xFF4D9FFF);
  static const coolJarDM     = Color(0xFF4CC9F0);
  static const petJarDM      = Color(0xFF64DFDF);
  static const successDM     = Color(0xFF3FB950);
  static const warningDM     = Color(0xFFD29922);
  static const dangerDM      = Color(0xFFF85149);

  static const primaryGradient = LinearGradient(colors: [primary, primaryLight], begin: Alignment.centerLeft, end: Alignment.centerRight);
  static const heroGradient    = LinearGradient(colors: [primaryDark, primary], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const coolGradient    = LinearGradient(colors: [Color(0xFF0077A8), Color(0xFF0096C7)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const petGradient     = LinearGradient(colors: [Color(0xFF1AA39A), Color(0xFF2EC4B6)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const waterGradient   = LinearGradient(colors: [Color(0xFF0A1F6E), Color(0xFF1A6BFF), Color(0xFF00C4FF)], begin: Alignment.topLeft, end: Alignment.bottomRight);

  // ── Water-themed accent presets ──────────────────────────────────────────────
  // Each entry: (hexString, displayName, isDarkFriendly)
  static const waterThemes = <(String, String, String)>[
    ('1A6BFF', 'Ocean Blue',   '4D9FFF'),   // default
    ('0096C7', 'Sky Blue',     '4CC9F0'),
    ('00B4D8', 'Aqua',         '48CAE4'),
    ('2EC4B6', 'Teal',         '64DFDF'),
    ('06D6A0', 'Mint Green',   '3FB950'),
    ('0077B6', 'Deep Ocean',   '4895EF'),
    ('7B61FF', 'Violet',       '9B7FFF'),
    ('FF8C42', 'Sunset',       'FFB347'),
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
