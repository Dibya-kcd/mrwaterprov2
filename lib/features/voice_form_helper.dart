// ════════════════════════════════════════════════════════════════════════════
// voice_form_helper.dart
//
// Provides:
//   1. VoiceMicButton — small "🎙 Voice Fill" button for any form
//   2. VoiceFormSheet — mini voice flow opened as a bottom sheet
//      Pre-scoped to the form type (delivery/event/return/payment/expense)
//      Skips the tx-type selection step since context is already known.
//   3. Better number parsing for jar counts and amounts
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';
import 'voice_assistant.dart' show HindiTranslator, NluEngine;

// ══════════════════════════════════════════════════════════════════════════════
// RESULT — what the voice form returns to the calling form
// ══════════════════════════════════════════════════════════════════════════════
class VoiceFormResult {
  final Customer? customer;
  final int coolDelivered;
  final int petDelivered;
  final int coolReturned;
  final int petReturned;
  final double payment;
  final String expenseCategory;
  final double expenseAmount;
  final String note;

  const VoiceFormResult({
    this.customer,
    this.coolDelivered = 0,
    this.petDelivered  = 0,
    this.coolReturned  = 0,
    this.petReturned   = 0,
    this.payment       = 0,
    this.expenseCategory = '',
    this.expenseAmount   = 0,
    this.note = 'Voice entry',
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// FORM TYPE — tells VoiceFormSheet which fields to ask for
// ══════════════════════════════════════════════════════════════════════════════
enum VoiceFormType { delivery, event, returnJars, payment, expense }

// ══════════════════════════════════════════════════════════════════════════════
// BETTER NUMBER PARSER
// Handles: "4", "four", "char", "04", "4 jars", "4-4", "4.0"
// Also handles Indian English STT quirks
// ══════════════════════════════════════════════════════════════════════════════
class VoiceNumberParser {
  static const _words = <String, int>{
    'zero':0,'one':1,'two':2,'three':3,'four':4,'five':5,
    'six':6,'seven':7,'eight':8,'nine':9,'ten':10,
    'eleven':11,'twelve':12,'thirteen':13,'fourteen':14,'fifteen':15,
    'sixteen':16,'seventeen':17,'eighteen':18,'nineteen':19,'twenty':20,
    // Indian English / Hinglish
    'ek':1,'do':2,'teen':3,'char':4,'chaar':4,'paanch':5,'panch':5,
    'chhe':6,'che':6,'saat':7,'sat':7,'aath':8,'aat':8,'nau':9,'das':10,
    'barah':12,'pandrah':15,'bees':20,'bis':20,
    // Zero variants
    'nil':0,'null':0,'nothing':0,'nill':0,'nahi':0,'na':0,
    'kuch nahi':0,'zero jar':0,
  };

  /// Parse an integer from any spoken/typed form.
  /// Returns null only if completely unrecognisable.
  static int? parseInt(String raw) {
    final s = raw.toLowerCase().trim();

    // Strip common noise words
    var clean = s
        .replaceAll(RegExp(r'\b(jars?|bottles?|cool|pet|return|deliver(ed)?|wapas|diye?|diya)\b'), '')
        .replaceAll(RegExp(r'[,।]'), '')
        .trim();

    // "4-4", "4.0", "04" — take first numeric group
    final digitMatch = RegExp(r'\b(\d+)\b').firstMatch(clean);
    if (digitMatch != null) {
      final n = int.tryParse(digitMatch.group(1)!);
      if (n != null && n <= 100) return n;
    }

    // Word match — longest first to avoid "fourteen" matching "four"
    final sorted = _words.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in sorted) {
      if (clean.contains(e.key)) return e.value;
    }
    return null;
  }

  /// Parse an amount. Returns -1=half, -2=full, or actual double.
  static double? parseAmount(String raw) {
    final s = HindiTranslator.translate(raw).toLowerCase().trim();
    if (s.contains('half') || s.contains('aadha')) return -1;
    if (s.contains('full') || s.contains('poora') || s.contains('all') ||
        s.contains('complete') || s.contains('sab')) return -2;
    if (_isZero(s)) return 0;

    // "five hundred", "paanch sau"
    final mulMap = <String, double>{
      'hundred':100, 'sau':100, 'thousand':1000, 'hazaar':1000,
    };
    double? base;
    double? mul;
    final sorted = _words.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in sorted) {
      if (s.contains(e.key)) { base = e.value.toDouble(); break; }
    }
    for (final e in mulMap.entries) {
      if (s.contains(e.key)) { mul = e.value; break; }
    }
    if (base != null && mul != null) return base * mul;
    if (mul != null) return mul;

    final m = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(s);
    if (m != null) return double.tryParse(m.group(1)!);
    return null;
  }

  static bool _isZero(String s) =>
      RegExp(r'\b(zero|0|nothing|nil|nill|none|no|na|nahi|kuch nahi)\b')
          .hasMatch(s);
}

// ══════════════════════════════════════════════════════════════════════════════
// VOICE MIC BUTTON — drop into any form
// Shows a small gradient button. Tapping opens VoiceFormSheet.
// onResult is called with pre-filled values.
// ══════════════════════════════════════════════════════════════════════════════
class VoiceMicButton extends StatelessWidget {
  final VoiceFormType formType;
  final Customer? preselectedCustomer; // if already selected in form
  final void Function(VoiceFormResult) onResult;

  const VoiceMicButton({
    super.key,
    required this.formType,
    required this.onResult,
    this.preselectedCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<VoiceFormResult>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (ctx, ctrl) => ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
              child: VoiceFormSheet(
                formType:            formType,
                preselectedCustomer: preselectedCustomer,
                scrollController:    ctrl,
              ),
            ),
          ),
        );
        if (result != null) onResult(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(
              color: primary.withValues(alpha: 0.30),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.mic_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text('Voice Fill',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// VOICE FORM SHEET — mini voice assistant scoped to one form type
// ══════════════════════════════════════════════════════════════════════════════
enum _Step {
  selectCustomer, // skipped if preselectedCustomer != null
  coolJars,
  petJars,
  coolReturn,
  petReturn,
  amount,
  expenseCategory,
  expenseAmount,
  done,
}

class _FMsg {
  final String text;
  final bool isUser;
  final List<({Customer customer, double score})>? suggestions;
  const _FMsg(this.text, {this.isUser = false, this.suggestions});
}

class VoiceFormSheet extends ConsumerStatefulWidget {
  final VoiceFormType formType;
  final Customer? preselectedCustomer;
  final ScrollController? scrollController;

  const VoiceFormSheet({
    super.key,
    required this.formType,
    this.preselectedCustomer,
    this.scrollController,
  });

  @override
  ConsumerState<VoiceFormSheet> createState() => _VoiceFormSheetState();
}

class _VoiceFormSheetState extends ConsumerState<VoiceFormSheet> {
  _Step _step = _Step.selectCustomer;
  Customer? _cust;
  int _coolDel = 0, _petDel = 0, _coolRet = 0, _petRet = 0;
  double _amount = 0;
  String _expCat = '';
  double _expAmt = 0;

  List<_FMsg> _msgs = [];
  List<({Customer customer, double score})> _suggestions = [];
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _speech     = stt.SpeechToText();
  bool _sttAvail    = false;
  bool _listening   = false;
  String _liveText  = '';

  AppSettings get _settings => ref.read(settingsProvider);
  double get _coolP => _cust?.coolPriceOverride ?? _settings.coolPrice;
  double get _petP  => _cust?.petPriceOverride  ?? _settings.petPrice;
  double get _billed =>
      (_coolDel * _coolP) + (_petDel * _petP);

  @override
  void initState() {
    super.initState();
    _initStt();
    if (widget.preselectedCustomer != null) {
      _cust = widget.preselectedCustomer;
      _step = _firstStepForType();
    }
    _bot(_greeting());
  }

  @override
  void dispose() {
    _speech.stop();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── STT ─────────────────────────────────────────────────────────────────────
  Future<void> _initStt() async {
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (s == 'notListening' && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (_) { if (mounted) setState(() => _listening = false); },
    );
    if (mounted) setState(() => _sttAvail = ok);
  }

  Future<void> _toggleMic() async {
    if (!_sttAvail) { await _initStt(); if (!_sttAvail) return; }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      _submitLive();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    setState(() { _listening = true; _liveText = ''; _ctrl.clear(); });
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          _liveText = r.recognizedWords;
          _ctrl.text = r.recognizedWords;
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

  void _submitLive() {
    final t = _liveText.trim().isNotEmpty ? _liveText.trim() : _ctrl.text.trim();
    _liveText = ''; _ctrl.clear();
    if (t.isNotEmpty) _onSubmit(t);
  }

  // ── Messages ─────────────────────────────────────────────────────────────────
  void _bot(String text, {List<({Customer customer, double score})>? sugg}) {
    setState(() {
      _msgs = [..._msgs, _FMsg(text, suggestions: sugg)];
      if (sugg == null) _suggestions = [];
    });
    _scrollLast();
  }

  void _user(String text) {
    setState(() => _msgs = [..._msgs, _FMsg(text, isUser: true)]);
    _scrollLast();
  }

  void _scrollLast() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  // ── Greeting ─────────────────────────────────────────────────────────────────
  String _greeting() {
    final custLine = _cust != null ? '👤 ${_cust!.name} selected.\n\n' : '';
    return switch (widget.formType) {
      VoiceFormType.delivery  => '${custLine}🚚 Delivery — How many Cool jars delivered? (say "0" if none)',
      VoiceFormType.event     => '${custLine}🎉 Event delivery — How many Cool jars?',
      VoiceFormType.returnJars=> '${custLine}📦 Return Jars — How many Cool jars returned? (say "0" if none)',
      VoiceFormType.payment   => '${custLine}💰 Payment — How much was collected?\n(e.g. "200", "full", "zero")',
      VoiceFormType.expense   => '📉 Expense — What is the category?\n(e.g. Petrol, Salary, Repair)',
    };
  }

  _Step _firstStepForType() => switch (widget.formType) {
    VoiceFormType.delivery   => _Step.coolJars,
    VoiceFormType.event      => _Step.coolJars,
    VoiceFormType.returnJars => _Step.coolReturn,
    VoiceFormType.payment    => _Step.amount,
    VoiceFormType.expense    => _Step.expenseCategory,
  };

  // ── Submit handler ────────────────────────────────────────────────────────────
  Future<void> _onSubmit(String raw) async {
    if (raw.trim().isEmpty) return;
    _ctrl.clear();
    _user(raw);
    final tr = HindiTranslator.translate(raw);

    // Cancel
    if (NluEngine.isCancel(tr)) {
      Navigator.pop(context);
      return;
    }

    switch (_step) {
      case _Step.selectCustomer:    _handleCustomer(raw, tr); break;
      case _Step.coolJars:          _handleCoolJars(tr); break;
      case _Step.petJars:           _handlePetJars(tr); break;
      case _Step.coolReturn:        _handleCoolReturn(tr); break;
      case _Step.petReturn:         _handlePetReturn(tr); break;
      case _Step.amount:            _handleAmount(tr); break;
      case _Step.expenseCategory:   _handleExpCat(raw); break;
      case _Step.expenseAmount:     _handleExpAmt(tr); break;
      case _Step.done:
        if (NluEngine.isConfirm(tr)) _finish();
        else _bot('Say "yes" to apply, "no" to cancel.');
    }
  }

  // ── Customer search ───────────────────────────────────────────────────────────
  void _handleCustomer(String raw, String tr) {
    final customers = ref.read(customersProvider)
        .where((c) => c.isActive).toList();

    if (_suggestions.isNotEmpty) {
      final m = RegExp(r'\b([1-5])\b').firstMatch(tr);
      final n = m != null ? int.tryParse(m.group(1)!) : null;
      if (n != null && n >= 1 && n <= _suggestions.length) {
        _pickCustomer(_suggestions[n - 1].customer);
        return;
      }
    }

    final q       = _stripPostpositions(raw);
    final matches = NluEngine.findCustomers(q, customers);

    if (matches.isEmpty) {
      _bot('No customer found for "$raw". Try again:');
      return;
    }
    if (matches.first.score >= 0.85) {
      _pickCustomer(matches.first.customer);
    } else {
      final top = matches.take(5).toList();
      setState(() => _suggestions = top);
      _bot(
        'Found ${top.length} match${top.length > 1 ? 'es' : ''} — tap to select:',
        sugg: top,
      );
    }
  }

  void _pickCustomer(Customer c) {
    setState(() { _cust = c; _step = _firstStepForType(); _suggestions = []; });
    _bot(_greeting());
  }

  String _stripPostpositions(String raw) {
    var s = raw.toLowerCase().trim();
    for (final suf in [' ko', ' ke liye', ' ka', ' ki', ' ke',
                        ' wala', ' wale', ' delivered', ' returned']) {
      final i = s.indexOf(suf);
      if (i > 0) { s = s.substring(0, i).trim(); break; }
    }
    return s;
  }

  // ── Jar steps ─────────────────────────────────────────────────────────────────
  void _handleCoolJars(String tr) {
    final n = VoiceNumberParser.parseInt(tr);
    if (n == null) { _bot('Could not understand. How many Cool jars? (e.g. "4", "0")'); return; }
    _coolDel = n;
    setState(() => _step = _Step.petJars);
    _bot('Cool: $n ✅\n\nHow many PET jars delivered? (say "0" if none)');
  }

  void _handlePetJars(String tr) {
    final n = VoiceNumberParser.parseInt(tr);
    if (n == null) { _bot('Could not understand. How many PET jars? (e.g. "2", "0")'); return; }
    _petDel = n;
    setState(() => _step = widget.formType == VoiceFormType.returnJars
        ? _Step.coolReturn : _Step.coolReturn);
    _bot('PET: $n ✅\n\nHow many Cool jars returned? (say "0" if none)');
  }

  void _handleCoolReturn(String tr) {
    final n = VoiceNumberParser.parseInt(tr);
    if (n == null) { _bot('Could not understand. Cool jars returned? (e.g. "3", "0")'); return; }
    _coolRet = n;
    setState(() => _step = _Step.petReturn);
    _bot('Cool returned: $n ✅\n\nHow many PET jars returned? (say "0" if none)');
  }

  void _handlePetReturn(String tr) {
    final n = VoiceNumberParser.parseInt(tr);
    if (n == null) { _bot('Could not understand. PET jars returned? (e.g. "1", "0")'); return; }
    _petRet = n;
    setState(() => _step = _Step.amount);
    final b = (_coolDel * _coolP) + (_petDel * _petP);
    _bot('PET returned: $n ✅\n\n'
        '💵 Bill: ₹${b.toInt()}\n\n'
        'How much payment collected?\n(e.g. "200", "full", "half", "0")');
  }

  // ── Payment ───────────────────────────────────────────────────────────────────
  void _handleAmount(String tr) {
    double? amt = VoiceNumberParser.parseAmount(tr);
    if (amt == null) {
      _bot('Could not understand. How much collected? (e.g. "200", "0")');
      return;
    }
    if (amt == -1) amt = _billed / 2;
    if (amt == -2) amt = _billed;
    _amount = amt;
    setState(() => _step = _Step.done);
    _showSummary();
  }

  // ── Expense ───────────────────────────────────────────────────────────────────
  void _handleExpCat(String raw) {
    if (raw.trim().isEmpty) { _bot('Please say the category name.'); return; }
    _expCat = raw.trim();
    setState(() => _step = _Step.expenseAmount);
    _bot('Category: $_expCat ✅\n\nHow much was spent? (e.g. "500")');
  }

  void _handleExpAmt(String tr) {
    final amt = VoiceNumberParser.parseAmount(tr);
    if (amt == null || (amt != -1 && amt != -2 && amt <= 0)) {
      _bot('Could not understand. How much? (e.g. "500")');
      return;
    }
    _expAmt = amt > 0 ? amt : 0;
    setState(() => _step = _Step.done);
    _bot('📋 Confirm expense:\n\n'
        '📉 Category: $_expCat\n'
        '💸 Amount: ₹${_expAmt.toInt()}\n\n'
        'Say "yes" to apply or "no" to cancel.');
  }

  // ── Summary ───────────────────────────────────────────────────────────────────
  void _showSummary() {
    final c = _cust;
    final type = switch (widget.formType) {
      VoiceFormType.delivery  => '🚚 Delivery',
      VoiceFormType.event     => '🎉 Event',
      VoiceFormType.returnJars=> '📦 Return',
      VoiceFormType.payment   => '💰 Payment',
      VoiceFormType.expense   => '📉 Expense',
    };
    final billed = _billed;
    _bot('📋 Confirm:\n\n'
        '$type${c != null ? " — ${c.name}" : ""}\n'
        '─────────────────\n'
        '📦 Cool: $_coolDel delivered  |  $_coolRet returned\n'
        '🫙 PET:  $_petDel delivered  |  $_petRet returned\n'
        '─────────────────\n'
        '💵 Bill: ₹${billed.toInt()}\n'
        '💰 Collected: ₹${_amount.toInt()}\n'
        '${billed - _amount > 0 ? "⚠ Pending: ₹${(billed - _amount).toInt()}" : "✅ Settled"}\n\n'
        'Say "yes" to apply in form, or "no" to cancel.');
  }

  // ── Finish — return result to form ───────────────────────────────────────────
  void _finish() {
    Navigator.pop(context, VoiceFormResult(
      customer:        _cust,
      coolDelivered:   _coolDel,
      petDelivered:    _petDel,
      coolReturned:    _coolRet,
      petReturned:     _petRet,
      payment:         _amount,
      expenseCategory: _expCat,
      expenseAmount:   _expAmt,
      note:            'Voice entry',
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bg,
      body: Column(children: [

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            border: Border(bottom: BorderSide(
                color: isDark ? AppColors.separatorDark : AppColors.separator)),
          ),
          child: Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.mic_rounded,
                    color: Colors.white, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(_formTitle(), style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87)),
              Text('Voice fill — speak or type',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.inkMuted)),
            ])),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
              iconSize: 20,
            ),
          ]),
        ),

        // Chat
        Expanded(child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          itemCount: _msgs.length,
          itemBuilder: (ctx, i) {
            final m = _msgs[i];
            if (m.suggestions != null && m.suggestions!.isNotEmpty) {
              return _InlineSuggCards(
                  label: m.text, suggestions: m.suggestions!,
                  isDark: isDark, primary: primary,
                  onSelect: (c) {
                    _user('👤 ${c.name}');
                    _pickCustomer(c);
                  });
            }
            return _FBubble(text: m.text, isUser: m.isUser,
                isDark: isDark, primary: primary);
          },
        )),

        // Listening banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: _listening ? 32 : 0,
          color: AppColors.dangerColor(isDark).withValues(alpha: 0.08),
          child: _listening ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              _FPulse(color: AppColors.dangerColor(isDark)),
              const SizedBox(width: 8),
              Text('Listening... release or tap ✓ Done',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.dangerColor(isDark))),
            ]),
          ) : const SizedBox.shrink(),
        ),

        // Input bar
        Container(
          padding: EdgeInsets.fromLTRB(
              10, 8, 10, 8 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            border: Border(top: BorderSide(
                color: isDark ? AppColors.separatorDark : AppColors.separator)),
          ),
          child: Row(children: [
            // Mic button
            GestureDetector(
              onTap: _toggleMic,
              onLongPressStart: (_) async {
                if (!_listening) await _startListening();
              },
              onLongPressEnd: (_) async {
                if (_listening) {
                  await _speech.stop();
                  setState(() => _listening = false);
                  _submitLive();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _listening ? 50 : 44,
                height: _listening ? 50 : 44,
                decoration: BoxDecoration(
                  color: _listening
                      ? AppColors.dangerColor(isDark)
                      : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _listening
                        ? AppColors.dangerColor(isDark)
                        : (isDark ? AppColors.separatorDark : AppColors.separator),
                    width: _listening ? 2 : 1.5,
                  ),
                  boxShadow: _listening ? [BoxShadow(
                      color: AppColors.dangerColor(isDark).withValues(alpha: 0.40),
                      blurRadius: 12)] : null,
                ),
                child: Icon(
                  _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _listening ? Colors.white
                      : (_sttAvail ? primary : AppColors.inkMuted),
                  size: _listening ? 24 : 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: _listening
                    ? AppColors.dangerColor(isDark).withValues(alpha: 0.05)
                    : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: _listening
                        ? AppColors.dangerColor(isDark).withValues(alpha: 0.35)
                        : (isDark ? AppColors.separatorDark : AppColors.separator)),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: false,
                textInputAction: TextInputAction.send,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _listening ? 'Speak now...' : _hint,
                  border: InputBorder.none, filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  hintStyle: GoogleFonts.inter(
                      color: AppColors.inkMuted, fontSize: 13),
                ),
                onSubmitted: (v) {
                  if (_listening) { _speech.stop(); setState(() => _listening = false); }
                  _onSubmit(v);
                },
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_listening) {
                  _speech.stop(); setState(() => _listening = false); _submitLive();
                } else {
                  _onSubmit(_ctrl.text);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _listening ? 64 : 44, height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                      color: primary.withValues(alpha: 0.30),
                      blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Center(child: _listening
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text('Done', style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                      ])
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  String _formTitle() => switch (widget.formType) {
    VoiceFormType.delivery   => '🚚 Voice — New Delivery',
    VoiceFormType.event      => '🎉 Voice — New Event',
    VoiceFormType.returnJars => '📦 Voice — Return Jars',
    VoiceFormType.payment    => '💰 Voice — Record Payment',
    VoiceFormType.expense    => '📉 Voice — Record Expense',
  };

  String get _hint => switch (_step) {
    _Step.selectCustomer  => 'Customer name / phone...',
    _Step.coolJars        => 'Cool jars delivered (0-20)...',
    _Step.petJars         => 'PET jars delivered (0-20)...',
    _Step.coolReturn      => 'Cool jars returned (0-20)...',
    _Step.petReturn       => 'PET jars returned (0-20)...',
    _Step.amount          => 'Amount collected (e.g. 200)...',
    _Step.expenseCategory => 'Category (Petrol, Food...)...',
    _Step.expenseAmount   => 'Amount (e.g. 500)...',
    _Step.done            => 'yes / no...',
  };
}

// ── Small helper widgets ──────────────────────────────────────────────────────

class _FBubble extends StatelessWidget {
  final String text;
  final bool isUser, isDark;
  final Color primary;
  const _FBubble({required this.text, required this.isUser,
      required this.isDark, required this.primary});
  @override
  Widget build(BuildContext context) => Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? primary : (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(16),
          topRight:    const Radius.circular(16),
          bottomLeft:  Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Text(text, style: GoogleFonts.inter(
          fontSize: 13, height: 1.5,
          color: isUser ? Colors.white
              : (isDark ? Colors.white : Colors.black87))),
    ),
  );
}

class _InlineSuggCards extends StatelessWidget {
  final String label;
  final List<({Customer customer, double score})> suggestions;
  final bool isDark;
  final Color primary;
  final void Function(Customer) onSelect;
  const _InlineSuggCards({required this.label, required this.suggestions,
      required this.isDark, required this.primary, required this.onSelect});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(
              alpha: isDark ? 0.16 : 0.06), blurRadius: 5)],
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, height: 1.5,
            color: isDark ? Colors.white : Colors.black87)),
      ),
      ...List.generate(suggestions.length, (i) {
        final r = suggestions[i];
        final c = r.customer;
        final bal = c.hasDues
            ? '⚠ Due ₹${c.balance.abs().toInt()}'
            : c.hasCredit ? '💰 Cr ₹${c.balance.toInt()}' : '✅ Clear';
        return GestureDetector(
          onTap: () => onSelect(c),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.40), width: 1.5),
            ),
            child: Row(children: [
              Container(width: 26, height: 26,
                  decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Center(child: Text('${i+1}',
                      style: GoogleFonts.inter(fontSize: 12,
                          fontWeight: FontWeight.w800, color: primary)))),
              const SizedBox(width: 10),
              CustomerAvatar(initials: c.initials, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(c.name, style: GoogleFonts.inter(fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(bal, style: GoogleFonts.inter(fontSize: 11,
                    color: c.hasDues ? AppColors.dangerColor(isDark)
                        : c.hasCredit ? AppColors.successColor(isDark)
                        : AppColors.inkMuted),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              ])),
              Text('${(r.score*100).toInt()}%',
                  style: GoogleFonts.inter(fontSize: 11,
                      fontWeight: FontWeight.w700, color: primary)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.inkMuted, size: 16),
            ]),
          ),
        );
      }),
    ]),
  );
}

class _FPulse extends StatefulWidget {
  final Color color;
  const _FPulse({required this.color});
  @override State<_FPulse> createState() => _FPulseState();
}
class _FPulseState extends State<_FPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _a;
  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: Container(width: 7, height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
  );
}
