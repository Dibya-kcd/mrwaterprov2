import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/app_state.dart';
import '../core/utils/pin_hash_util.dart';
import 'modern_app_logo.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';
import 'diagnostics_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const ScreenHeader(title: 'Settings', subtitle: 'Configure your business app'),
        const SizedBox(height: 4),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Business Profile ──────────────────────────────────────────────────
        _Section(
          id: 'business', title: '🏢 Business Profile', expanded: _expanded == 'business',
          onToggle: () => setState(() => _expanded = _expanded == 'business' ? null : 'business'),
          child: _BusinessForm(settings: s),
        ),

        // ── App Identity ──────────────────────────────────────────────────────
        _Section(
          id: 'identity', title: '🏷️ App Identity', expanded: _expanded == 'identity',
          onToggle: () => setState(() => _expanded = _expanded == 'identity' ? null : 'identity'),
          child: _AppIdentityForm(settings: s),
        ),

        // ── Pricing ───────────────────────────────────────────────────────────
        _Section(
          id: 'pricing', title: '💰 Pricing & Charges', expanded: _expanded == 'pricing',
          onToggle: () => setState(() => _expanded = _expanded == 'pricing' ? null : 'pricing'),
          child: _PricingForm(settings: s),
        ),

        // ── Inventory ─────────────────────────────────────────────────────────
        _Section(
          id: 'inventory', title: '📦 Inventory Rules', expanded: _expanded == 'inventory',
          onToggle: () => setState(() => _expanded = _expanded == 'inventory' ? null : 'inventory'),
          child: _InventoryForm(settings: s),
        ),

        // ── Payment & Sync ────────────────────────────────────────────────────
        _Section(
          id: 'payment', title: '💳 Payment & Sync', expanded: _expanded == 'payment',
          onToggle: () => setState(() => _expanded = _expanded == 'payment' ? null : 'payment'),
          child: _PaymentForm(settings: s),
        ),

        // ── Theme & UI ────────────────────────────────────────────────────────
        _Section(
          id: 'theme', title: '🎨 Theme & UI', expanded: _expanded == 'theme',
          onToggle: () => setState(() => _expanded = _expanded == 'theme' ? null : 'theme'),
          child: _ThemeForm(settings: s),
        ),

        // ── Audit & Data ──────────────────────────────────────────────────────
        _Section(
          id: 'audit', title: '📋 Audit & Data', expanded: _expanded == 'audit',
          onToggle: () => setState(() => _expanded = _expanded == 'audit' ? null : 'audit'),
          child: _AuditForm(settings: s),
        ),

        _Section(
          id: 'staff', title: '👷 Staff Access', expanded: _expanded == 'staff',
          onToggle: () => setState(() => _expanded = _expanded == 'staff' ? null : 'staff'),
          child: ref.watch(sessionUserProvider) == null
              ? const _StaffForm()
              : const _StaffAccessReadOnly(),
        ),

        // ── Firebase Diagnostics ──────────────────────────────────────────────
        _Section(
          id: 'diagnostics', title: '🔬 Firebase Diagnostics', expanded: _expanded == 'diagnostics',
          onToggle: () => setState(() => _expanded = _expanded == 'diagnostics' ? null : 'diagnostics'),
          child: const _DiagnosticsLauncher(),
        ),

        const SizedBox(height: 16),
        // App version
        Center(child: Column(children: [
          Text('MrWater v2.1.0', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.inkMuted)),
          const SizedBox(height: 4),
          Text('Flutter · Built for Indian water delivery businesses',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted), textAlign: TextAlign.center),
        ])),
        const SizedBox(height: 40),
        ])),  // inner Column+Padding
      ]),
    );
  }
}

// ── Collapsible Section ───────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String id, title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _Section({required this.id, required this.title, required this.expanded,
      required this.onToggle, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface))),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded, color: AppColors.inkMuted),
                ),
              ]),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: child),
          ],
        ]),
      ),
    );
  }
}

// ── Business Profile Form ─────────────────────────────────────────────────────
class _BusinessForm extends ConsumerStatefulWidget {
  final AppSettings settings;
  const _BusinessForm({required this.settings});

  @override
  ConsumerState<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends ConsumerState<_BusinessForm> {
  late TextEditingController _bizName, _owner, _phone, _address, _gstin, _invPrefix;
  late bool _gst;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _bizName = TextEditingController(text: widget.settings.businessName);
    _owner = TextEditingController(text: widget.settings.ownerName);
    _phone = TextEditingController(text: widget.settings.phone);
    _address = TextEditingController(text: widget.settings.address);
    _gstin = TextEditingController(text: widget.settings.gstin);
    _invPrefix = TextEditingController(text: widget.settings.invoicePrefix);
    _gst = widget.settings.gstEnabled;
  }

  @override
  void dispose() { _bizName.dispose(); _owner.dispose(); _phone.dispose(); _address.dispose(); _gstin.dispose(); _invPrefix.dispose(); super.dispose(); }

  void _save() {
    ref.read(settingsProvider.notifier).save(widget.settings.copyWith(
      businessName: _bizName.text.trim(), ownerName: _owner.text.trim(),
      phone: _phone.text.trim(), address: _address.text.trim(),
      gstin: _gstin.text.trim(), gstEnabled: _gst,
      invoicePrefix: _invPrefix.text.trim(),
    ));
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    _TF(label: 'Business Name', ctrl: _bizName),
    _TF(label: 'Owner Name', ctrl: _owner),
    _TF(label: 'Phone', ctrl: _phone, type: TextInputType.phone),
    _TF(label: 'Address', ctrl: _address, maxLines: 2),
    _Toggle(label: 'GST Enabled', value: _gst, onChanged: (v) => setState(() => _gst = v)),
    if (_gst) _TF(label: 'GSTIN', ctrl: _gstin),
    _TF(label: 'Invoice Prefix (e.g. MRW)', ctrl: _invPrefix),
    const SizedBox(height: 4),
    _SaveBtn(saved: _saved, onSave: _save),
  ]);
}

// ── App Identity Form ─────────────────────────────────────────────────────────
class _AppIdentityForm extends ConsumerStatefulWidget {
  final AppSettings settings;
  const _AppIdentityForm({required this.settings});

  @override
  ConsumerState<_AppIdentityForm> createState() => _AppIdentityState();
}

class _AppIdentityState extends ConsumerState<_AppIdentityForm> {
  late TextEditingController _appName, _currency, _dateFormat, _logoUrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _appName    = TextEditingController(text: widget.settings.appName);
    _currency   = TextEditingController(text: widget.settings.currency);
    _dateFormat = TextEditingController(text: widget.settings.dateFormat);
    _logoUrl    = TextEditingController(text: widget.settings.logoUrl);
  }

  @override
  void dispose() { _appName.dispose(); _currency.dispose(); _dateFormat.dispose(); _logoUrl.dispose(); super.dispose(); }

  void _save() {
    ref.read(settingsProvider.notifier).save(widget.settings.copyWith(
      appName: _appName.text.trim(),
      currency: _currency.text.trim(),
      dateFormat: _dateFormat.text.trim(),
      logoUrl: _logoUrl.text.trim(),
    ));
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // ── Company Logo ──────────────────────────────────────────────────────────
    const FieldLabel('Company Logo'),
    const LogoPickerWidget(),
    const SizedBox(height: 16),
    // ── Identity fields ───────────────────────────────────────────────────────
    _TF(label: 'App Name', ctrl: _appName, hint: 'e.g. MrWater, AquaFlow'),
    _TF(label: 'Currency Symbol', ctrl: _currency, hint: '₹'),
    _TF(label: 'Date Format', ctrl: _dateFormat, hint: 'dd MMM yyyy'),
    const SizedBox(height: 4),
    _SaveBtn(saved: _saved, onSave: _save),
  ]);
}

// ── Pricing Form ──────────────────────────────────────────────────────────────
class _PricingForm extends ConsumerStatefulWidget {
  final AppSettings settings;
  const _PricingForm({required this.settings});

  @override
  ConsumerState<_PricingForm> createState() => _PricingFormState();
}

class _PricingFormState extends ConsumerState<_PricingForm> {
  late TextEditingController _cool, _pet, _transport, _damage;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _cool = TextEditingController(text: widget.settings.coolPrice.toStringAsFixed(0));
    _pet = TextEditingController(text: widget.settings.petPrice.toStringAsFixed(0));
    _transport = TextEditingController(text: widget.settings.transportFee.toStringAsFixed(0));
    _damage = TextEditingController(text: widget.settings.damageChargePerJar.toStringAsFixed(0));
  }

  @override
  void dispose() { _cool.dispose(); _pet.dispose(); _transport.dispose(); _damage.dispose(); super.dispose(); }

  void _save() {
    ref.read(settingsProvider.notifier).save(widget.settings.copyWith(
      coolPrice: double.tryParse(_cool.text) ?? 60,
      petPrice: double.tryParse(_pet.text) ?? 40,
      transportFee: double.tryParse(_transport.text) ?? 500,
      damageChargePerJar: double.tryParse(_damage.text) ?? 200,
    ));
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Row(children: [
        Expanded(child: _PriceField(
          label: 'Cool Jar Price',
          icon: CoolJarIcon(size: 18, color: AppColors.coolColor(isDark)),
          ctrl: _cool,
        )),
        const SizedBox(width: 12),
        Expanded(child: _PriceField(
          label: 'PET Jar Price',
          icon: PetJarIcon(size: 18, color: AppColors.petColor(isDark)),
          ctrl: _pet,
        )),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _PriceField(label: 'Transport Fee', icon: const Icon(Icons.local_shipping_rounded, size: 18), ctrl: _transport)),
        const SizedBox(width: 12),
        Expanded(child: _PriceField(label: 'Damage/jar', icon: const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger), ctrl: _damage)),
      ]),
      const SizedBox(height: 4),
      _SaveBtn(saved: _saved, onSave: _save),
    ]);
  }
}

class _PriceField extends StatelessWidget {
  final String label;
  final Widget icon;
  final TextEditingController ctrl;
  const _PriceField({required this.label, required this.icon, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label),
      Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        child: Row(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: icon),
          Text('₹ ', style: GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.inkMuted)),
          Expanded(child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero),
          )),
        ]),
      ),
    ]);
  }
}

// ── Inventory Rules Form ──────────────────────────────────────────────────────
class _InventoryForm extends ConsumerStatefulWidget {
  final AppSettings settings;
  const _InventoryForm({required this.settings});

  @override
  ConsumerState<_InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends ConsumerState<_InventoryForm> {
  late int _lowStk, _overdueDays;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _lowStk = widget.settings.lowStockThreshold;
    _overdueDays = widget.settings.overdueDays;
  }

  void _save() {
    ref.read(settingsProvider.notifier).save(widget.settings.copyWith(
      lowStockThreshold: _lowStk, overdueDays: _overdueDays,
    ));
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const FieldLabel('Low Stock Alert Threshold'),
    Text('Alert when jar count drops below:', style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
    const SizedBox(height: 8),
    Row(children: [
      QuantityStepper(value: _lowStk, min: 1, max: 50, onChanged: (v) => setState(() => _lowStk = v)),
      const SizedBox(width: 12),
      Text('jars', style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkMuted)),
    ]),
    const SizedBox(height: 16),
    const FieldLabel('Overdue Return Alert'),
    Text('Flag customers with jars out for more than:', style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
    const SizedBox(height: 8),
    Row(children: [
      QuantityStepper(value: _overdueDays, min: 1, max: 60, onChanged: (v) => setState(() => _overdueDays = v)),
      const SizedBox(width: 12),
      Text('days', style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkMuted)),
    ]),
    const SizedBox(height: 16),
    const _InfoBox(
      title: 'Inventory Sync Logic',
      items: [
        '↓ Delivery: Stock decreases, customer jars increase',
        '↑ Return: Stock increases, customer jars decrease',
        '⚠️ Damage: Permanently removed from total fleet',
        '🔄 Edit/Delete: All changes fully reversed & reapplied',
      ],
    ),
    const SizedBox(height: 4),
    _SaveBtn(saved: _saved, onSave: _save),
  ]);
}

// ── Payment & Sync Form ───────────────────────────────────────────────────────
class _PaymentForm extends ConsumerStatefulWidget {
  final AppSettings settings;
  const _PaymentForm({required this.settings});

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  late bool _autoSync, _audit;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _autoSync = widget.settings.paymentAutoSync;
    _audit = widget.settings.auditLogEnabled;
  }

  void _save() {
    ref.read(settingsProvider.notifier).save(widget.settings.copyWith(
      paymentAutoSync: _autoSync, auditLogEnabled: _audit,
    ));
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Toggle(
      label: 'Auto-sync Payment with Delivery',
      subtitle: 'Automatically calculate billed amount from jar counts and prices',
      value: _autoSync, onChanged: (v) => setState(() => _autoSync = v),
    ),
    _Toggle(
      label: 'Enable Audit Trail',
      subtitle: 'Log every create, edit, and delete with timestamps and before/after values',
      value: _audit, onChanged: (v) => setState(() => _audit = v),
    ),
    const SizedBox(height: 8),
    const _InfoBox(
      title: 'Payment Sync Rules',
      items: [
        'Credit = billed but not collected (shows as "due")',
        'Advance payments reduce customer advance balance',
        'All payment modes supported: Cash, UPI, Advance, Credit',
        'Transaction edit reverses old and applies new values',
      ],
    ),
    const SizedBox(height: 4),
    _SaveBtn(saved: _saved, onSave: _save),
  ]);
}

// ── Theme & UI Form ───────────────────────────────────────────────────────────
class _ThemeForm extends ConsumerStatefulWidget {
  final AppSettings settings;
  const _ThemeForm({required this.settings});

  @override
  ConsumerState<_ThemeForm> createState() => _ThemeFormState();
}

class _ThemeFormState extends ConsumerState<_ThemeForm> {
  late String _themeMode, _accent;
  bool _saved = false;

  // Water-business friendly color themes
  static const _themes = <(String, String, String)>[
    ('1A6BFF', 'Ocean Blue',  '🌊'),
    ('0096C7', 'Sky Blue',    '🌤'),
    ('00B4D8', 'Aqua',        '💧'),
    ('2EC4B6', 'Teal',        '🫧'),
    ('06D6A0', 'Mint',        '🌿'),
    ('0077B6', 'Deep Ocean',  '🌑'),
    ('7B61FF', 'Violet',      '🔮'),
    ('FF8C42', 'Sunset',      '🌅'),
  ];

  @override
  void initState() {
    super.initState();
    _themeMode = widget.settings.themeMode;
    _accent = widget.settings.accentColor;
  }

  void _save() {
    ref.read(settingsProvider.notifier).save(widget.settings.copyWith(
      themeMode: _themeMode, accentColor: _accent,
    ));
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Mode selector ──────────────────────────────────────────────────────
      const FieldLabel('App Theme'),
      Row(children: ['system', 'light', 'dark'].map((m) {
        final active = _themeMode == m;
        final idx = ['system', 'light', 'dark'].indexOf(m);
        final label = switch (m) { 'light' => '☀️ Light', 'dark' => '🌙 Dark', _ => '⚙️ System' };
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _themeMode = m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.only(right: idx < 2 ? 8 : 0),
            height: 46,
            decoration: BoxDecoration(
              color: active ? primary.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? primary : Theme.of(context).dividerColor, width: 1.5),
            ),
            child: Center(child: Text(label,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? primary : AppColors.inkMuted))),
          ),
        ));
      }).toList()),
      const SizedBox(height: 20),

      // ── Color theme picker ─────────────────────────────────────────────────
      Row(children: [
        Text('Colour Theme', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
            color: isDark ? AppColors.inkSoftDark : AppColors.inkSoft)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('💧 Water Palettes',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: primary)),
        ),
      ]),
      const SizedBox(height: 10),
      // 2-column grid of theme cards
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
        children: _themes.map((t) {
          final hex   = t.$1;
          final name  = t.$2;
          final emoji = t.$3;
          final color = Color(int.parse('FF$hex', radix: 16));
          final active = _accent == hex;
          return GestureDetector(
            onTap: () { setState(() => _accent = hex); _save(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: isDark ? 0.22 : 0.10)
                    : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? color : (isDark ? AppColors.separatorDark : AppColors.separator),
                  width: active ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: active
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : Center(child: Text(emoji,
                            style: const TextStyle(fontSize: 13))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(name,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? color : Theme.of(context).colorScheme.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      // Preview strip
      Container(
        height: 10,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Color(int.parse('FF$_accent', radix: 16)),
            Color(int.parse('FF$_accent', radix: 16)).withValues(alpha: 0.4),
          ]),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      const SizedBox(height: 4),
      Center(child: Text('Tap a colour to apply instantly',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted))),
      const SizedBox(height: 16),
      _SaveBtn(saved: _saved, onSave: _save),
    ]);
  }
}

// ── Audit & Data Form ─────────────────────────────────────────────────────────
class _AuditForm extends ConsumerStatefulWidget {
  final AppSettings settings;
  const _AuditForm({required this.settings});

  @override
  ConsumerState<_AuditForm> createState() => _AuditFormState();
}

class _AuditFormState extends ConsumerState<_AuditForm> {
  @override
  Widget build(BuildContext context) {
    final log = ref.watch(auditProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Audit Log (${log.length} entries)',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
        if (log.isNotEmpty)
          GestureDetector(
            onTap: () => ref.read(auditProvider.notifier).clear(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.dangerColor(isDark).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Clear log', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.dangerColor(isDark))),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      if (log.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text('No audit entries yet',
              style: GoogleFonts.inter(color: AppColors.inkMuted))),
        )
      else
        ...log.take(10).map((e) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _AuditChip(type: e.type),
              const Spacer(),
              Text(_fmtTime(e.createdAt),
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.inkMuted)),
            ]),
            const SizedBox(height: 4),
            Text(e.description, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
            if (e.before.isNotEmpty || e.after.isNotEmpty) ...[
              const SizedBox(height: 4),
              if (e.before.isNotEmpty)
                Text('Before: ${e.before}', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.inkMuted)),
              if (e.after.isNotEmpty)
                Text('After: ${e.after}', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.successColor(isDark))),
            ],
          ]),
        )),
    ]);
  }

  String _fmtTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }
}

class _AuditChip extends StatelessWidget {
  final String type;
  const _AuditChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, color) = switch (type) {
      'transaction_created' => ('Created', AppColors.successColor(isDark)),
      'transaction_edited' => ('Edited', AppColors.warningColor(isDark)),
      'transaction_deleted' => ('Deleted', AppColors.dangerColor(isDark)),
      'stock_added' => ('Stock +', AppColors.coolColor(isDark)),
      _ => (type, AppColors.inkMuted),
    };
    return StatusChip(label: label, color: color);
  }
}

// ── Shared form components ────────────────────────────────────────────────────
class _TF extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType? type;
  final String? hint;
  final int maxLines;
  const _TF({required this.label, required this.ctrl, this.type, this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label),
      TextField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
      ),
    ]),
  );
}

class _Toggle extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.label, required this.value, required this.onChanged, this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface)),
        if (subtitle != null)
          Text(subtitle!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted, height: 1.4)),
      ])),
      Switch.adaptive(value: value, onChanged: onChanged,
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          activeTrackColor: Theme.of(context).colorScheme.primary),
    ]),
  );
}

class _SaveBtn extends StatelessWidget {
  final bool saved;
  final VoidCallback onSave;
  const _SaveBtn({required this.saved, required this.onSave});

  @override
  Widget build(BuildContext context) => GradientButton(
    label: saved ? '✅ Saved!' : 'Save Changes',
    onTap: onSave,
    gradient: saved
        ? const LinearGradient(colors: [AppColors.success, AppColors.success])
        : AppColors.primaryGradient,
    height: 44,
  );
}

class _InfoBox extends StatelessWidget {
  final String title;
  final List<String> items;
  const _InfoBox({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 6),
        ...items.map((i) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(i, style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppColors.inkSoftDark : AppColors.inkSoft)),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STAFF FORM  (inside Settings → Staff Access section)
// ══════════════════════════════════════════════════════════════════════════════
class _StaffForm extends ConsumerWidget {
  const _StaffForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff  = ref.watch(staffProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Info banner
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 16, color: primary),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Staff log in with a 4-digit PIN you set. They only see the screens you permit.',
            style: GoogleFonts.inter(fontSize: 12, color: primary, height: 1.4),
          )),
        ]),
      ),
      const SizedBox(height: 14),

      // Add staff button
      GestureDetector(
        onTap: () => showMrSheet(context,
            title: '👷 Add Staff Member',
            builder: (_) => const _StaffEditSheet()),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Row(children: [
            Icon(Icons.person_add_rounded, size: 18, color: primary),
            const SizedBox(width: 10),
            Expanded(child: Text('Add New Staff Member',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: primary))),
            Icon(Icons.add_circle_outline_rounded, size: 18, color: primary),
          ]),
        ),
      ),
      const SizedBox(height: 12),

      // Staff list
      if (staff.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text('No staff added yet',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted))),
        )
      else
        ...staff.map((s) => _StaffCard(member: s, isDark: isDark)),
    ]);
  }
}

class _StaffAccessReadOnly extends ConsumerWidget {
  const _StaffAccessReadOnly();

  static const _permLabels = {
    'dashboard':      '🏠 Dashboard',
    'transactions':   '🚚 Transactions',
    'customers':      '👤 Customers',
    'inventory':      '📦 Inventory',
    'load_unload':    '🔄 Load/Unload',
    'payments':       '💳 Payments',
    'reports':        '📊 Reports',
    'notifications':  '🔔 Notifications',
    'expenses':       '💸 Expenses',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(sessionUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final perms = staff?.permissions ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.16)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your access is read-only.', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: primary)),
          const SizedBox(height: 6),
          Text(
            'Only the owner can add staff or change screen permissions. You can log out to return to the PIN entry screen.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted, height: 1.4),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      Text('Allowed screens', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (perms.isEmpty)
        Text('No screens are enabled for your account. Ask the owner to grant access.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted, height: 1.4))
      else
        Wrap(spacing: 8, runSpacing: 8, children: perms.map((perm) {
          return Chip(
            label: Text(_permLabels[perm] ?? perm, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            backgroundColor: isDark ? AppColors.surface2Dark : AppColors.surface2,
          );
        }).toList()),
      const SizedBox(height: 18),
      Text('Need a change?', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('The owner must sign in using the hidden admin portal and update staff permissions from Settings.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted, height: 1.4)),
    ]);
  }
}

class _StaffCard extends ConsumerWidget {
  final StaffMember member;
  final bool isDark;
  const _StaffCard({required this.member, required this.isDark});

  static const _permLabels = {
    'dashboard':      '🏠 Dashboard',
    'transactions':   '🚚 Transactions',
    'customers':      '👤 Customers',
    'inventory':      '📦 Inventory',
    'load_unload':    '🔄 Load/Unload',
    'payments':       '💳 Payments',
    'reports':        '📊 Reports',
    'notifications':  '🔔 Notifications',
    'expenses':       '💸 Expenses',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final activeC = member.isActive ? AppColors.successColor(isDark) : AppColors.inkMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(
              member.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase(),
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: primary),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
            if (member.phone.isNotEmpty)
              Text(member.phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
          ])),
          // PIN display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface2Dark.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
            ),
            child: Text('PIN ••••',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted)),
          ),
          const SizedBox(width: 8),
          // Active toggle
          GestureDetector(
            onTap: () => ref.read(staffProvider.notifier).update(
                member.copyWith(isActive: !member.isActive)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: activeC.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: activeC.withValues(alpha: 0.3)),
              ),
              child: Text(member.isActive ? 'Active' : 'Disabled',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: activeC)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // Permissions row
        Wrap(spacing: 6, children: member.permissions.map((p) {
          final label = _permLabels[p] ?? p;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Text(label, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: primary)),
          );
        }).toList()),
        const SizedBox(height: 10),
        // Action row
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => showMrSheet(context,
                title: '✏️ Edit Staff',
                builder: (_) => _StaffEditSheet(existing: member)),
            icon: const Icon(Icons.edit_rounded, size: 14),
            label: const Text('Edit'),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(context,
                title: 'Remove ${member.name}?',
                message: 'This staff member will no longer be able to log in.',
                confirmLabel: 'Remove',
              );
              if (ok) ref.read(staffProvider.notifier).remove(member.id);
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 14),
            label: const Text('Remove'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dangerColor(isDark),
              side: BorderSide(color: AppColors.dangerColor(isDark).withValues(alpha: 0.4)),
            ),
          )),
        ]),
      ]),
    );
  }
}

// ── Add / Edit staff sheet ────────────────────────────────────────────────────
class _StaffEditSheet extends ConsumerStatefulWidget {
  final StaffMember? existing;
  const _StaffEditSheet({this.existing});
  @override
  ConsumerState<_StaffEditSheet> createState() => _StaffEditSheetState();
}

class _StaffEditSheetState extends ConsumerState<_StaffEditSheet> {
  final _name  = TextEditingController();
  final _phone = TextEditingController();
  final _pin   = TextEditingController();
  final _pin2  = TextEditingController();
  final List<String> _perms = [];
  bool _showPin = false;

  // Full feature list — id must match StaffGuard permission keys in main_scaffold
  static const _allPerms = <(String, String, String, List<(String, String, String)>?)>[
    ('dashboard',     '🏠 Dashboard',        'Home overview, KPIs and quick stats', null),
    ('transactions',  '🚚 Transactions',      'Add daily deliveries and payments', [
      ('transactions_add', 'Add Transactions', 'Create new deliveries and payments'),
      ('transactions_edit', 'Edit Transactions', 'Modify existing transactions'),
      ('transactions_voice', 'Voice Assistant', 'Use voice commands for transactions'),
    ]),
    ('customers',     '👤 Customers',         'View, add and manage customers', [
      ('customers_add', 'Add Customers', 'Create new customer profiles'),
      ('customers_edit', 'Edit Customers', 'Modify customer information'),
      ('customers_delete', 'Delete Customers', 'Remove customer profiles'),
    ]),
    ('inventory',     '📦 Inventory',         'View current stock levels', null),
    ('load_unload',   '🔄 Load / Unload',     'Warehouse jar in/out movements', [
      ('load_unload_add', 'Add Movements', 'Record jar load/unload operations'),
      ('load_unload_edit', 'Edit Movements', 'Modify existing movements'),
    ]),
    ('payments',      '💳 Payments',          'View and record dues & advances', [
      ('payments_record', 'Record Payments', 'Add new payment entries'),
      ('payments_edit', 'Edit Payments', 'Modify payment records'),
    ]),
    ('expenses',      '💸 Expenses',          'View and add business expenses', [
      ('expenses_add', 'Add Expenses', 'Create new expense entries'),
      ('expenses_edit', 'Edit Expenses', 'Modify expense records'),
    ]),
    ('reports',       '📊 Reports',           'Generate and export reports', null),
    ('notifications', '🔔 Notifications',     'View delivery alerts and reminders', null),
    ('smart_entry',   '📷 Smart Entry',       'OCR photo scan for bulk entry', null),
    ('settings',      '⚙️ Settings',          'App settings and staff management', null),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _name.text  = e.name;
      _phone.text = e.phone;
      // If this record already uses a hashed PIN, do NOT pre-fill the plain-text
      // pin field — the hash is not reversible. Leave _pin and _pin2 blank so the
      // owner must consciously re-enter a PIN to change it. If left blank on save,
      // the existing hash is preserved unchanged.
      if (!e.hasPinHash) {
        _pin.text  = e.pin;
        _pin2.text = e.pin;
      }
      _perms.addAll(e.permissions);
    } else {
      _perms.addAll(['dashboard', 'transactions', 'transactions_add', 'transactions_voice', 'customers', 'customers_add', 'load_unload', 'load_unload_add']);
    }
  }

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _pin.dispose(); _pin2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final isEdit  = widget.existing != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Name
      const FieldLabel('Staff Name *'),
      TextField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. Ramesh Kumar')),
      const SizedBox(height: 12),

      // Phone
      const FieldLabel('Phone (optional)'),
      TextField(controller: _phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '10-digit mobile')),
      const SizedBox(height: 12),

      // PIN
      FieldLabel(isEdit && widget.existing!.hasPinHash
          ? '4–6 Digit PIN  (leave blank to keep existing)'
          : '4–6 Digit PIN *'),
      Row(children: [
        Expanded(child: TextField(
          controller: _pin,
          obscureText: !_showPin,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: isEdit && widget.existing!.hasPinHash ? '(unchanged)' : '••••',
            counterText: '',
            suffixIcon: IconButton(
              icon: Icon(_showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
              onPressed: () => setState(() => _showPin = !_showPin),
            ),
          ),
        )),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: _pin2,
          obscureText: !_showPin,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: isEdit && widget.existing!.hasPinHash ? '(unchanged)' : 'Confirm PIN',
            counterText: '',
          ),
        )),
      ]),
      const SizedBox(height: 16),

      // Permissions
      const FieldLabel('Permissions'),
      const SizedBox(height: 8),
      ..._allPerms.map((rec) {
        final (id, label, desc, subPerms) = rec;
        final on = _perms.contains(id);
        return Column(children: [
          GestureDetector(
            onTap: () => setState(() => on ? _perms.remove(id) : _perms.add(id)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: on ? primary.withValues(alpha: 0.08) : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: on ? primary : (isDark ? AppColors.separatorDark : AppColors.separator),
                  width: on ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Text(label.split(' ').first, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label.split(' ').skip(1).join(' '),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                          color: on ? primary : Theme.of(context).colorScheme.onSurface)),
                  Text(desc, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
                ])),
                Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 20, color: on ? primary : AppColors.inkMuted),
              ]),
            ),
          ),
          // Sub-permissions
          if (on && subPerms != null && subPerms.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 24, bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sub-features:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                const SizedBox(height: 8),
                ...subPerms.map((sub) {
                  final (subId, subLabel, subDesc) = sub;
                  final subOn = _perms.contains(subId);
                  return GestureDetector(
                    onTap: () => setState(() => subOn ? _perms.remove(subId) : _perms.add(subId)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: subOn ? primary.withValues(alpha: 0.06) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        Icon(subOn ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 16, color: subOn ? primary : AppColors.inkMuted),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(subLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                              color: subOn ? primary : Theme.of(context).colorScheme.onSurface)),
                          Text(subDesc, style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted)),
                        ])),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
        ]);
      }),
      const SizedBox(height: 20),

      GradientButton(
        label: isEdit ? '✅ Save Changes' : '👷 Add Staff Member',
        onTap: () {
          final name     = _name.text.trim();
          final pinInput = _pin.text.trim();
          final existing = widget.existing;
          final isEdit   = existing != null;

          // ── Validate name ────────────────────────────────────────────────
          if (name.isEmpty) { showToast(context, 'Enter staff name', error: true); return; }

          // ── Validate permissions ─────────────────────────────────────────
          if (_perms.isEmpty) { showToast(context, 'Select at least one permission', error: true); return; }

          // ── PIN handling ─────────────────────────────────────────────────
          // On edit: if PIN fields are blank AND the record already has a hash,
          // keep the existing hash/salt unchanged.
          final keepExistingPin = isEdit && existing.hasPinHash && pinInput.isEmpty;

          if (!keepExistingPin) {
            // New staff OR owner is setting/changing the PIN
            final pinErr = PinHashUtil.validate(pinInput);
            if (pinErr != null) { showToast(context, pinErr, error: true); return; }
            if (pinInput != _pin2.text) { showToast(context, 'PINs do not match', error: true); return; }
          }

          // ── Build the StaffMember ────────────────────────────────────────
          final memberId = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

          final String newPinHash;
          final String newPinSalt;
          final String newPin;  // kept for legacy fallback reads; set to '' after hashing

          if (keepExistingPin) {
            // Preserve existing hash — no PIN change
            newPinHash = existing.pinHash;
            newPinSalt = existing.pinSalt;
            newPin     = existing.pin;  // preserve legacy field if it exists
          } else {
            // Hash the new PIN using the member's ID as salt
            newPinSalt = memberId;
            newPinHash = PinHashUtil.hash(pin: pinInput, salt: newPinSalt);
            newPin     = '';  // clear plain-text field after hashing
          }

          final member = StaffMember(
            id:          memberId,
            name:        name,
            phone:       _phone.text.trim(),
            pin:         newPin,
            permissions: List.from(_perms),
            pinHash:     newPinHash,
            pinSalt:     newPinSalt,
          );

          if (isEdit) {
            ref.read(staffProvider.notifier).update(member);
          } else {
            ref.read(staffProvider.notifier).add(member);
          }
          Navigator.pop(context);
          showToast(context, isEdit ? '✅ Staff updated' : '✅ Staff added', success: true);
        },
      ),
    ]);
  }
}

// ── Diagnostics section launcher ─────────────────────────────────────────────
class _DiagnosticsLauncher extends StatelessWidget {
  const _DiagnosticsLauncher();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Run read/write tests on every Firebase RTDB node. Checks connectivity, permissions, and latency for all 14 nodes.',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.5),
      ),
      const SizedBox(height: 14),
      Row(children: [
        const Icon(Icons.storage_rounded, size: 13, color: AppColors.inkMuted),
        const SizedBox(width: 6),
        Expanded(child: Text(
          'mrwaterprov1-54c3f · Firebase RTDB',
          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.inkMuted),
        )),
      ]),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FirebaseDiagnosticsScreen())),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text('Open Diagnostics',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ]);
  }
}
