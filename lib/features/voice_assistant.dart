// ════════════════════════════════════════════════════════════════════════════
// voice_assistant.dart  — Hindi/English bilingual transaction assistant
//
// FIX: Opens as a full-screen page (Navigator.push) — NOT a bottom sheet.
//      Bottom sheets don't bound height, causing Expanded→ListView hang.
//
// FLOW:
//   1. selectTxType   → Delivery / Event / Payment / Expense
//   2. selectCustomer → fuzzy match by name / phone / area
//   3. setCoolJars    → cool jars delivered  (can be 0)
//   4. setPetJars     → pet jars delivered   (can be 0)
//   5. setCoolReturn  → cool jars returned   (can be 0)
//   6. setPetReturn   → pet jars returned    (can be 0)
//   7. setPayment     → amount received      (can be 0)
//   8. confirm        → हाँ/yes saves, ना/no resets
//
// For Payment type:  skips steps 3-6, only asks amount
// For Expense type:  skips customer + jars, asks category + amount
// ════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';

const _uuid = Uuid();

// ══════════════════════════════════════════════════════════════════════════════
// TRANSACTION TYPE
// ══════════════════════════════════════════════════════════════════════════════
enum VoiceTxType { delivery, event, payment, expense }

// ══════════════════════════════════════════════════════════════════════════════
// NLU ENGINE  — English + Hindi/Hinglish input (en_IN locale)
// All Hindi/Hinglish spoken words are normalised to English FIRST
// via HindiTranslator, then processed by NluEngine.
// ══════════════════════════════════════════════════════════════════════════════

// ── Hindi → English normaliser ────────────────────────────────────────────────
// Runs on EVERY input before NLU processing.
// Handles common Hinglish speech patterns that en_IN STT outputs.
class HindiTranslator {

  // ── Number words (Hindi romanised → digit string) ────────────────────────────
  static const _numbers = <String, String>{
    // Units
    'ek': '1', 'do': '2', 'teen': '3', 'char': '4', 'chaar': '4',
    'paanch': '5', 'panch': '5', 'chhe': '6', 'che': '6', 'chheh': '6',
    'saat': '7', 'sat': '7', 'aath': '8', 'aat': '8',
    'nau': '9', 'das': '10',
    // Teens
    'gyarah': '11', 'barah': '12', 'terah': '13', 'chaudah': '14',
    'pandrah': '15', 'solah': '16', 'satrah': '17', 'atharah': '18',
    'unnis': '19', 'bees': '20', 'bis': '20',
    // Tens
    'tees': '30', 'chalees': '40', 'pachas': '50',
    'saath': '60', 'sattar': '70', 'assi': '80', 'nabbe': '90',
    // Hundreds / thousands
    'sau': 'hundred', 'hazaar': 'thousand', 'lakh': 'hundred thousand',
  };

  // ── Action / intent words ─────────────────────────────────────────────────────
  static const _actions = <String, String>{
    // Delivery
    'diya': 'delivered', 'diye': 'delivered', 'de diya': 'delivered',
    'bheja': 'delivered', 'bheje': 'delivered', 'dena': 'delivery',
    'pohncha': 'delivered', 'pohnchaaya': 'delivered',
    // Return
    'wapas': 'returned', 'vapas': 'returned', 'wapas aaya': 'returned',
    'wapas aaye': 'returned', 'liya': 'returned', 'liye': 'returned',
    'khaali': 'empty returned', 'khali': 'empty returned',
    'laaya': 'returned', 'laaye': 'returned',
    // Payment
    'paisa': 'payment', 'paise': 'payment', 'rupaya': 'rupees',
    'rupaye': 'rupees', 'rupaiye': 'rupees', 'rupaiya': 'rupees',
    'diye paise': 'payment', 'paise diye': 'payment',
    'vasool': 'collected', 'vasool kiya': 'collected',
    'liya paise': 'payment collected', 'paise liye': 'payment collected',
    'nahi diya': 'zero payment', 'nahi diye': 'zero payment',
    'kuch nahi': 'zero', 'kuch nahin': 'zero',
    'poora': 'full', 'pura': 'full', 'aadha': 'half', 'adha': 'half',
    // Transaction type
    'delivery karna': 'delivery', 'jar dena': 'delivery',
    'event karna': 'event', 'payment lena': 'payment',
    'kharcha': 'expense', 'kharche': 'expense', 'kharch': 'expense',
    // Confirm / cancel
    'haan': 'yes', 'han': 'yes', 'ha ': 'yes ', 'theek': 'yes',
    'theek hai': 'yes', 'sahi': 'yes', 'bilkul': 'yes', 'kar do': 'yes',
    'save karo': 'yes', 'save kar': 'yes', 'ho gaya': 'yes',
    'nahi': 'no', 'nahin': 'no', 'mat karo': 'no', 'rok do': 'cancel',
    'band karo': 'cancel', 'galat': 'no', 'wapas jao': 'back',
    'piche': 'back', 'reset karo': 'reset',
    // Jar types
    'thanda': 'cool', 'thandha': 'cool', 'thand': 'cool',
    'botal': 'bottle', 'bottal': 'bottle', 'galon': 'jar', 'gallon': 'jar',
    // Customer reference
    'ko': 'for', 'ke liye': 'for', 'wala': '', 'wale': '', 'waale': '',
    'ka': '', 'ki': '', 'ke': '',
    // Directions
    'kitne': 'how many', 'kitna': 'how much',
  };

  // ── Devanagari script → romanised map (if STT ever outputs Hindi script) ───────
  // Chrome en_IN usually outputs romanised but just in case
  static const _devanagari = <String, String>{
    'एक': '1', 'दो': '2', 'तीन': '3', 'चार': '4', 'पाँच': '5',
    'छह': '6', 'सात': '7', 'आठ': '8', 'नौ': '9', 'दस': '10',
    'बीस': '20', 'सौ': 'hundred', 'हज़ार': 'thousand',
    'हाँ': 'yes', 'हां': 'yes', 'ना': 'no', 'नहीं': 'no',
    'ठीक': 'yes', 'वापस': 'back', 'खाली': 'empty',
    'पैसा': 'payment', 'पैसे': 'payment', 'रुपये': 'rupees',
    'डिलीवरी': 'delivery', 'इवेंट': 'event',
  };

  /// Translate any Hinglish / Hindi input to normalised English.
  /// Returns the translated string — NLU processes the result.
  static String translate(String raw) {
    var text = raw.trim().toLowerCase();

    // 1. Devanagari script replacement (whole word)
    for (final e in _devanagari.entries) {
      text = text.replaceAll(e.key, e.value);
    }

    // 2. Multi-word phrases first (longer matches take priority)
    final sortedActions = _actions.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in sortedActions) {
      text = text.replaceAll(e.key, e.value);
    }

    // 3. Single number words (whole word boundary)
    for (final e in _numbers.entries) {
      text = text.replaceAllMapped(
        RegExp('\\b${RegExp.escape(e.key)}\\b'),
        (_) => e.value,
      );
    }

    // 4. Clean up double spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
class NluEngine {
  // English + Indian number words
  static const _numWords = <String, int>{
    'one': 1,   'two': 2,    'three': 3,  'four': 4,   'five': 5,
    'six': 6,   'seven': 7,  'eight': 8,  'nine': 9,   'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19, 'twenty': 20,
    // Hinglish fallbacks (not caught by translator)
    'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'chaar': 4,
    'panch': 5, 'paanch': 5, 'chhe': 6, 'che': 6,
    'saat': 7, 'sat': 7, 'aath': 8, 'aat': 8,
    'nau': 9, 'das': 10, 'barah': 12, 'bees': 20, 'bis': 20,
  };

  static const _confirmWords = {
    'yes', 'ok', 'okay', 'done', 'correct', 'right', 'save',
    'confirm', 'yep', 'yup', 'sure', 'fine', 'good',
    // Hinglish (kept as fallback)
    'ha', 'han', 'haan', 'theek', 'sahi', 'bilkul',
  };

  static const _cancelWords = {
    'no', 'cancel', 'back', 'stop', 'wrong', 'reset', 'redo',
    // Hinglish fallback
    'nahi', 'galat', 'wapas', 'na',
  };

  // ── Parse integer (0 allowed) ──────────────────────────────────────────────
  static int? parseNumber(String raw) {
    final lower = raw.toLowerCase().trim();
    if (_isZeroWord(lower)) return 0;
    final m = RegExp(r'\b(\d{1,3})\b').firstMatch(lower);
    if (m != null) return int.tryParse(m.group(1)!);
    for (final e in _numWords.entries) {
      if (lower == e.key || lower.contains(e.key)) return e.value;
    }
    return null;
  }

  static bool _isZeroWord(String s) =>
      {'zero', '0', 'nothing', 'nil', 'nill', 'none', 'no', 'na', 'nahi'}
          .any((w) => s == w || s.contains(w));

  // ── Parse payment amount ───────────────────────────────────────────────────
  // Returns -1 for "half", -2 for "full"/"all"
  static double? parseAmount(String raw) {
    final lower = raw.toLowerCase().trim();
    if (_isZeroWord(lower)) { return 0; }
    if (lower.contains('half') || lower.contains('aadha')) { return -1; }
    if (lower.contains('full') || lower.contains('all') ||
        lower.contains('poora') || lower.contains('complete')) { return -2; }

    // "five hundred" = 500, "two thousand" = 2000
    final muls = <String, double>{
      'hundred': 100, 'sau': 100,
      'thousand': 1000, 'hazaar': 1000,
    };
    double? base;
    double? mul;
    for (final e in _numWords.entries) {
      if (lower.contains(e.key)) { base = e.value.toDouble(); break; }
    }
    for (final e in muls.entries) {
      if (lower.contains(e.key)) { mul = e.value; break; }
    }
    if (base != null && mul != null) return base * mul;
    if (mul  != null) return mul;

    final m = RegExp(r'\b(\d{1,6})\b').firstMatch(lower);
    if (m != null) return double.tryParse(m.group(1)!);
    return null;
  }

  // ── Confirm / Cancel ───────────────────────────────────────────────────────
  static bool isConfirm(String raw) {
    final lower = raw.toLowerCase().trim();
    return _confirmWords.any((w) => lower == w || lower.startsWith('$w '));
  }

  static bool isCancel(String raw) {
    final lower = raw.toLowerCase().trim();
    return _cancelWords.any((w) => lower == w || lower.contains(w));
  }

  // ── Transaction type detection ─────────────────────────────────────────────
  static VoiceTxType? detectTxType(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower == '1' || lower.contains('deliver') || lower.contains('jar') ||
        lower.contains('water') || lower.contains('supply') ||
        lower.contains('bottle') || lower.contains('galon'))
      { return VoiceTxType.delivery; }
    if (lower == '2' || lower.contains('event') ||
        lower.contains('function') || lower.contains('party') ||
        lower.contains('bulk') || lower.contains('occasion'))
      { return VoiceTxType.event; }
    if (lower == '3' || lower.contains('payment') || lower.contains('paid') ||
        lower.contains('collect') || lower.contains('money') ||
        lower.contains('cash') || lower.contains('amount') ||
        lower.contains('rupee') || lower.contains('vasool'))
      { return VoiceTxType.payment; }
    if (lower == '4' || lower.contains('expense') || lower.contains('spend') ||
        lower.contains('cost') || lower.contains('kharcha') ||
        lower.contains('kharche') || lower.contains('petrol') ||
        lower.contains('salary'))
      { return VoiceTxType.expense; }
    return null;
  }

  // ── Fuzzy customer matching ────────────────────────────────────────────────
  static double similarity(String a, String b) {
    final s1 = a.toLowerCase().trim();
    final s2 = b.toLowerCase().trim();
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    return 1.0 - _lev(s1, s2) / math.max(s1.length, s2.length);
  }

  static int _lev(String s, String t) {
    var prev = List<int>.generate(t.length + 1, (i) => i);
    var curr = List<int>.filled(t.length + 1, 0);
    for (int i = 1; i <= s.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= t.length; j++) {
        curr[j] = s[i-1] == t[j-1]
            ? prev[j-1]
            : 1 + [prev[j], curr[j-1], prev[j-1]].reduce(math.min);
      }
      final tmp = prev; prev = curr; curr = tmp;
    }
    return prev[t.length];
  }

  static List<({Customer customer, double score})> findCustomers(
      String query, List<Customer> all) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    return all.map((c) {
      double score = similarity(q, c.name.toLowerCase());
      if (c.phone.contains(q)) score = math.max(score, 0.95);
      if (c.area.toLowerCase().contains(q)) score = math.max(score, 0.70);
      score = math.max(score,
          similarity(q, c.name.split(' ').first.toLowerCase()));
      return (customer: c, score: score);
    }).where((r) => r.score >= 0.35).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ASSISTANT STEP
// ══════════════════════════════════════════════════════════════════════════════
enum AssistantStep {
  selectTxType,
  selectCustomer,
  setCoolJars,
  setPetJars,
  setCoolReturn,
  setPetReturn,
  setPayment,
  setExpenseCategory,
  setExpenseAmount,
  confirm,
}

// ══════════════════════════════════════════════════════════════════════════════
// ASSISTANT STATE
// ══════════════════════════════════════════════════════════════════════════════
class _AS {
  final AssistantStep step;
  final VoiceTxType txType;
  final Customer? customer;
  final int coolDelivered, petDelivered, coolReturned, petReturned;
  final double payment;
  final String expenseCategory;
  final List<_Msg> messages;

  const _AS({
    this.step = AssistantStep.selectTxType,
    this.txType = VoiceTxType.delivery,
    this.customer,
    this.coolDelivered = 0, this.petDelivered  = 0,
    this.coolReturned  = 0, this.petReturned   = 0,
    this.payment = 0,
    this.expenseCategory = '',
    this.messages = const [],
  });

  _AS copyWith({
    AssistantStep? step, VoiceTxType? txType, Customer? customer,
    int? coolDelivered, int? petDelivered,
    int? coolReturned,  int? petReturned,
    double? payment, String? expenseCategory,
    List<_Msg>? messages,
  }) => _AS(
    step:            step            ?? this.step,
    txType:          txType          ?? this.txType,
    customer:        customer        ?? this.customer,
    coolDelivered:   coolDelivered   ?? this.coolDelivered,
    petDelivered:    petDelivered    ?? this.petDelivered,
    coolReturned:    coolReturned    ?? this.coolReturned,
    petReturned:     petReturned     ?? this.petReturned,
    payment:         payment         ?? this.payment,
    expenseCategory: expenseCategory ?? this.expenseCategory,
    messages:        messages        ?? this.messages,
  );
}

class _Msg {
  final String text;
  final bool isUser;
  // Non-null when this message contains customer suggestion cards
  final List<({Customer customer, double score})>? suggestions;
  const _Msg(this.text, {this.isUser = false, this.suggestions});
}

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY POINT — Navigator.push to full-screen (fixes bottom sheet hang)
// ══════════════════════════════════════════════════════════════════════════════
void openVoiceAssistant(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => const VoiceAssistantScreen(),
    fullscreenDialog: true,
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
// VOICE ASSISTANT SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class VoiceAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAssistantScreen({super.key});
  @override
  ConsumerState<VoiceAssistantScreen> createState() =>
      _VoiceAssistantState();
}

class _VoiceAssistantState extends ConsumerState<VoiceAssistantScreen> {
  _AS _s = const _AS();
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<({Customer customer, double score})> _suggestions = [];
  bool _saving = false;

  // ── Speech-to-text ───────────────────────────────────────────────────────────
  final _speech      = stt.SpeechToText();
  bool  _sttAvail    = false;   // whether mic permission granted & STT ready
  bool  _listening   = false;   // actively recording
  String _liveText   = '';      // live transcript shown in text field

  AppSettings get _settings => ref.read(settingsProvider);
  double get _coolPrice =>
      _s.customer?.coolPriceOverride ?? _settings.coolPrice;
  double get _petPrice =>
      _s.customer?.petPriceOverride  ?? _settings.petPrice;
  double get _billed =>
      (_s.coolDelivered * _coolPrice) + (_s.petDelivered * _petPrice);

  // ── Message helpers ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initStt();
    _bot('🎙 Hello! What do you want to do?\n\n'
        '1️⃣  Delivery  (Jar delivery)\n'
        '2️⃣  Event\n'
        '3️⃣  Payment  (Collect money)\n'
        '4️⃣  Expense  (Record expense)\n\n'
        'Tap the mic 🎙 to speak, or type below.');
  }

  Future<void> _initStt() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        // Only update UI state — do NOT auto-submit here.
        // Chrome fires 'done' even during normal pauses between words.
        // Submission is handled ONLY by the user tapping "Done" or
        // by a confirmed final result after the full utterance.
        if (status == 'notListening' && mounted && _listening) {
          setState(() => _listening = false);
        }
      },
      onError: (error) {
        // Don't submit on error — just reset mic state silently
        if (mounted) setState(() => _listening = false);
      },
    );
    if (mounted) setState(() => _sttAvail = available);
  }

  @override
  void dispose() {
    _speech.stop();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _bot(String text) {
    setState(() {
      _s = _s.copyWith(messages: [..._s.messages, _Msg(text)]);
      _suggestions = [];
    });
    _scrollToBottom();
  }

  void _user(String text) {
    setState(() =>
        _s = _s.copyWith(messages: [..._s.messages, _Msg(text, isUser: true)]));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Mic toggle (quick tap) ────────────────────────────────────────────────────
  Future<void> _toggleMic() async {
    if (!_sttAvail) {
      await _initStt();
      if (!_sttAvail) {
        _bot('❌ Microphone permission denied.\n'
            'Allow microphone access in browser settings and try again.');
        return;
      }
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      _submitLiveText();
    } else {
      await _startListening();
    }
  }

  // ── Start listening (shared by tap and hold) ──────────────────────────────────
  Future<void> _startListening() async {
    if (!_sttAvail) await _initStt();
    if (!_sttAvail) return;
    setState(() { _listening = true; _liveText = ''; _ctrl.text = ''; });
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _liveText  = result.recognizedWords;
          _ctrl.text = result.recognizedWords;
          _ctrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _ctrl.text.length));
        });
      },
      listenFor:   const Duration(seconds: 30),
      pauseFor:    const Duration(seconds: 4),
      localeId:    'en_IN',
      listenOptions: stt.SpeechListenOptions(
        cancelOnError:  false,
        partialResults: true,
      ),
    );
  }

  // ── Submit whatever is currently in the live text / text field ───────────────
  void _submitLiveText() {
    final text = _liveText.trim().isNotEmpty
        ? _liveText.trim()
        : _ctrl.text.trim();
    _liveText = '';
    _ctrl.clear();
    if (text.isNotEmpty) _onSubmit(text);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INPUT DISPATCH
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _onSubmit(String raw) async {
    if (raw.trim().isEmpty) return;
    _ctrl.clear();

    // Normalise Hindi/Hinglish → English before any NLU processing
    final translated = HindiTranslator.translate(raw);
    // Show original input in chat, process translated version
    _user(raw);

    if (NluEngine.isCancel(translated) &&
        _s.step != AssistantStep.confirm) {
      _reset();
      return;
    }

    switch (_s.step) {
      case AssistantStep.selectTxType:       await _handleTxType(translated);
      case AssistantStep.selectCustomer:     await _handleCustomer(raw, translated);
      case AssistantStep.setCoolJars:        await _handleCoolJars(translated);
      case AssistantStep.setPetJars:         await _handlePetJars(translated);
      case AssistantStep.setCoolReturn:      await _handleCoolReturn(translated);
      case AssistantStep.setPetReturn:       await _handlePetReturn(translated);
      case AssistantStep.setPayment:         await _handlePayment(translated);
      case AssistantStep.setExpenseCategory: await _handleExpenseCat(raw); // keep original for category name
      case AssistantStep.setExpenseAmount:   await _handleExpenseAmt(translated);
      case AssistantStep.confirm:            await _handleConfirm(translated);
    }
  }

  // ── 0. Tx type ───────────────────────────────────────────────────────────────
  Future<void> _handleTxType(String raw) async {
    final type = NluEngine.detectTxType(raw);
    if (type == null) {
      _bot('Not understood 😕\n'
          '1=Delivery  2=Event  3=Payment  4=Expense');
      return;
    }
    if (type == VoiceTxType.expense) {
      setState(() => _s = _s.copyWith(
          txType: type, step: AssistantStep.setExpenseCategory));
      _bot('📉 Expense selected!\n\nWhat is the expense category?\n'
          '(e.g. Petrol, Salary, Repair, Food, Other)');
      return;
    }
    setState(() => _s = _s.copyWith(txType: type,
        step: AssistantStep.selectCustomer));
    final label = switch (type) {
      VoiceTxType.delivery => '🚚 Delivery',
      VoiceTxType.event    => '🎉 Event',
      VoiceTxType.payment  => '💰 Payment',
      VoiceTxType.expense  => '📉 Expense',
    };
    _bot('$label selected! ✅\n\nType customer name or phone number:');
  }

  // ── 1. Customer ──────────────────────────────────────────────────────────────
  // Shows numbered list — user can say/type "1", "2", "3" to pick
  Future<void> _handleCustomer(String raw, String translated) async {
    final customers = ref.read(customersProvider)
        .where((c) => c.isActive).toList();

    // Pick by number from suggestion list (use translated — handles "ek"→"1" etc.)
    if (_suggestions.isNotEmpty) {
      final firstDigit = RegExp(r'\b([1-5])\b').firstMatch(translated.trim());
      final n = firstDigit != null ? int.tryParse(firstDigit.group(1)!) : null;
      if (n != null && n >= 1 && n <= _suggestions.length) {
        _selectCustomer(_suggestions[n - 1].customer);
        return;
      }
    }

    // Fuzzy name search — use ORIGINAL raw input so customer names aren't
    // mangled by the translator (e.g. "Ramesh ko" → don't strip "ko" yet)
    final nameQuery = _stripActionWords(raw);
    final matches   = NluEngine.findCustomers(nameQuery, customers);

    if (matches.isEmpty) {
      _bot('No customer found for "$raw".\n'
          'Try spelling differently or type phone number:');
      return;
    }

    if (matches.first.score >= 0.85) {
      _confirmCustomer(matches.first.customer);
    } else {
      final top = matches.take(5).toList();
      setState(() => _suggestions = top);
      // Embed suggestion cards as a special message IN the chat list
      // so they scroll naturally with the conversation
      final suggMsg = _Msg(
        'Found ${top.length} match${top.length > 1 ? 'es' : ''} — tap to select:',
        suggestions: top,
      );
      setState(() =>
          _s = _s.copyWith(messages: [..._s.messages, suggMsg]));
      _scrollToBottom();
    }
  }

  /// Strip common postposition words that appear after a name in speech
  /// e.g. "Ramesh ko" → "Ramesh", "Suresh ke liye" → "Suresh"
  String _stripActionWords(String raw) {
    var s = raw.toLowerCase().trim();
    for (final suffix in [
      ' ko ', ' ke liye', ' ka ', ' ki ', ' ke ',
      ' ko', ' wala', ' wale', ' waale',
      ' delivered', ' returned', ' payment', ' jar',
    ]) {
      final idx = s.indexOf(suffix);
      if (idx > 0) { s = s.substring(0, idx).trim(); break; }
    }
    return s;
  }

  void _confirmCustomer(Customer c) {
    setState(() => _suggestions = []);
    final bal = c.hasDues
        ? '⚠ Due: ₹${c.balance.abs().toInt()}'
        : c.hasCredit
            ? '💰 Credit: ₹${c.balance.toInt()}'
            : '✅ Clear';

    if (_s.txType == VoiceTxType.payment) {
      setState(() =>
          _s = _s.copyWith(customer: c, step: AssistantStep.setPayment));
      _bot('👤 ${c.name} ✅\n$bal\n\n'
          '💰 How much payment collected?\n'
          '(e.g. "200", "full", "zero")');
    } else {
      setState(() =>
          _s = _s.copyWith(customer: c, step: AssistantStep.setCoolJars));
      _bot('👤 ${c.name} ✅\n'
          '$bal  •  Jars with customer: Cool ${c.coolOut}  PET ${c.petOut}\n\n'
          '🫙 How many Cool jars delivered? (0 is ok)');
    }
  }

  void _selectCustomer(Customer c) {
    _user('👤 ${c.name}');
    _confirmCustomer(c);
  }

  // ── 2. Cool delivered ────────────────────────────────────────────────────────
  Future<void> _handleCoolJars(String raw) async {
    final n = NluEngine.parseNumber(raw);
    if (n == null) {
      _bot('Could not understand the number.\nHow many Cool jars delivered? (e.g. "4", "0")');
      return;
    }
    setState(() =>
        _s = _s.copyWith(coolDelivered: n, step: AssistantStep.setPetJars));
    _bot('Cool: $n ✅\n\n🫙 How many PET jars delivered? (0 is ok)');
  }

  // ── 3. Pet delivered ─────────────────────────────────────────────────────────
  Future<void> _handlePetJars(String raw) async {
    final n = NluEngine.parseNumber(raw);
    if (n == null) {
      _bot('Could not understand.\nHow many PET jars delivered? (e.g. "2", "0")');
      return;
    }
    setState(() =>
        _s = _s.copyWith(petDelivered: n, step: AssistantStep.setCoolReturn));
    _bot('PET: $n ✅\n\n🔁 How many Cool jars returned? (0 is ok)');
  }

  // ── 4. Cool returned ─────────────────────────────────────────────────────────
  Future<void> _handleCoolReturn(String raw) async {
    final n = NluEngine.parseNumber(raw);
    if (n == null) {
      _bot('Could not understand.\nHow many Cool jars returned? (e.g. "3", "0")');
      return;
    }
    setState(() =>
        _s = _s.copyWith(coolReturned: n, step: AssistantStep.setPetReturn));
    _bot('Cool returned: $n ✅\n\n🔁 How many PET jars returned? (0 is ok)');
  }

  // ── 5. Pet returned ──────────────────────────────────────────────────────────
  Future<void> _handlePetReturn(String raw) async {
    final n = NluEngine.parseNumber(raw);
    if (n == null) {
      _bot('Could not understand.\nHow many PET jars returned? (e.g. "1", "0")');
      return;
    }
    setState(() =>
        _s = _s.copyWith(petReturned: n, step: AssistantStep.setPayment));
    final b = (_s.coolDelivered * _coolPrice) + (_s.petDelivered * _petPrice);
    _bot('PET returned: $n ✅\n\n'
        '💵 Bill: ₹${b.toInt()} '
        '(${_s.coolDelivered}C×₹${_coolPrice.toInt()}'
        ' + ${_s.petDelivered}P×₹${_petPrice.toInt()})\n\n'
        '💰 How much payment collected?\n'
        '(e.g. "200", "full", "half", "0")');
  }

  // ── 6. Payment ───────────────────────────────────────────────────────────────
  Future<void> _handlePayment(String raw) async {
    double? amt = NluEngine.parseAmount(raw);
    if (amt == null) {
      _bot('Could not understand amount.\nHow much collected? (e.g. "200", "0", "full")');
      return;
    }
    if (amt == -1) amt = _billed / 2;
    if (amt == -2) amt = _billed;
    setState(() => _s = _s.copyWith(payment: amt!, step: AssistantStep.confirm));
    _showSummary();
  }

  // ── 6b. Expense category ─────────────────────────────────────────────────────
  Future<void> _handleExpenseCat(String raw) async {
    if (raw.trim().isEmpty) {
      _bot('Please enter a category — e.g. Petrol, Salary, Repair, Food');
      return;
    }
    setState(() => _s = _s.copyWith(
        expenseCategory: raw.trim(), step: AssistantStep.setExpenseAmount));
    _bot('Category: ${raw.trim()} ✅\n\nHow much was spent? (e.g. "500", "1000")');
  }

  // ── 6c. Expense amount ───────────────────────────────────────────────────────
  Future<void> _handleExpenseAmt(String raw) async {
    final amt = NluEngine.parseAmount(raw);
    if (amt == null || amt <= 0) {
      _bot('Could not understand amount.\nHow much was the expense? (e.g. "500")');
      return;
    }
    setState(() =>
        _s = _s.copyWith(payment: amt, step: AssistantStep.confirm));
    _bot('📋 Please confirm:\n\n'
        '📉 Expense: ${_s.expenseCategory}\n'
        '💸 Amount: ₹${amt.toInt()}\n\n'
        'Yes = Save  •  No = Reset');
  }

  // ── Confirm summary ──────────────────────────────────────────────────────────
  void _showSummary() {
    final c       = _s.customer!;
    final billed  = _billed;
    final pending = billed - _s.payment;
    final label   = _s.txType == VoiceTxType.event ? '🎉 Event' : '🚚 Delivery';
    _bot('📋 Please confirm:\n\n'
        '$label — 👤 ${c.name}\n'
        '─────────────────\n'
        '📦 Cool delivered: ${_s.coolDelivered}  |  PET delivered: ${_s.petDelivered}\n'
        '🔁 Cool returned: ${_s.coolReturned}   |  PET returned: ${_s.petReturned}\n'
        '─────────────────\n'
        '💵 Bill: ₹${billed.toInt()}\n'
        '💰 Collected: ₹${_s.payment.toInt()}\n'
        '${pending > 0 ? "⚠ Pending: ₹${pending.toInt()}" : "✅ Fully paid"}\n\n'
        'Yes = Save  •  No = Reset');
  }

  // ── 7. Confirm ───────────────────────────────────────────────────────────────
  Future<void> _handleConfirm(String raw) async {
    if (NluEngine.isCancel(raw)) { _reset(); return; }
    if (NluEngine.isConfirm(raw)) {
      await _save();
    } else {
      _bot('Say/type "yes" to save or "no" to reset');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _save() async {
    setState(() => _saving = true);
    final session = ref.read(sessionUserProvider);
    final now     = DateTime.now().toIso8601String();
    final today   = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      switch (_s.txType) {
        case VoiceTxType.expense:
          await ref.read(transactionsProvider.notifier).add(JarTransaction(
            id: _uuid.v4(), customerId: 'EXPENSE',
            customerName: _s.expenseCategory,
            date: today, createdAt: now,
            billedAmount: 0, amountCollected: 0,
            damageCharge: _s.payment,
            paymentMode: 'cash',
            note: '[${_s.expenseCategory}]',
            createdBy: session?.name ?? 'Admin',
            deliveryType: 'daily',
          ));

        case VoiceTxType.payment:
          final c = _s.customer!;
          await ref.read(transactionsProvider.notifier).add(JarTransaction(
            id: _uuid.v4(), customerId: c.id, customerName: c.name,
            date: today, createdAt: now,
            billedAmount: 0, amountCollected: _s.payment,
            paymentMode: 'cash',
            note: 'Voice payment entry',
            createdBy: session?.name ?? 'Admin',
            deliveryType: 'daily',
          ));

        case VoiceTxType.delivery:
        case VoiceTxType.event:
          final c     = _s.customer!;
          final coolP = c.coolPriceOverride ?? _settings.coolPrice;
          final petP  = c.petPriceOverride  ?? _settings.petPrice;
          final billed =
              (_s.coolDelivered * coolP) + (_s.petDelivered * petP);
          await ref.read(transactionsProvider.notifier).add(JarTransaction(
            id: _uuid.v4(), customerId: c.id, customerName: c.name,
            date: today, createdAt: now,
            coolDelivered: _s.coolDelivered, petDelivered: _s.petDelivered,
            coolReturned:  _s.coolReturned,  petReturned:  _s.petReturned,
            coolPrice: coolP, petPrice: petP,
            billedAmount: billed, amountCollected: _s.payment,
            paymentMode: 'cash',
            note: 'Voice entry',
            createdBy: session?.name ?? 'Admin',
            deliveryType: _s.txType == VoiceTxType.event ? 'event' : 'daily',
          ));
      }

      setState(() { _saving = false; _s = const _AS(); });
      _bot('✅ Saved successfully!\n\n'
          'Do another transaction?\n'
          '1=Delivery  2=Event  3=Payment  4=Expense\n'
          'Or press back to exit.');

    } catch (e) {
      setState(() => _saving = false);
      _bot('❌ Error: $e\nPlease try again.');
    }
  }

  void _reset() {
    setState(() { _s = const _AS(); _suggestions = []; });
    _bot('🔄 Reset! What do you want to do?\n'
        '1=Delivery  2=Event  3=Payment  4=Expense');
  }

  // ── Quick chips ──────────────────────────────────────────────────────────────
  List<String> get _chips => switch (_s.step) {
    AssistantStep.selectTxType      =>
        ['1 Delivery', '2 Event', '3 Payment', '4 Expense'],
    AssistantStep.setCoolJars       => ['0', '1', '2', '4', '6', '10'],
    AssistantStep.setPetJars        => ['0', '1', '2', '4', '6'],
    AssistantStep.setCoolReturn     => ['0', '1', '2', '3', '4'],
    AssistantStep.setPetReturn      => ['0', '1', '2', '3'],
    AssistantStep.setPayment        =>
        ['0', 'Poora', 'Aadha', '₹100', '₹200', '₹500'],
    AssistantStep.setExpenseAmount  =>
        ['₹100', '₹200', '₹500', '₹1000'],
    AssistantStep.confirm           => ['Yes', 'No'],
    _                               => [],
  };

  String get _hint => switch (_s.step) {
    AssistantStep.selectTxType        => '1/2/3/4 ya naam...',
    AssistantStep.selectCustomer      => 'Name / Phone / Area...',
    AssistantStep.setCoolJars         => 'Cool jar count (0-20)...',
    AssistantStep.setPetJars          => 'PET jar count (0-20)...',
    AssistantStep.setCoolReturn       => 'Cool returned (0-20)...',
    AssistantStep.setPetReturn        => 'PET returned (0-20)...',
    AssistantStep.setPayment          => 'Amount (200 / poora / 0)...',
    AssistantStep.setExpenseCategory  => 'Category (Petrol, Food...)...',
    AssistantStep.setExpenseAmount    => 'Amount (500)...',
    AssistantStep.confirm             => 'yes or no...',
  };

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // ── App bar ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Voice Assistant',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            Text('Speak or type in English',
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.inkMuted)),
          ]),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _StepDots(step: _s.step),
          ),
        ],
      ),

      body: Column(children: [

        // ── Chat messages ──────────────────────────────────────────────────────
        Expanded(child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          itemCount: _s.messages.length,
          itemBuilder: (ctx, i) {
            final msg = _s.messages[i];

            // Suggestion card message — renders cards inline
            if (msg.suggestions != null && msg.suggestions!.isNotEmpty) {
              return _SuggestionCards(
                label:       msg.text,
                suggestions: msg.suggestions!,
                isDark:      isDark,
                primary:     primary,
                onSelect:    _selectCustomer,
              );
            }

            return _ChatBubble(
              text: msg.text, isUser: msg.isUser,
              isDark: isDark, primary: primary,
            );
          },
        )),

        // ── Quick chips ────────────────────────────────────────────────────────
        if (_chips.isNotEmpty)
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => _onSubmit(_chips[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surface2Dark
                        : const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isDark
                            ? AppColors.separatorDark
                            : const Color(0xFFBDD5F8)),
                  ),
                  child: Text(_chips[i],
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primary)),
                ),
              ),
            ),
          ),

        const SizedBox(height: 4),

        // ── Listening status banner ────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _listening ? 36 : 0,
          color: AppColors.dangerColor(isDark).withValues(alpha: 0.08),
          child: _listening ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _PulseDot(color: AppColors.dangerColor(isDark)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '🎙 Listening...  Release hold or tap ✓ Done when finished speaking',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.dangerColor(isDark),
                    fontWeight: FontWeight.w600),
              )),
            ]),
          ) : const SizedBox.shrink(),
        ),

        // ── Input bar ──────────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
              10, 8, 10, 8 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            border: Border(top: BorderSide(
                color: isDark ? AppColors.separatorDark : AppColors.separator)),
          ),
          child: Row(children: [

            // ── Mic button — HOLD to speak, release to submit ────────────────
            GestureDetector(
              onTap: _toggleMic,           // quick tap = toggle (fallback)
              onLongPressStart: (_) async {
                // Hold: start listening
                if (!_listening) await _startListening();
              },
              onLongPressEnd: (_) async {
                // Release: stop and submit
                if (_listening) {
                  await _speech.stop();
                  setState(() => _listening = false);
                  _submitLiveText();
                }
              },
              onLongPressCancel: () async {
                if (_listening) {
                  await _speech.stop();
                  setState(() => _listening = false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _listening ? 52 : 46,
                height: _listening ? 52 : 46,
                decoration: BoxDecoration(
                  color: _listening
                      ? AppColors.dangerColor(isDark)
                      : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _listening
                        ? AppColors.dangerColor(isDark)
                        : (isDark
                            ? AppColors.separatorDark
                            : AppColors.separator),
                    width: _listening ? 2.5 : 1.5,
                  ),
                  boxShadow: _listening
                      ? [BoxShadow(
                          color: AppColors.dangerColor(isDark)
                              .withValues(alpha: 0.50),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 3))]
                      : null,
                ),
                child: Icon(
                  _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _listening
                      ? Colors.white
                      : (_sttAvail ? primary : AppColors.inkMuted),
                  size: _listening ? 26 : 22,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ── Text field ───────────────────────────────────────────────────
            Expanded(child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: _listening
                    ? AppColors.dangerColor(isDark).withValues(alpha: 0.05)
                    : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: _listening
                        ? AppColors.dangerColor(isDark)
                            .withValues(alpha: 0.35)
                        : (isDark
                            ? AppColors.separatorDark
                            : AppColors.separator)),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: !_sttAvail,
                textInputAction: TextInputAction.send,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _listening ? 'Speak now...' : _hint,
                  border: InputBorder.none,
                  filled: false,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                  hintStyle: GoogleFonts.inter(
                      color: _listening
                          ? AppColors.dangerColor(isDark)
                              .withValues(alpha: 0.6)
                          : AppColors.inkMuted,
                      fontSize: 13),
                ),
                onSubmitted: (v) {
                  if (_listening) {
                    _speech.stop();
                    setState(() => _listening = false);
                  }
                  _onSubmit(v);
                },
              ),
            )),

            const SizedBox(width: 8),

            // ── Done / Send button ───────────────────────────────────────────
            // While listening: shows "✓ Done" — stops mic and submits
            // Otherwise: send arrow
            GestureDetector(
              onTap: _saving
                  ? null
                  : () {
                      if (_listening) {
                        // Stop mic and submit recognised text
                        _speech.stop();
                        setState(() => _listening = false);
                        _submitLiveText();
                      } else {
                        _onSubmit(_ctrl.text);
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _listening ? 64 : 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius:
                      BorderRadius.circular(_listening ? 23 : 23),
                  boxShadow: [BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3))],
                ),
                child: _saving
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Center(child: _listening
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 4),
                              Text('Done',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP DOTS — progress indicator in app bar
// ══════════════════════════════════════════════════════════════════════════════
class _StepDots extends StatelessWidget {
  final AssistantStep step;
  const _StepDots({required this.step});

  static const _order = [
    AssistantStep.selectTxType,
    AssistantStep.selectCustomer,
    AssistantStep.setCoolJars,
    AssistantStep.setPetJars,
    AssistantStep.setCoolReturn,
    AssistantStep.setPetReturn,
    AssistantStep.setPayment,
    AssistantStep.confirm,
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final idx = _order.indexOf(step);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 0; i < _order.length; i++)
        Container(
          width: 6, height: 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == idx
                ? primary
                : i < idx
                    ? primary.withValues(alpha: 0.40)
                    : AppColors.inkMuted.withValues(alpha: 0.20),
          ),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHAT BUBBLE
// ══════════════════════════════════════════════════════════════════════════════
class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser, isDark;
  final Color primary;
  const _ChatBubble({
    required this.text,   required this.isUser,
    required this.isDark, required this.primary,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser
            ? primary
            : (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(16),
          topRight:    const Radius.circular(16),
          bottomLeft:  Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4  : 16),
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(
                alpha: isDark ? 0.18 : 0.07),
            blurRadius: 6,
            offset: const Offset(0, 2))],
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 13, height: 1.5,
              color: isUser
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87))),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// VOICE FAB — drop-in replacement for use in TransactionsScreen
// ══════════════════════════════════════════════════════════════════════════════
class VoiceFab extends StatelessWidget {
  final bool isDark;
  final Color primary;
  const VoiceFab({super.key, required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.25)),
        ),
        child: Text('Voice',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: primary)),
      ),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () => openVoiceAssistant(context),
        child: Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: primary.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.mic_rounded,
              color: Colors.white, size: 28),
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PULSE DOT — animated red dot shown while listening
// ══════════════════════════════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ac   = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
          color: widget.color, shape: BoxShape.circle),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SUGGESTION CARDS — rendered inline inside the chat ListView
// Shown as a bot-side message with tappable customer cards below the label
// ══════════════════════════════════════════════════════════════════════════════
class _SuggestionCards extends StatelessWidget {
  final String label;
  final List<({Customer customer, double score})> suggestions;
  final bool isDark;
  final Color primary;
  final void Function(Customer) onSelect;

  const _SuggestionCards({
    required this.label,
    required this.suggestions,
    required this.isDark,
    required this.primary,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label bubble (same style as bot bubble)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(16),
                topRight:    Radius.circular(16),
                bottomLeft:  Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.07),
                  blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, height: 1.5,
                    color: isDark ? Colors.white : Colors.black87)),
          ),

          // Customer cards — full width, stacked vertically
          ...List.generate(suggestions.length, (i) {
            final r   = suggestions[i];
            final c   = r.customer;
            final pct = (r.score * 100).toInt();
            final bal = c.hasDues
                ? '⚠ Due ₹${c.balance.abs().toInt()}'
                : c.hasCredit
                    ? '💰 Cr ₹${c.balance.toInt()}'
                    : '✅ Clear';
            final balColor = c.hasDues
                ? AppColors.dangerColor(isDark)
                : c.hasCredit
                    ? AppColors.successColor(isDark)
                    : AppColors.inkMuted;

            return GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: primary.withValues(alpha: 0.40), width: 1.5),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(
                          alpha: isDark ? 0.18 : 0.07),
                      blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(children: [
                  // Number badge
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('${i + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: primary))),
                  ),
                  const SizedBox(width: 10),
                  CustomerAvatar(initials: c.initials, size: 34),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(c.name,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87)),
                    Text(
                      '${c.area.isNotEmpty ? "${c.area}  •  " : ""}$bal',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: balColor),
                    ),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$pct%',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: primary)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.inkMuted, size: 18),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}
