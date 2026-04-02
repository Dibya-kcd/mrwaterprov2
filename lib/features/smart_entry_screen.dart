// ════════════════════════════════════════════════════════════════════════════
// smart_entry_screen.dart  — Handwritten Sheet → Smart Data Entry
//
// Flow:
//   1. Capture / upload photo
//   2. OCR via google_mlkit_text_recognition
//   3. Parse OCR rows → (name, delivered, returned, payment)
//   4. Fuzzy-match names against real customers (Levenshtein)
//   5. Editable preview table (green/yellow/red confidence)
//   6. Save → creates JarTransaction records
// ════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// Conditional import: on web, use a stub that provides the same class names
// but never calls any native code. The real ML Kit only compiles on Android/iOS.
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    if (dart.library.html) '../stubs/mlkit_stub.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════

enum MatchConfidence { high, low, none }

class ParsedRow {
  final String rawName;
  final int delivered;
  final int returned;
  final double payment;

  const ParsedRow({
    required this.rawName,
    required this.delivered,
    required this.returned,
    required this.payment,
  });
}

class MatchedRow {
  ParsedRow parsed;
  Customer? customer;
  double confidence;
  MatchConfidence get level {
    if (confidence >= 0.7) return MatchConfidence.high;
    if (confidence >= 0.4) return MatchConfidence.low;
    return MatchConfidence.none;
  }

  // Editable fields
  int delivered;
  int returned;
  double payment;

  MatchedRow({
    required this.parsed,
    required this.customer,
    required this.confidence,
  })  : delivered = parsed.delivered,
        returned  = parsed.returned,
        payment   = parsed.payment;
}

// ══════════════════════════════════════════════════════════════════════════════
// OCR SERVICE
// google_mlkit_text_recognition is NATIVE ONLY (Android / iOS).
// On Flutter Web it throws MissingPluginException at runtime.
// We guard with kIsWeb — web callers must use the paste-text path instead.
// ══════════════════════════════════════════════════════════════════════════════
class OCRService {
  static TextRecognizer? _recognizer;

  static TextRecognizer get _rec {
    // Only instantiate on native — prevents web crash at static init time
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  /// Returns true if OCR is available on this platform.
  static bool get isSupported => !kIsWeb;

  /// Extract text from an XFile on native (Android/iOS) only.
  /// Throws [UnsupportedError] on web — callers should check [isSupported] first.
  static Future<String> extractFromXFile(XFile xfile) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'OCR (google_mlkit_text_recognition) is not supported on Flutter Web. '
          'Use the manual text-paste path instead.');
    }
    final inputImage = InputImage.fromFilePath(xfile.path);
    final result     = await _rec.processImage(inputImage);
    return result.text;
  }

  static void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TEXT PARSER SERVICE
// ══════════════════════════════════════════════════════════════════════════════
class TextParserService {
  /// Parse raw OCR text into structured rows.
  /// Expected format (flexible): "name  delivered  returned  payment"
  /// e.g.  "John 20 18 500"  or  "john  20  -  500"
  static List<ParsedRow> parse(String rawText) {
    final rows = <ParsedRow>[];
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      // Split on whitespace — collapse multiple spaces
      final tokens = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (tokens.length < 2) continue; // need at least name + one number

      // Try to find contiguous number tokens at the end
      // Name = all leading non-numeric tokens
      int firstNumIdx = -1;
      for (int i = 0; i < tokens.length; i++) {
        if (_isNumeric(tokens[i])) { firstNumIdx = i; break; }
      }

      if (firstNumIdx <= 0) continue; // no numbers or name is empty

      final name     = tokens.sublist(0, firstNumIdx).join(' ');
      final numToks  = tokens.sublist(firstNumIdx);

      final delivered = _parseInt(numToks.elementAtOrNull(0));
      final returned  = _parseInt(numToks.elementAtOrNull(1));
      final payment   = _parseDouble(numToks.elementAtOrNull(2));

      if (delivered == null && returned == null && payment == null) continue;

      rows.add(ParsedRow(
        rawName:   name,
        delivered: delivered ?? 0,
        returned:  returned  ?? 0,
        payment:   payment   ?? 0,
      ));
    }
    return rows;
  }

  static bool   _isNumeric(String s) => double.tryParse(s.replaceAll(',', '')) != null;
  static int?   _parseInt(String? s) {
    if (s == null || s == '-') return null;
    return int.tryParse(s.replaceAll(',', '').replaceAll('.', ''));
  }
  static double? _parseDouble(String? s) {
    if (s == null || s == '-') return null;
    return double.tryParse(s.replaceAll(',', ''));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CUSTOMER MATCHER SERVICE  — Levenshtein-based fuzzy matching
// ══════════════════════════════════════════════════════════════════════════════
class CustomerMatcherService {
  /// Returns similarity score 0.0–1.0 using normalised Levenshtein distance.
  static double similarity(String a, String b) {
    final s1 = a.toLowerCase().trim();
    final s2 = b.toLowerCase().trim();
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final dist = _levenshtein(s1, s2);
    final maxLen = math.max(s1.length, s2.length);
    return 1.0 - dist / maxLen;
  }

  static int _levenshtein(String s, String t) {
    final m = s.length, n = t.length;
    // Use two-row DP to save memory
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);
    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        if (s[i - 1] == t[j - 1]) {
          curr[j] = prev[j - 1];
        } else {
          curr[j] = 1 + [prev[j], curr[j - 1], prev[j - 1]].reduce(math.min);
        }
      }
      final tmp = prev; prev = curr; curr = tmp;
    }
    return prev[n];
  }

  /// Best match from customer list for a given raw name.
  static ({Customer? customer, double confidence}) bestMatch(
      String rawName, List<Customer> customers) {
    if (customers.isEmpty) return (customer: null, confidence: 0.0);

    double   bestScore = 0.0;
    Customer? bestCust;

    for (final c in customers) {
      // Also try matching against first name only
      final fullScore  = similarity(rawName, c.name);
      final firstName  = c.name.split(' ').first;
      final firstScore = similarity(rawName, firstName);
      final score      = math.max(fullScore, firstScore);

      if (score > bestScore) {
        bestScore = score;
        bestCust  = c;
      }
    }
    return (customer: bestCust, confidence: bestScore);
  }

  /// Match all parsed rows at once.
  static List<MatchedRow> matchAll(
      List<ParsedRow> rows, List<Customer> customers) {
    return rows.map((r) {
      final m = bestMatch(r.rawName, customers);
      return MatchedRow(
        parsed:     r,
        customer:   m.confidence >= 0.4 ? m.customer : null,
        confidence: m.confidence,
      );
    }).toList();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SMART ENTRY SCREEN — main widget
// ══════════════════════════════════════════════════════════════════════════════
class SmartEntryScreen extends ConsumerStatefulWidget {
  const SmartEntryScreen({super.key});
  @override
  ConsumerState<SmartEntryScreen> createState() => _SmartEntryScreenState();
}

// capture  → pick image (both platforms)
// webPaste → web only: show image preview + paste text field (no ML Kit)
// processing → native only: running ML Kit OCR
// preview  → review & edit rows
// saved    → success
enum _Phase { capture, webPaste, processing, preview, saved }

class _SmartEntryScreenState extends ConsumerState<SmartEntryScreen> {
  _Phase _phase = _Phase.capture;
  XFile?     _xfile;
  Uint8List? _imageBytes;
  String _rawText   = '';
  String _statusMsg = '';
  List<MatchedRow> _rows = [];
  bool _saving = false;

  // ── Image capture ──────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
        source: source, imageQuality: 90, maxWidth: 1920);
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    setState(() {
      _xfile      = xfile;
      _imageBytes = bytes;
    });

    if (kIsWeb) {
      // Web: ML Kit not available — show image + paste-text screen
      setState(() => _phase = _Phase.webPaste);
    } else {
      // Native: run OCR automatically
      setState(() { _phase = _Phase.processing; _statusMsg = 'Running OCR…'; });
      await _runOCR();
    }
  }

  // ── Native OCR (ML Kit) ────────────────────────────────────────────────────
  Future<void> _runOCR() async {
    try {
      setState(() => _statusMsg = 'Extracting text…');
      _rawText = await OCRService.extractFromXFile(_xfile!);
      setState(() => _statusMsg = 'Parsing rows…');
      await _parseAndMatch(_rawText);
    } catch (e) {
      setState(() {
        _statusMsg = 'OCR failed: $e';
        _phase     = _Phase.preview;
        _rows      = [];
      });
    }
  }

  // ── Parse + fuzzy-match (shared by both paths) ────────────────────────────
  Future<void> _parseAndMatch(String text) async {
    final parsed = TextParserService.parse(text);
    if (parsed.isEmpty) {
      setState(() {
        _statusMsg = 'No rows found. Check the format or add rows manually.';
        _rows      = [];
        _phase     = _Phase.preview;
      });
      return;
    }
    setState(() => _statusMsg = 'Matching customers…');
    final customers = ref.read(customersProvider).where((c) => c.isActive).toList();
    _rows = CustomerMatcherService.matchAll(parsed, customers);
    setState(() { _phase = _Phase.preview; _statusMsg = ''; });
  }

  // ── Web: user pasted text manually, now parse ─────────────────────────────
  Future<void> _onWebTextSubmit(String text) async {
    if (text.trim().isEmpty) return;
    setState(() { _rawText = text; _statusMsg = 'Parsing rows…'; });
    await _parseAndMatch(text);
  }

  // ── Save rows as transactions ──────────────────────────────────────────────
  Future<void> _save() async {
    // Validate: all rows must have a customer
    final invalid = _rows.where((r) => r.customer == null).length;
    if (invalid > 0) {
      showToast(context, '⚠ $invalid row(s) have no customer selected', error: true);
      return;
    }

    setState(() => _saving = true);
    final notifier = ref.read(transactionsProvider.notifier);
    final today    = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now      = DateTime.now().toIso8601String();
    final session  = ref.read(sessionUserProvider);

    for (final row in _rows) {
      final tx = JarTransaction(
        id:              DateTime.now().microsecondsSinceEpoch.toString(),
        customerId:      row.customer!.id,
        customerName:    row.customer!.name,
        date:            today,
        createdAt:       now,
        billedAmount:    0,
        amountCollected: row.payment,
        coolDelivered:   row.delivered,
        petDelivered:    0,
        coolReturned:    row.returned,
        petReturned:     0,
        paymentMode:     'cash',
        note:            'Imported from handwritten sheet',
        createdBy:       session?.name ?? 'Admin',
        deliveryType:    'daily',
      );
      await notifier.add(tx);
      // Small delay to ensure unique IDs
      await Future.delayed(const Duration(milliseconds: 2));
    }

    setState(() { _saving = false; _phase = _Phase.saved; });
  }

  void _addEmptyRow() {
    setState(() => _rows.add(MatchedRow(
      parsed:     const ParsedRow(rawName: '', delivered: 0, returned: 0, payment: 0),
      customer:   null,
      confidence: 0,
    )));
  }

  void _reset() => setState(() {
    _phase = _Phase.capture; _xfile = null; _imageBytes = null;
    _rawText = ''; _rows = []; _statusMsg = '';
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: switch (_phase) {
        _Phase.capture    => _CaptureView(isDark: isDark, primary: primary,
                                onPick: _pickImage),
        _Phase.webPaste   => _WebPasteView(
                                isDark: isDark, primary: primary,
                                imageBytes: _imageBytes,
                                onSubmit: _onWebTextSubmit,
                                onBack: _reset),
        _Phase.processing => _ProcessingView(isDark: isDark, message: _statusMsg),
        _Phase.preview    => _PreviewView(
                                isDark: isDark, primary: primary,
                                imageBytes: _imageBytes, rawText: _rawText,
                                rows: _rows, statusMsg: _statusMsg,
                                saving: _saving,
                                onAddRow: _addEmptyRow,
                                onSave: _save,
                                onReset: _reset,
                                onRowChanged: () => setState(() {})),
        _Phase.saved      => _SavedView(
                                isDark: isDark, primary: primary,
                                count: _rows.length,
                                onDone: _reset),
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 1 — CAPTURE VIEW
// ══════════════════════════════════════════════════════════════════════════════
class _CaptureView extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final Future<void> Function(ImageSource) onPick;
  const _CaptureView(
      {required this.isDark, required this.primary, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        // Hero icon
        Center(child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [primary.withValues(alpha: 0.15), primary.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
          ),
          child: Icon(Icons.document_scanner_rounded, size: 48, color: primary),
        )),
        const SizedBox(height: 20),
        Center(child: Text('Handwritten Sheet Scanner',
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87))),
        const SizedBox(height: 6),
        Center(child: Text(
            'Capture or upload your delivery sheet.\nWe\'ll extract and match the data automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.5))),

        const SizedBox(height: 32),

        // Camera button
        _BigBtn(
          icon: Icons.camera_alt_rounded,
          label: 'Take Photo',
          sublabel: 'Use camera to capture sheet',
          color: primary,
          isDark: isDark,
          onTap: () => onPick(ImageSource.camera),
        ),
        const SizedBox(height: 14),

        // Gallery button
        _BigBtn(
          icon: Icons.photo_library_rounded,
          label: 'Choose from Gallery',
          sublabel: 'Upload an existing photo',
          color: AppColors.successColor(isDark),
          isDark: isDark,
          onTap: () => onPick(ImageSource.gallery),
        ),

        const SizedBox(height: 32),

        // Tips card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark ? AppColors.separatorDark : const Color(0xFFBDD5F8)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.lightbulb_rounded, size: 16, color: primary),
              const SizedBox(width: 6),
              Expanded(child: Text('Tips for best results',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700, color: primary),
                  overflow: TextOverflow.ellipsis, maxLines: 1)),
            ]),
            const SizedBox(height: 10),
            ...const [
              'Write clearly — one entry per line',
              'Format: Name  Delivered  Returned  Payment',
              'Use numbers only in the right columns',
              'Good lighting and flat surface',
            ].map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_circle_rounded,
                    size: 13, color: AppColors.successColor(false)),
                const SizedBox(width: 7),
                Expanded(child: Text(tip,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.inkMuted, height: 1.4))),
              ]),
            )),
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: primary.withValues(alpha: 0.15)),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.web_rounded, size: 13, color: primary),
                const SizedBox(width: 7),
                Expanded(child: Text(
                  'On web: after uploading, you\'ll paste the text extracted '
                  'by Google Lens or any OCR tool.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: primary.withValues(alpha: 0.8),
                      height: 1.4),
                )),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _BigBtn extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _BigBtn({required this.icon, required this.label, required this.sublabel,
      required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 26, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(sublabel, style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.inkMuted)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 2 — PROCESSING VIEW
// ══════════════════════════════════════════════════════════════════════════════
class _ProcessingView extends StatelessWidget {
  final bool isDark;
  final String message;
  const _ProcessingView({required this.isDark, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 60, height: 60,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: 24),
      Text('Scanning Sheet…',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87)),
      const SizedBox(height: 8),
      Text(message,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 2b — WEB PASTE VIEW (web only — ML Kit not available on web)
// Shows the uploaded image + a text area for the user to paste OCR text.
// They can use Google Lens / phone camera OCR / any external tool and paste
// the result. The same parser & fuzzy matcher then runs on the pasted text.
// ══════════════════════════════════════════════════════════════════════════════
class _WebPasteView extends StatefulWidget {
  final bool isDark;
  final Color primary;
  final Uint8List? imageBytes;
  final Future<void> Function(String) onSubmit;
  final VoidCallback onBack;
  const _WebPasteView({
    required this.isDark, required this.primary,
    required this.imageBytes, required this.onSubmit, required this.onBack,
  });
  @override
  State<_WebPasteView> createState() => _WebPasteViewState();
}

class _WebPasteViewState extends State<_WebPasteView> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark;
    final primary = widget.primary;

    return Column(children: [
      // ── Header ──────────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          border: Border(bottom: BorderSide(
              color: isDark ? AppColors.separatorDark : AppColors.separator)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark ? AppColors.separatorDark : AppColors.separator),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Paste Extracted Text',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            Text('OCR not available on web — paste text below',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
          ])),
        ]),
      ),

      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Info banner ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.20)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: primary),
                const SizedBox(width: 8),
                Text('How to extract text on web',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, color: primary)),
              ]),
              const SizedBox(height: 10),
              ...const [
                ('1', 'Open Google Lens (lens.google.com) or Google Photos'),
                ('2', 'Upload the same image and copy the extracted text'),
                ('3', 'Paste it in the box below — one row per line'),
                ('4', 'Format: Name  Delivered  Returned  Payment'),
              ].map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 18, height: 18,
                    margin: const EdgeInsets.only(right: 8, top: 1),
                    decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Center(child: Text(s.$1,
                        style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w800, color: primary))),
                  ),
                  Expanded(child: Text(s.$2,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.inkMuted, height: 1.4))),
                ]),
              )),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Image preview (so user knows which image to OCR) ───────────────
          if (widget.imageBytes != null) ...[
            Text('Your image',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                widget.imageBytes!,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.inkMuted.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.broken_image_rounded,
                      color: AppColors.inkMuted, size: 40)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Paste text area ────────────────────────────────────────────────
          Text('Paste extracted text here',
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface2Dark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? AppColors.separatorDark : AppColors.separator),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 13, height: 1.6,
                  color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText:
                    'John  20  18  500\nRamesh  10  8  300\nSuresh  15  12  450',
                hintStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 12, color: AppColors.inkMuted.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text('One entry per line · Format: Name  Delivered  Returned  Payment',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),

          const SizedBox(height: 20),

          // ── Parse button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading || _ctrl.text.trim().isEmpty
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      await widget.onSubmit(_ctrl.text);
                      if (mounted) setState(() => _loading = false);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.auto_fix_high_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Parse & Match Customers',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),

          // ── Or skip image and just type ────────────────────────────────────
          const SizedBox(height: 12),
          Center(child: TextButton.icon(
            onPressed: () async {
              if (_ctrl.text.trim().isNotEmpty) {
                setState(() => _loading = true);
                await widget.onSubmit(_ctrl.text);
                if (mounted) setState(() => _loading = false);
              }
            },
            icon: const Icon(Icons.keyboard_rounded, size: 15),
            label: Text('Or type entries directly above',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
            style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
          )),
        ]),
      )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 3 — PREVIEW VIEW
// ══════════════════════════════════════════════════════════════════════════════
class _PreviewView extends ConsumerWidget {
  final bool isDark;
  final Color primary;
  final Uint8List? imageBytes; // web-safe bytes instead of File
  final String rawText, statusMsg;
  final List<MatchedRow> rows;
  final bool saving;
  final VoidCallback onAddRow, onSave, onReset, onRowChanged;

  const _PreviewView({
    required this.isDark, required this.primary,
    required this.imageBytes, required this.rawText, required this.statusMsg,
    required this.rows, required this.saving,
    required this.onAddRow, required this.onSave,
    required this.onReset, required this.onRowChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider)
        .where((c) => c.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final highCount = rows.where((r) => r.level == MatchConfidence.high).length;
    final lowCount  = rows.where((r) => r.level == MatchConfidence.low).length;
    final noneCount = rows.where((r) => r.level == MatchConfidence.none).length;

    return Column(children: [
      // ── Top bar ──────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          border: Border(bottom: BorderSide(
              color: isDark ? AppColors.separatorDark : AppColors.separator)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: onReset,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark ? AppColors.separatorDark : AppColors.separator),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Review & Edit',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            Text('${rows.length} rows extracted',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
          ])),
          // Confidence legend pills
          Row(children: [
            _ConfPill('$highCount', AppColors.successColor(isDark)),
            const SizedBox(width: 5),
            _ConfPill('$lowCount', AppColors.warningColor(isDark)),
            const SizedBox(width: 5),
            _ConfPill('$noneCount', AppColors.dangerColor(isDark)),
          ]),
        ]),
      ),

      // ── Image thumbnail + raw text toggle ────────────────────────────────
      if (imageBytes != null)
        _ImageThumb(imageBytes: imageBytes!, isDark: isDark, rawText: rawText),

      // ── Status message ───────────────────────────────────────────────────
      if (statusMsg.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.warningColor(isDark).withValues(alpha: 0.10),
          child: Text(statusMsg,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.warningColor(isDark))),
        ),

      // ── Confidence legend ─────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(children: [
          _LegendDot(AppColors.successColor(isDark), 'High confidence'),
          const SizedBox(width: 14),
          _LegendDot(AppColors.warningColor(isDark), 'Low confidence'),
          const SizedBox(width: 14),
          _LegendDot(AppColors.dangerColor(isDark),  'No match'),
        ]),
      ),

      // ── Row list ──────────────────────────────────────────────────────────
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: rows.length,
        itemBuilder: (ctx, i) => _RowCard(
          key: ValueKey(i),
          row: rows[i],
          index: i,
          customers: customers,
          isDark: isDark,
          primary: primary,
          onDelete: () {
            rows.removeAt(i);
            onRowChanged();
          },
          onChanged: onRowChanged,
        ),
      )),

      // ── Bottom action bar ─────────────────────────────────────────────────
      Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16,
            12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Row(children: [
          // Add row
          GestureDetector(
            onTap: onAddRow,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Icon(Icons.add_rounded, size: 18, color: primary),
                const SizedBox(width: 6),
                Text('Add Row',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, color: primary)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          // Save
          Expanded(child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: saving || rows.isEmpty ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successColor(isDark),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.successColor(isDark).withValues(alpha: 0.40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.save_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Save ${rows.length} Transactions',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
            ),
          )),
        ]),
      ),
    ]);
  }
}

// ── Row card — editable ───────────────────────────────────────────────────────
class _RowCard extends ConsumerStatefulWidget {
  final MatchedRow row;
  final int index;
  final List<Customer> customers;
  final bool isDark;
  final Color primary;
  final VoidCallback onDelete, onChanged;

  const _RowCard({
    super.key,
    required this.row, required this.index,
    required this.customers, required this.isDark,
    required this.primary, required this.onDelete,
    required this.onChanged,
  });
  @override
  ConsumerState<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends ConsumerState<_RowCard> {
  late final TextEditingController _delCtrl;
  late final TextEditingController _retCtrl;
  late final TextEditingController _payCtrl;
  bool _showCustSearch = false;
  String _custSearch = '';

  @override
  void initState() {
    super.initState();
    _delCtrl = TextEditingController(text: widget.row.delivered.toString());
    _retCtrl = TextEditingController(text: widget.row.returned.toString());
    _payCtrl = TextEditingController(text: widget.row.payment.toInt().toString());
  }

  @override
  void dispose() {
    _delCtrl.dispose(); _retCtrl.dispose(); _payCtrl.dispose();
    super.dispose();
  }

  Color get _borderColor {
    switch (widget.row.level) {
      case MatchConfidence.high: return AppColors.successColor(widget.isDark);
      case MatchConfidence.low:  return AppColors.warningColor(widget.isDark);
      case MatchConfidence.none: return AppColors.dangerColor(widget.isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark;
    final primary = widget.primary;
    final row     = widget.row;
    final bc      = _borderColor;

    final filteredCusts = _custSearch.isEmpty
        ? widget.customers
        : widget.customers.where((c) =>
            c.name.toLowerCase().contains(_custSearch.toLowerCase()) ||
            c.phone.contains(_custSearch)).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bc.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Card header: row # + raw name + confidence + delete ─────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: bc.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13), topRight: Radius.circular(13)),
          ),
          child: Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                  color: bc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: Center(child: Text('${widget.index + 1}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, fontWeight: FontWeight.w700, color: bc))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
              row.parsed.rawName.isEmpty ? 'New Row' : '"${row.parsed.rawName}"',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.inkMuted,
                  fontStyle: FontStyle.italic),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
            // Confidence badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                switch (row.level) {
                  MatchConfidence.high => '${(row.confidence * 100).toInt()}% ✓',
                  MatchConfidence.low  => '${(row.confidence * 100).toInt()}% ~',
                  MatchConfidence.none => 'No match',
                },
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700, color: bc),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onDelete,
              child: Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.inkMuted.withValues(alpha: 0.6)),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Customer selector ──────────────────────────────────────────
            GestureDetector(
              onTap: () => setState(() {
                _showCustSearch = !_showCustSearch;
                _custSearch = '';
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: row.customer != null
                          ? bc.withValues(alpha: 0.40)
                          : AppColors.dangerColor(isDark).withValues(alpha: 0.40)),
                ),
                child: Row(children: [
                  if (row.customer != null)
                    CustomerAvatar(initials: row.customer!.initials, size: 26)
                  else
                    Icon(Icons.person_search_rounded,
                        size: 20, color: AppColors.dangerColor(isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    row.customer?.name ?? '⚠ Select customer',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: row.customer != null
                            ? (isDark ? Colors.white : Colors.black87)
                            : AppColors.dangerColor(isDark)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                  Icon(
                    _showCustSearch
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AppColors.inkMuted,
                  ),
                ]),
              ),
            ),

            // Customer search dropdown
            if (_showCustSearch) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark ? AppColors.separatorDark : AppColors.separator),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(children: [
                  // Search input
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setState(() => _custSearch = v),
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search customer…',
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 16, color: AppColors.inkMuted),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.surface2Dark : AppColors.surface2,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: filteredCusts.length,
                      separatorBuilder: (_, __) => Divider(height: 1,
                          color: isDark
                              ? AppColors.separatorDark : AppColors.separator),
                      itemBuilder: (ctx, i) {
                        final cu = filteredCusts[i];
                        final isSel = cu.id == row.customer?.id;
                        return InkWell(
                          onTap: () => setState(() {
                            row.customer   = cu;
                            row.confidence = 1.0;
                            _showCustSearch = false;
                            widget.onChanged();
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            child: Row(children: [
                              CustomerAvatar(initials: cu.initials, size: 28),
                              const SizedBox(width: 10),
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(cu.name,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: isSel
                                            ? FontWeight.w700 : FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (cu.phone.isNotEmpty)
                                  Text(cu.phone,
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: AppColors.inkMuted)),
                              ])),
                              if (isSel)
                                Icon(Icons.check_circle_rounded,
                                    size: 16, color: primary),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 10),

            // ── Number fields: Delivered | Returned | Payment ──────────────
            Row(children: [
              Expanded(child: _NumField(
                label: 'Delivered', ctrl: _delCtrl,
                color: AppColors.coolColor(isDark), isDark: isDark,
                onChanged: (v) {
                  row.delivered = int.tryParse(v) ?? 0;
                  widget.onChanged();
                },
              )),
              const SizedBox(width: 8),
              Expanded(child: _NumField(
                label: 'Returned', ctrl: _retCtrl,
                color: AppColors.petColor(isDark), isDark: isDark,
                onChanged: (v) {
                  row.returned = int.tryParse(v) ?? 0;
                  widget.onChanged();
                },
              )),
              const SizedBox(width: 8),
              Expanded(child: _NumField(
                label: 'Payment ₹', ctrl: _payCtrl,
                color: AppColors.successColor(isDark), isDark: isDark,
                onChanged: (v) {
                  row.payment = double.tryParse(v) ?? 0;
                  widget.onChanged();
                },
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Number field ─────────────────────────────────────────────────────────────
class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final Color color;
  final bool isDark;
  final ValueChanged<String> onChanged;
  const _NumField({required this.label, required this.ctrl,
      required this.color, required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    const SizedBox(height: 4),
    TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      style: GoogleFonts.jetBrainsMono(
          fontSize: 16, fontWeight: FontWeight.w700, color: color),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: color.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: color.withValues(alpha: 0.25))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: color.withValues(alpha: 0.25))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: color, width: 1.5)),
      ),
    ),
  ]);
}

// ── Image thumbnail with raw text expandable ──────────────────────────────────
// ── Image thumbnail with raw text expandable ──────────────────────────────────
// Uses Image.memory (Uint8List) so it works on Flutter Web — Image.file
// throws "!kIsWeb" on the web platform.
class _ImageThumb extends StatefulWidget {
  final Uint8List imageBytes;
  final bool isDark;
  final String rawText;
  const _ImageThumb(
      {required this.imageBytes, required this.isDark, required this.rawText});
  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  bool _showText = false;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: widget.isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: widget.isDark ? AppColors.separatorDark : AppColors.separator),
    ),
    child: Column(children: [
      Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          // Image.memory works on all platforms including Flutter Web
          child: Image.memory(
            widget.imageBytes,
            width: 64, height: 64, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.inkMuted.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.broken_image_rounded,
                  color: AppColors.inkMuted, size: 28),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Captured image',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
          Text('Tap ▼ to view extracted text',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
        ])),
        GestureDetector(
          onTap: () => setState(() => _showText = !_showText),
          child: Icon(
            _showText ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: AppColors.inkMuted,
          ),
        ),
      ]),
      if (_showText && widget.rawText.isNotEmpty) ...[
        const SizedBox(height: 8),
        Divider(height: 1,
            color: widget.isDark ? AppColors.separatorDark : AppColors.separator),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 160),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Text(widget.rawText,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 11, color: AppColors.inkMuted, height: 1.5)),
          ),
        ),
      ],
    ]),
  );
}

// ── Small helper widgets ──────────────────────────────────────────────────────
class _ConfPill extends StatelessWidget {
  final String label;
  final Color color;
  const _ConfPill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label,
        style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 9, height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 4 — SAVED VIEW
// ══════════════════════════════════════════════════════════════════════════════
class _SavedView extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final int count;
  final VoidCallback onDone;
  const _SavedView({required this.isDark, required this.primary,
      required this.count, required this.onDone});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: AppColors.successColor(isDark).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, size: 50,
              color: AppColors.successColor(isDark)),
        ),
        const SizedBox(height: 24),
        Text('Saved Successfully!',
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text('$count transactions have been recorded.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkMuted)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onDone,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: Text('Scan Another Sheet',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    ),
  );
}
