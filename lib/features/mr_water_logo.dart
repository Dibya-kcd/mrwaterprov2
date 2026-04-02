import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MrWater Logo Widget — tight-cropped transparent PNG asset
// Cobalt blue drop · white text · fully transparent background
// Works on any background colour.
//
// Asset: assets/images/mrwater_logo.png
// Aspect ratio: 1.86 : 1  (1590 × 856 tight-cropped)
// ══════════════════════════════════════════════════════════════════════════════

class MrWaterLogo extends StatelessWidget {
  final double height;
  // onDark kept for API compat — PNG works on any bg, param ignored
  const MrWaterLogo({super.key, this.height = 60, bool onDark = true});

  static const _asset = 'assets/images/mrwater_logo.png';

  @override
  Widget build(BuildContext context) => Image.asset(
    _asset,
    height: height,
    width: height * 1.86,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}

// ── Full-width logo (fills available width) ───────────────────────────────────
class MrWaterLogoLarge extends StatelessWidget {
  // [size] is the HEIGHT. Width auto-calculated from 1.86:1 aspect ratio.
  final double size;
  const MrWaterLogoLarge({super.key, this.size = 200, bool onDark = true});

  @override
  Widget build(BuildContext context) => Image.asset(
    MrWaterLogo._asset,
    height: size,
    width: size * 1.86,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}

// ── Screen-filling logo (for splash — fills full screen width) ────────────────
class MrWaterLogoFullWidth extends StatelessWidget {
  const MrWaterLogoFullWidth({super.key});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Image.asset(
      MrWaterLogo._asset,
      width: screenW,
      height: screenW / 1.86,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
