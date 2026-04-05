// ══════════════════════════════════════════════════════════════════════════════
// app_logo.dart  — Dynamic company logo widget
//
// Place this file at:  lib/features/app_logo.dart
//
// Resolution order (highest → lowest priority):
//   1. Network URL   — settings.logoUrl (Firebase Storage / any HTTPS URL)
//   2. Local file    — settings.logoLocalPath (picked from device gallery)
//   3. Default asset — assets/images/mrwater_logo.png
//
// Drop-in replacements for old MrWaterLogo / MrWaterLogoLarge:
//   AppLogo(height: 86)           // app bar
//   AppLogo(height: 140)          // drawer header, profile sheet
//   AppLogo.fullWidth()           // fills available width (splash-style)
//
// Also exports LogoPickerWidget — drop this into Settings → App Identity.
//
// Required pubspec.yaml additions (add if not already present):
//   dependencies:
//     cached_network_image: ^3.3.1
//     image_picker: ^1.0.7
//
// Note: image_picker requires platform setup:
//   Android: add READ_EXTERNAL_STORAGE permission in AndroidManifest
//   iOS:     add NSPhotoLibraryUsageDescription in Info.plist
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';

// ── Default fallback asset ────────────────────────────────────────────────────
const _kDefaultAsset = 'assets/images/mrwater_logo.png';

// ══════════════════════════════════════════════════════════════════════════════
// AppLogo — PRIMARY WIDGET
// Reads settingsProvider automatically. No props needed beyond size.
// ══════════════════════════════════════════════════════════════════════════════
class AppLogo extends ConsumerWidget {
  final double height;
  final BoxFit fit;
  // onDark kept for drop-in compat with old MrWaterLogo API — ignored
  // ignore: avoid_unused_constructor_parameters
  const AppLogo({
    super.key,
    this.height = 60,
    this.fit = BoxFit.contain,
    bool onDark = true,
  });

  /// Full-width variant — height auto-calculated from content aspect ratio.
  static Widget fullWidth({Key? key}) => _AppLogoFullWidth(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return _LogoResolver(
      logoUrl: s.logoUrl,
      logoLocalPath: s.logoLocalPath,
      height: height,
      fit: fit,
      businessName: s.appName.isNotEmpty ? s.appName : s.businessName,
    );
  }
}

// ── Full-width variant ────────────────────────────────────────────────────────
class _AppLogoFullWidth extends ConsumerWidget {
  const _AppLogoFullWidth({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final w = MediaQuery.of(context).size.width;
    return _LogoResolver(
      logoUrl: s.logoUrl,
      logoLocalPath: s.logoLocalPath,
      height: w / 1.86,  // default asset is 1.86:1 — network images use natural ratio
      fit: BoxFit.contain,
      businessName: s.appName.isNotEmpty ? s.appName : s.businessName,
      fullWidth: true,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _LogoResolver — internal: picks source and renders correctly
// ══════════════════════════════════════════════════════════════════════════════
class _LogoResolver extends StatelessWidget {
  final String logoUrl;
  final String logoLocalPath;
  final double height;
  final BoxFit fit;
  final String businessName;
  final bool fullWidth;

  const _LogoResolver({
    required this.logoUrl,
    required this.logoLocalPath,
    required this.height,
    required this.fit,
    required this.businessName,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = fullWidth ? double.infinity : height * 1.86;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth  = w.isFinite      ? (w      * pixelRatio).round() : null;
    final cacheHeight = height.isFinite ? (height * pixelRatio).round() : null;

    // ── Priority 1: Network URL ───────────────────────────────────────────────
    if (logoUrl.isNotEmpty && Uri.tryParse(logoUrl)?.hasAbsolutePath == true) {
      return Image.network(
        logoUrl,
        height: height,
        width: w,
        fit: fit,
        filterQuality: FilterQuality.high,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : _placeholder(context, height, w),
        errorBuilder: (ctx, _, __) => _placeholder(context, height, w),
      );
    }

    // ── Priority 2: Local file path ───────────────────────────────────────────
    if (logoLocalPath.isNotEmpty) {
      final file = File(logoLocalPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          height: height,
          width: w,
          fit: fit,
          filterQuality: FilterQuality.high,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (_, __, ___) => _defaultAsset(height, w),
        );
      }
    }

    // ── Priority 3: Default asset ─────────────────────────────────────────────
    return _defaultAsset(height, w);
  }

  Widget _defaultAsset(double h, double w) => Builder(
    builder: (context) {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final cacheWidth  = w.isFinite ? (w * pixelRatio).round() : null;
      final cacheHeight = h.isFinite ? (h * pixelRatio).round() : null;
      return Image.asset(
        _kDefaultAsset,
        height: h,
        width: w,
        fit: fit,
        filterQuality: FilterQuality.high,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
    },
  );

  Widget _placeholder(BuildContext ctx, double h, double w) =>
      _InitialsPlaceholder(name: businessName, height: h, width: w);
}

// ══════════════════════════════════════════════════════════════════════════════
// _InitialsPlaceholder — shown while loading or on error
// Branded gradient pill with business initials
// ══════════════════════════════════════════════════════════════════════════════
class _InitialsPlaceholder extends StatelessWidget {
  final String name;
  final double height;
  final double width;
  const _InitialsPlaceholder({required this.name, required this.height, required this.width});

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : 'MW';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final fs = (height * 0.38).clamp(14.0, 40.0);
    return Container(
      height: height,
      width: width == double.infinity ? null : width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.72)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(height * 0.16),
      ),
      child: Center(
        child: Text(_initials,
          style: GoogleFonts.inter(
            fontSize: fs, fontWeight: FontWeight.w800,
            color: Colors.white, letterSpacing: 2,
          )),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LogoPickerWidget — drop into Settings → App Identity section
//
// Features:
//   • Live preview of current logo
//   • Paste URL — for Firebase Storage / Cloudinary / any HTTPS image
//   • Pick from Gallery — local file (mobile only)
//   • Clear — restores default asset
//   • Tips panel
// ══════════════════════════════════════════════════════════════════════════════
class LogoPickerWidget extends ConsumerStatefulWidget {
  const LogoPickerWidget({super.key});

  @override
  ConsumerState<LogoPickerWidget> createState() => _LogoPickerState();
}

class _LogoPickerState extends ConsumerState<LogoPickerWidget> {
  final _urlCtrl = TextEditingController();
  bool _showUrlField = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = ref.read(settingsProvider).logoUrl;
  }

  @override
  void dispose() { _urlCtrl.dispose(); super.dispose(); }

  AppSettings get _s => ref.read(settingsProvider);

  void _save(AppSettings updated) {
    ref.read(settingsProvider.notifier).save(updated);
  }

  void _saveUrl() {
    final url = _urlCtrl.text.trim();
    _save(_s.copyWith(logoUrl: url, logoLocalPath: ''));
    setState(() => _showUrlField = false);
    _toast(url.isEmpty ? 'Logo URL cleared' : '✅ Logo URL saved — preview updated');
  }

  Future<void> _pickFromGallery() async {
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 430,
        imageQuality: 92,
      );
      if (img != null && mounted) {
        _save(_s.copyWith(logoUrl: '', logoLocalPath: img.path));
        _toast('✅ Logo updated from gallery');
      }
    } catch (e) {
      if (mounted) _toast('Could not pick image: $e', error: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _clear() {
    _save(_s.copyWith(logoUrl: '', logoLocalPath: ''));
    _urlCtrl.clear();
    setState(() => _showUrlField = false);
    _toast('Logo cleared — default restored');
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      backgroundColor: error
          ? AppColors.dangerColor(Theme.of(context).brightness == Brightness.dark)
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s       = ref.watch(settingsProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final hasCustom = s.logoUrl.isNotEmpty || s.logoLocalPath.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Live logo preview ───────────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasCustom
                ? primary.withValues(alpha: 0.45)
                : (isDark ? AppColors.separatorDark : AppColors.separator),
            width: hasCustom ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          const AppLogo(height: 72),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (hasCustom ? primary : AppColors.inkMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              hasCustom
                  ? (s.logoUrl.isNotEmpty ? '🔗 Custom URL' : '📱 From device')
                  : '🏷 Default logo',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: hasCustom ? primary : AppColors.inkMuted,
              ),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 14),

      // ── Action buttons ──────────────────────────────────────────────────────
      Row(children: [
        Expanded(child: _LogoActionBtn(
          icon: Icons.link_rounded,
          label: 'Paste URL',
          color: primary,
          isDark: isDark,
          active: _showUrlField,
          onTap: () => setState(() => _showUrlField = !_showUrlField),
        )),
        const SizedBox(width: 10),
        Expanded(child: _LogoActionBtn(
          icon: _picking ? Icons.hourglass_top_rounded : Icons.photo_library_rounded,
          label: _picking ? 'Picking…' : 'From Gallery',
          color: AppColors.successColor(isDark),
          isDark: isDark,
          onTap: _picking ? null : _pickFromGallery,
        )),
        if (hasCustom) ...[
          const SizedBox(width: 10),
          _LogoActionBtn(
            icon: Icons.delete_outline_rounded,
            label: 'Reset',
            color: AppColors.dangerColor(isDark),
            isDark: isDark,
            compact: true,
            onTap: _clear,
          ),
        ],
      ]),

      // ── URL input panel ─────────────────────────────────────────────────────
      if (_showUrlField) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.20)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Logo Image URL',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: primary)),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://firebasestorage.googleapis.com/...',
                hintStyle: GoogleFonts.inter(color: AppColors.inkMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
              onSubmitted: (_) => _saveUrl(),
            ),
            const SizedBox(height: 8),
            Text(
              'Use a direct image link (PNG / JPG / WebP with transparent background). '
              'Upload to Firebase Storage and paste the Download URL here.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => setState(() {
                  _showUrlField = false;
                  _urlCtrl.text = s.logoUrl;
                }),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: _saveUrl,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Apply Logo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              )),
            ]),
          ]),
        ),
      ],

      const SizedBox(height: 14),

      // ── Tips ────────────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningColor(isDark).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warningColor(isDark).withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.lightbulb_rounded, size: 14, color: AppColors.warningColor(isDark)),
            const SizedBox(width: 6),
            Text('Logo Tips',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.warningColor(isDark))),
          ]),
          const SizedBox(height: 8),
          ...[
            'Transparent PNG works best on any background colour',
            'Ideal size: 400 × 215 px  (1.86 : 1 aspect ratio)',
            'Upload to Firebase Storage → copy the Download URL',
            'From Gallery: works offline, stored on this device only',
            'URL logo syncs automatically across all devices',
          ].map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
              Expanded(child: Text(tip,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted, height: 1.4))),
            ]),
          )),
        ]),
      ),
    ]);
  }
}

// ── Reusable logo action button ───────────────────────────────────────────────
class _LogoActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final bool active;
  final bool compact;
  final VoidCallback? onTap;

  const _LogoActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.active = false,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.12)
              : (disabled ? Colors.transparent : color.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? color
                : (disabled
                    ? (isDark ? AppColors.separatorDark : AppColors.separator)
                    : color.withValues(alpha: 0.28)),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
          Icon(icon, size: 15, color: disabled ? AppColors.inkMuted : color),
          if (!compact) ...[
            const SizedBox(width: 6),
            Flexible(child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: disabled ? AppColors.inkMuted : color),
                overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ]),
      ),
    );
  }
}
