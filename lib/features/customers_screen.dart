import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/app_state.dart';
import 'ledger_screen.dart';
import 'transactions_screen.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustScreenState();
}

class _CustScreenState extends ConsumerState<CustomersScreen> {
  String _search = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final custs = ref.watch(customersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final list = custs.where((c) {
      final ms = c.name.toLowerCase().contains(_search.toLowerCase()) ||
          c.phone.contains(_search) || c.area.toLowerCase().contains(_search.toLowerCase());
      final mf = switch (_filter) {
        'Active' => c.isActive,
        'Jars Out' => c.hasJarsOut,
        'Has Dues' => c.hasDues,
        'Has Advance' => c.hasAdvance,
        _ => true,
      };
      return ms && mf;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Customers', style: Theme.of(context).textTheme.headlineLarge)),
              GestureDetector(
                onTap: () => showMrSheet(context, title: 'Add Customer', builder: (_) => const AddCustForm()),
                child: Container(
                  height: 40, 
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_rounded, 
                        color: Theme.of(context).colorScheme.primary, size: 18),
                    const SizedBox(width: 6),
                    Text('Add Customer', 
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary)),
                  ]),
                ),
              ),
            ]),
            Text('${list.length} customers', style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
            const SizedBox(height: 10),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
              ),
              child: Row(children: [
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.search_rounded, color: AppColors.inkMuted, size: 18)),
                Expanded(child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Name, phone, area...',
                    border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
                    hintStyle: GoogleFonts.inter(color: AppColors.inkMuted),
                  ),
                )),
              ]),
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: ['All', 'Active', 'Jars Out', 'Has Dues', 'Has Advance'].map((f) {
            final active = f == _filter;
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.separatorDark : AppColors.separator), width: 1.5),
                ),
                child: Text(f, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                    color: active ? Theme.of(context).colorScheme.primary : AppColors.inkMuted)),
              ),
            );
          }).toList()),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(transactionsProvider.notifier).refreshAll(ref),
            child: list.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(height: 300, child: Center(
                      child: Text('No customers found',
                          style: GoogleFonts.inter(color: AppColors.inkMuted)),
                    )),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => CustCard(
                      customer: list[i],
                      isDark: isDark,
                      onTap: () => showMrSheet(ctx, title: list[i].name,
                          builder: (_) => CustDetail(customer: list[i])),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class CustCard extends StatelessWidget {
  final Customer customer;
  final bool isDark;
  final VoidCallback onTap;
  const CustCard({super.key, required this.customer, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      onTap: onTap,
      child: Row(children: [
        CustomerAvatar(initials: customer.initials, size: 44),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customer.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          Text('+91 ${customer.phone} · ${customer.area}',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (customer.coolOut > 0) JarBadge(type: 'cool', delivered: customer.coolOut, returned: 0),
            if (customer.petOut > 0) JarBadge(type: 'pet', delivered: customer.petOut, returned: 0),
            if (customer.advanceBalance > 0)
              StatusChip(label: '+₹${customer.advanceBalance.toInt()} adv', color: AppColors.successColor(isDark)),
            if (customer.ledgerBalance < 0)
              StatusChip(label: '₹${customer.ledgerBalance.abs().toInt()} due', color: AppColors.dangerColor(isDark)),
          ]),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted, size: 18),
      ]),
    ),
  );
}

class CustDetail extends ConsumerWidget {
  final Customer customer;
  const CustDetail({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = ref.watch(customersProvider).firstWhere((x) => x.id == customer.id, orElse: () => customer);
    final txns = ref.watch(transactionsProvider).where((t) => t.customerId == c.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header ──────────────────────────────────────────────────────────────
      Row(children: [
        CustomerAvatar(initials: c.initials, size: 52),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.name, style: Theme.of(context).textTheme.headlineMedium),
          Text(c.area.isNotEmpty ? c.area : 'No area set',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
          Text('+91 ${c.phone}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.inkMuted)),
        ])),
        // Edit button
        GestureDetector(
          onTap: () => showMrSheet(context,
              title: '✏️ Edit Customer', builder: (_) => EditCustForm(customer: c)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 5),
              Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 16),

      // ── Financial & Jar Status ────────────────────────────────────────────
      Row(children: [
        StBox(
          'Advance',
          '+₹${c.advanceBalance.toInt()}',
          AppColors.successColor(isDark),
        ),
        const SizedBox(width: 8),
        StBox(
          'Dues',
          c.ledgerBalance < 0 ? '-₹${c.ledgerBalance.abs().toInt()}' : '₹0',
          c.ledgerBalance < 0 ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark),
        ),
        if (c.securityDeposit > 0) ...[
          const SizedBox(width: 8),
          StBox('Deposit', '₹${c.securityDeposit.toInt()}', AppColors.warningColor(isDark)),
        ],
      ]),
      const SizedBox(height: 8),

      // ── Jars with Customer ────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('JARS WITH CUSTOMER', style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: AppColors.inkMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(children: [
            _JarStatusTile(
              icon: CoolJarIcon(size: 18, color: AppColors.coolColor(isDark)),
              label: 'Cool Jars',
              count: c.coolOut,
              ownCount: c.ownCoolJars,
              color: AppColors.coolColor(isDark),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _JarStatusTile(
              icon: PetJarIcon(size: 18, color: AppColors.petColor(isDark)),
              label: 'PET Jars',
              count: c.petOut,
              ownCount: c.ownPetJars,
              color: AppColors.petColor(isDark),
              isDark: isDark,
            ),
          ]),
          if (c.coolPriceOverride != null || c.petPriceOverride != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (c.coolPriceOverride != null)
                _PriceBadge('Cool Price', c.coolPriceOverride!, isDark),
              if (c.petPriceOverride != null)
                _PriceBadge('PET Price', c.petPriceOverride!, isDark),
            ]),
          ],
          if (c.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.notes_rounded, size: 12, color: AppColors.inkMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(c.notes,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted))),
            ]),
          ],
        ]),
      ),

      // ── Recent Transactions ───────────────────────────────────────────────
      const SectionHeader(title: 'Recent Transactions'),
      if (txns.isEmpty)
        Text('No transactions yet', style: GoogleFonts.inter(color: AppColors.inkMuted))
      else
        ...txns.take(5).map((t) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: isDark ? AppColors.surface2Dark : AppColors.surface2,
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.date, style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
              Wrap(spacing: 4, children: [
                if (t.coolDelivered > 0 || t.coolReturned > 0)
                  JarBadge(type: 'cool', delivered: t.coolDelivered, returned: t.coolReturned),
                if (t.petDelivered > 0 || t.petReturned > 0)
                  JarBadge(type: 'pet', delivered: t.petDelivered, returned: t.petReturned),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // For pure payments show amountCollected, for deliveries show billedAmount
              Text(
                t.billedAmount == 0 && t.amountCollected > 0
                    ? '₹${t.amountCollected.toInt()}'
                    : '₹${t.billedAmount.toInt()}',
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(t.paymentMode, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
            ]),
          ]),
        )),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: GradientButton(
          label: '⚡ New Transaction',
          onTap: () {
            // Pre-select the customer so DeliveryForm/EventForm auto-fills it
            ref.read(selectedCustomerForTxnProvider.notifier).state = c;
            // Open the quick action sheet — same as dashboard + FAB
            showMrSheet(context,
              title: '⚡ New Transaction — ${c.name}',
              builder: (_) => _CustomerQuickSheet(isDark: isDark),
            );
          },
          height: 44,
        )),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: () => showMrSheet(context,
            title: '📒 Ledger — ${c.name}',
            builder: (_) => ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: LedgerScreen(customerId: c.id),
            ),
          ),
          icon: const Icon(Icons.receipt_long_rounded, size: 16),
          label: const Text('View Ledger'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        )),
      ]),
    ]);
  }
}

class _JarStatusTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final int count, ownCount;
  final Color color;
  final bool isDark;
  const _JarStatusTile({required this.icon, required this.label, required this.count,
      required this.ownCount, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: count > 0 ? color.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: count > 0 ? color.withValues(alpha: 0.2) : AppColors.separatorDark.withValues(alpha: 0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        icon, const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
            color: count > 0 ? color : AppColors.inkMuted)),
      ]),
      const SizedBox(height: 6),
      Text('$count with customer', style: GoogleFonts.jetBrainsMono(fontSize: 13,
          fontWeight: FontWeight.w700, color: count > 0 ? color : AppColors.inkMuted)),
      if (ownCount > 0)
        Text('+ $ownCount own jars', style: GoogleFonts.inter(fontSize: 10,
            color: AppColors.inkMuted, fontStyle: FontStyle.italic)),
    ]),
  ));
}

class _PriceBadge extends StatelessWidget {
  final String label;
  final double price;
  final bool isDark;
  const _PriceBadge(this.label, this.price, this.isDark);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.warningColor(isDark).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.warningColor(isDark).withValues(alpha: 0.25)),
    ),
    child: Text('$label: ₹${price.toInt()}',
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
            color: AppColors.warningColor(isDark))),
  );
}

class StBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const StBox(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
    ]),
  ));
}

class AddCustForm extends ConsumerStatefulWidget {
  const AddCustForm({super.key});
  @override
  ConsumerState<AddCustForm> createState() => _AddCustFormState();
}

class _AddCustFormState extends ConsumerState<AddCustForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _addr = TextEditingController();

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _area.dispose(); _addr.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const FieldLabel('Full Name *'),
      TextFormField(
        controller: _name,
        decoration: const InputDecoration(hintText: 'e.g. Rajesh Kumar'),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Please enter a name';
          if (v.trim().length < 3) return 'Name must be at least 3 characters';
          return null;
        },
      ),
      const SizedBox(height: 12),
      const FieldLabel('Mobile Number *'),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(hintText: '9876543210', prefixText: '+91 '),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Please enter a phone number';
          if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) return 'Enter a valid 10-digit number';
          return null;
        },
      ),
      const SizedBox(height: 12),
      const FieldLabel('Area / Route'),
      TextFormField(controller: _area, decoration: const InputDecoration(hintText: 'Koregaon Park')),
      const SizedBox(height: 12),
      const FieldLabel('Address'),
      TextFormField(controller: _addr, maxLines: 2, decoration: const InputDecoration(hintText: '12 Rose Apartments...')),
      const SizedBox(height: 24),
      GradientButton(
        label: 'Save Customer',
        onTap: () {
          if (_formKey.currentState!.validate()) {
            ref.read(customersProvider.notifier).add(Customer(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _name.text.trim(), phone: _phone.text.trim(),
              area: _area.text.trim(), address: _addr.text.trim(),
              createdAt: DateTime.now().toIso8601String(),
            ));
            Navigator.pop(context);
            showToast(context, '✅ Customer added', success: true);
          }
        },
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// EDIT CUSTOMER FORM
// Comprehensive editing: profile, jars with them, financials, pricing, notes
// ══════════════════════════════════════════════════════════════════════════════
class EditCustForm extends ConsumerStatefulWidget {
  final Customer customer;
  const EditCustForm({super.key, required this.customer});
  @override
  ConsumerState<EditCustForm> createState() => _EditCustFormState();
}

class _EditCustFormState extends ConsumerState<EditCustForm> {
  final _formKey = GlobalKey<FormState>();

  // Basic info
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _area;
  late final TextEditingController _addr;
  late final TextEditingController _notes;

  // Financials
  late final TextEditingController _secDeposit;
  late final TextEditingController _balance; // positive = advance, negative = dues
  String _balanceType = 'advance'; // 'advance' | 'dues' | 'zero'

  // Jar counts (with customer, from owner's stock)
  late int _coolOut;
  late int _petOut;
  // Customer's own jars (not from owner's stock)
  late int _ownCool;
  late int _ownPet;

  // Pricing overrides
  bool _hasCoolOverride = false;
  bool _hasPetOverride = false;
  late final TextEditingController _coolPrice;
  late final TextEditingController _petPrice;

  // Status
  late bool _isActive;

  // Whether jar count was changed (affects inventory)
  bool get _jarsChanged => _coolOut != widget.customer.coolOut || _petOut != widget.customer.petOut;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _name = TextEditingController(text: c.name);
    _phone = TextEditingController(text: c.phone);
    _area = TextEditingController(text: c.area);
    _addr = TextEditingController(text: c.address);
    _notes = TextEditingController(text: c.notes);
    _secDeposit = TextEditingController(
        text: c.securityDeposit > 0 ? c.securityDeposit.toInt().toString() : '');
    _coolOut = c.coolOut;
    _petOut = c.petOut;
    _ownCool = c.ownCoolJars;
    _ownPet = c.ownPetJars;
    _isActive = c.isActive;

    // Determine balance type
    if (c.balance > 0) {
      _balanceType = 'advance';
      _balance = TextEditingController(text: c.balance.toInt().toString());
    } else if (c.balance < 0) {
      _balanceType = 'dues';
      _balance = TextEditingController(text: c.balance.abs().toInt().toString());
    } else {
      _balanceType = 'zero';
      _balance = TextEditingController(text: '0');
    }

    // Price overrides
    _hasCoolOverride = c.coolPriceOverride != null;
    _hasPetOverride = c.petPriceOverride != null;
    final defSettings = ref.read(settingsProvider);
    _coolPrice = TextEditingController(
        text: (c.coolPriceOverride ?? defSettings.coolPrice).toInt().toString());
    _petPrice = TextEditingController(
        text: (c.petPriceOverride ?? defSettings.petPrice).toInt().toString());
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _area.dispose(); _addr.dispose();
    _notes.dispose(); _secDeposit.dispose(); _balance.dispose();
    _coolPrice.dispose(); _petPrice.dispose();
    super.dispose();
  }

  double get _finalBalance {
    final amt = double.tryParse(_balance.text) ?? 0;
    return switch (_balanceType) {
      'advance' => amt,
      'dues' => -amt,
      _ => 0,
    };
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final inv = ref.read(inventoryProvider);
    final oldCoolOut = widget.customer.coolOut;
    final oldPetOut = widget.customer.petOut;
    final coolDelta = _coolOut - oldCoolOut; // positive = more jars now with cust (reduces stock)
    final petDelta = _petOut - oldPetOut;

    // Validate inventory won't go negative
    if (coolDelta > 0 && inv.coolStock < coolDelta) {
      showToast(context, 'Not enough Cool jars in warehouse (${inv.coolStock} available)', error: true);
      return;
    }
    if (petDelta > 0 && inv.petStock < petDelta) {
      showToast(context, 'Not enough PET jars in warehouse (${inv.petStock} available)', error: true);
      return;
    }

    final updated = widget.customer.copyWith(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      area: _area.text.trim(),
      address: _addr.text.trim(),
      notes: _notes.text.trim(),
      isActive: _isActive,
      balance: _finalBalance,
      coolOut: _coolOut,
      petOut: _petOut,
      ownCoolJars: _ownCool,
      ownPetJars: _ownPet,
      securityDeposit: double.tryParse(_secDeposit.text) ?? 0,
      coolPriceOverride: _hasCoolOverride ? (double.tryParse(_coolPrice.text)) : null,
      petPriceOverride: _hasPetOverride ? (double.tryParse(_petPrice.text)) : null,
    );

    ref.read(customersProvider.notifier).update(updated);

    // Adjust inventory if jar count changed (manual correction)
    if (_jarsChanged) {
      if (coolDelta != 0 || petDelta != 0) {
        // coolDelta > 0 means more jars with customer → reduce warehouse stock
        ref.read(inventoryProvider.notifier).adjustForCustomerEdit(coolDelta, petDelta);
      }
    }

    Navigator.pop(context);
    showToast(context, '✅ Customer updated', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = ref.watch(inventoryProvider);
    final s = ref.watch(settingsProvider);

    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Basic Info ─────────────────────────────────────────────────────
        const _SectionDivider(label: 'Basic Info', icon: Icons.person_rounded),
        const FieldLabel('Full Name *'),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(hintText: 'e.g. Rajesh Kumar'),
          validator: (v) => (v == null || v.trim().length < 3) ? 'At least 3 characters' : null,
        ),
        const SizedBox(height: 12),
        const FieldLabel('Mobile Number *'),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '9876543210', prefixText: '+91 '),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) return 'Enter valid 10-digit number';
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('Area / Route'),
            TextFormField(controller: _area, decoration: const InputDecoration(hintText: 'Koregaon Park')),
          ])),
        ]),
        const SizedBox(height: 12),
        const FieldLabel('Address'),
        TextFormField(controller: _addr, maxLines: 2,
            decoration: const InputDecoration(hintText: '12 Rose Apartments...')),

        // ── Active Status ──────────────────────────────────────────────────
        const SizedBox(height: 16),
        _StatusToggle(
          isActive: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
          isDark: isDark,
        ),

        // ── Jars With Customer (Owner's Stock) ─────────────────────────────
        const _SectionDivider(label: 'Your Jars With Customer', icon: Icons.inventory_2_rounded),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'These are jars from your warehouse currently with this customer. '
              'Changing these numbers adjusts your warehouse stock accordingly.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            _JarCountRow(
              icon: CoolJarIcon(size: 20, color: AppColors.coolColor(isDark)),
              label: 'Cool Jars with customer',
              count: _coolOut,
              maxAdd: _coolOut + inv.coolStock, // can increase up to available stock
              color: AppColors.coolColor(isDark),
              isDark: isDark,
              onChanged: (v) => setState(() => _coolOut = v),
            ),
            const SizedBox(height: 12),
            _JarCountRow(
              icon: PetJarIcon(size: 20, color: AppColors.petColor(isDark)),
              label: 'PET Jars with customer',
              count: _petOut,
              maxAdd: _petOut + inv.petStock,
              color: AppColors.petColor(isDark),
              isDark: isDark,
              onChanged: (v) => setState(() => _petOut = v),
            ),
            if (_jarsChanged) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningColor(isDark).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warningColor(isDark).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warningColor(isDark)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Warehouse stock will be adjusted: '
                    'Cool ${_coolOut - widget.customer.coolOut >= 0 ? "−${_coolOut - widget.customer.coolOut}" : "+${(widget.customer.coolOut - _coolOut)}"}, '
                    'PET ${_petOut - widget.customer.petOut >= 0 ? "−${_petOut - widget.customer.petOut}" : "+${(widget.customer.petOut - _petOut)}"}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.warningColor(isDark)),
                  )),
                ]),
              ),
            ],
          ]),
        ),

        // ── Customer's Own Jars ────────────────────────────────────────────
        const _SectionDivider(label: "Customer's Own Jars", icon: Icons.business_center_rounded),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Jars the customer owns themselves (not from your inventory). '
              'For reference only — does not affect your stock.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _OwnJarCounter(
                icon: CoolJarIcon(size: 18, color: AppColors.coolColor(isDark)),
                label: 'Own Cool',
                count: _ownCool,
                color: AppColors.coolColor(isDark),
                onChanged: (v) => setState(() => _ownCool = v),
              )),
              const SizedBox(width: 12),
              Expanded(child: _OwnJarCounter(
                icon: PetJarIcon(size: 18, color: AppColors.petColor(isDark)),
                label: 'Own PET',
                count: _ownPet,
                color: AppColors.petColor(isDark),
                onChanged: (v) => setState(() => _ownPet = v),
              )),
            ]),
          ]),
        ),

        // ── Financials ─────────────────────────────────────────────────────
        const _SectionDivider(label: 'Financials', icon: Icons.account_balance_wallet_rounded),

        // Balance (advance/dues)
        const FieldLabel('Opening Balance'),
        _BalanceField(
          type: _balanceType,
          ctrl: _balance,
          isDark: isDark,
          onTypeChanged: (t) => setState(() => _balanceType = t),
        ),
        const SizedBox(height: 12),

        // Security Deposit
        const FieldLabel('Security Deposit', hint: '(refundable, for records only)'),
        TextFormField(
          controller: _secDeposit,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '0', prefixText: '₹ '),
        ),

        // ── Custom Pricing ─────────────────────────────────────────────────
        const _SectionDivider(label: 'Custom Pricing', icon: Icons.sell_rounded),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            _PriceOverrideRow(
              icon: CoolJarIcon(size: 16, color: AppColors.coolColor(isDark)),
              label: 'Cool Jar',
              defaultPrice: s.coolPrice,
              enabled: _hasCoolOverride,
              ctrl: _coolPrice,
              color: AppColors.coolColor(isDark),
              isDark: isDark,
              onToggle: (v) => setState(() {
                _hasCoolOverride = v;
                if (!v) _coolPrice.text = s.coolPrice.toInt().toString();
              }),
            ),
            const SizedBox(height: 10),
            _PriceOverrideRow(
              icon: PetJarIcon(size: 16, color: AppColors.petColor(isDark)),
              label: 'PET Jar',
              defaultPrice: s.petPrice,
              enabled: _hasPetOverride,
              ctrl: _petPrice,
              color: AppColors.petColor(isDark),
              isDark: isDark,
              onToggle: (v) => setState(() {
                _hasPetOverride = v;
                if (!v) _petPrice.text = s.petPrice.toInt().toString();
              }),
            ),
          ]),
        ),

        // ── Notes ──────────────────────────────────────────────────────────
        const _SectionDivider(label: 'Notes', icon: Icons.notes_rounded),
        TextFormField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Any notes about this customer...'),
        ),
        const SizedBox(height: 28),

        // ── Save ───────────────────────────────────────────────────────────
        GradientButton(label: 'Save Changes', onTap: _save),
        const SizedBox(height: 16),

        // Deactivate / Reactivate
        GestureDetector(
          onTap: () async {
            final label = _isActive ? 'deactivate' : 'reactivate';
            final ok = await confirmDialog(context,
              title: '${_isActive ? 'Deactivate' : 'Reactivate'} Customer?',
              message: _isActive
                  ? 'This customer will be hidden from active lists but their history is preserved.'
                  : 'This customer will be moved back to active status.',
              confirmLabel: label[0].toUpperCase() + label.substring(1),
              color: _isActive ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark),
            );
            if (ok && mounted) {
              setState(() => _isActive = !_isActive);
            }
          },
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: _isActive
                  ? AppColors.dangerColor(isDark).withValues(alpha: 0.4)
                  : AppColors.successColor(isDark).withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(
              _isActive ? 'Deactivate Customer' : 'Reactivate Customer',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                  color: _isActive ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark)),
            )),
          ),
        ),
      ]),
    );
  }
}

// ── Section Divider ───────────────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionDivider({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(children: [
      Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 7),
      Text(label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.6, color: Theme.of(context).colorScheme.primary)),
      const SizedBox(width: 10),
      Expanded(child: Divider(height: 1, color: Theme.of(context).dividerColor)),
    ]),
  );
}

// ── Status Toggle ─────────────────────────────────────────────────────────────
class _StatusToggle extends StatelessWidget {
  final bool isActive;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  const _StatusToggle({required this.isActive, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: (isActive ? AppColors.successColor(isDark) : AppColors.dangerColor(isDark))
          .withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (isActive
          ? AppColors.successColor(isDark) : AppColors.dangerColor(isDark)).withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      Icon(isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 18, color: isActive ? AppColors.successColor(isDark) : AppColors.dangerColor(isDark)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isActive ? 'Active Customer' : 'Inactive Customer',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                color: isActive ? AppColors.successColor(isDark) : AppColors.dangerColor(isDark))),
        Text(isActive ? 'Appears in all lists & transactions' : 'Hidden from active lists',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
      ])),
      Switch(value: isActive, onChanged: onChanged),
    ]),
  );
}

// ── Jar Count Row (for editing owner-tracked jars) ────────────────────────────
class _JarCountRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final int count, maxAdd;
  final Color color;
  final bool isDark;
  final ValueChanged<int> onChanged;
  const _JarCountRow({required this.icon, required this.label, required this.count,
      required this.maxAdd, required this.color, required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    icon, const SizedBox(width: 10),
    Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13,
        fontWeight: FontWeight.w600, color: AppColors.inkMuted))),
    QuantityStepper(
      value: count,
      min: 0,
      max: maxAdd,
      onChanged: onChanged,
      activeColor: color,
      size: 36,
    ),
  ]);
}

// ── Own Jar Counter ────────────────────────────────────────────────────────────
class _OwnJarCounter extends StatelessWidget {
  final Widget icon;
  final String label;
  final int count;
  final Color color;
  final ValueChanged<int> onChanged;
  const _OwnJarCounter({required this.icon, required this.label, required this.count,
      required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        icon, const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.inkMuted)),
      ]),
      const SizedBox(height: 8),
      QuantityStepper(value: count, min: 0, max: 99, onChanged: onChanged,
          activeColor: color, size: 34),
    ]),
  );
}

// ── Balance Field (Advance / Dues / Zero) ─────────────────────────────────────
class _BalanceField extends StatelessWidget {
  final String type;
  final TextEditingController ctrl;
  final bool isDark;
  final ValueChanged<String> onTypeChanged;
  const _BalanceField({required this.type, required this.ctrl,
      required this.isDark, required this.onTypeChanged});

  @override
  Widget build(BuildContext context) {
    final Color activeColor = switch (type) {
      'advance' => AppColors.successColor(isDark),
      'dues' => AppColors.dangerColor(isDark),
      _ => AppColors.inkMuted,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Type selector
      Row(children: [
        _BalanceTypeChip(label: 'No Balance', value: 'zero', selected: type, isDark: isDark,
            color: AppColors.inkMuted, onTap: () => onTypeChanged('zero')),
        const SizedBox(width: 8),
        _BalanceTypeChip(label: '💳 Advance', value: 'advance', selected: type, isDark: isDark,
            color: AppColors.successColor(isDark), onTap: () => onTypeChanged('advance')),
        const SizedBox(width: 8),
        _BalanceTypeChip(label: '📋 Dues', value: 'dues', selected: type, isDark: isDark,
            color: AppColors.dangerColor(isDark), onTap: () => onTypeChanged('dues')),
      ]),
      if (type != 'zero') ...[
        const SizedBox(height: 10),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w700,
              color: activeColor),
          decoration: InputDecoration(
            hintText: '0',
            prefixText: type == 'dues' ? '−₹ ' : '+₹ ',
            prefixStyle: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, color: activeColor),
          ),
          validator: (v) {
            if (type != 'zero' && (v == null || v.trim().isEmpty)) return 'Enter amount';
            return null;
          },
        ),
        const SizedBox(height: 6),
        Text(
          type == 'advance'
              ? 'Customer has paid ahead — will be auto-deducted in next transaction'
              : 'Customer owes this amount — visible as pending due',
          style: GoogleFonts.inter(fontSize: 11, color: activeColor.withValues(alpha: 0.8)),
        ),
      ],
    ]);
  }
}

class _BalanceTypeChip extends StatelessWidget {
  final String label, value, selected;
  final bool isDark;
  final Color color;
  final VoidCallback onTap;
  const _BalanceTypeChip({required this.label, required this.value, required this.selected,
      required this.isDark, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : (isDark ? AppColors.separatorDark : AppColors.separator),
              width: 1.5),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? color : AppColors.inkMuted)),
      ),
    );
  }
}

// ── Price Override Row ─────────────────────────────────────────────────────────
class _PriceOverrideRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final double defaultPrice;
  final bool enabled, isDark;
  final TextEditingController ctrl;
  final Color color;
  final ValueChanged<bool> onToggle;
  const _PriceOverrideRow({required this.icon, required this.label, required this.defaultPrice,
      required this.enabled, required this.ctrl, required this.color,
      required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) => Row(children: [
    icon, const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
      Text(enabled ? 'Custom price active' : 'Using default ₹${defaultPrice.toInt()}',
          style: GoogleFonts.inter(fontSize: 11, color: enabled ? color : AppColors.inkMuted)),
    ])),
    if (enabled)
      SizedBox(width: 90, child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: color),
        decoration: InputDecoration(
          prefixText: '₹',
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          prefixStyle: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, color: color),
        ),
      )),
    const SizedBox(width: 10),
    Switch(
      value: enabled,
      onChanged: onToggle,
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? color : null),
    ),
  ]);
}



// ══════════════════════════════════════════════════════════════════════════════
// CUSTOMER QUICK SHEET
// Same options as dashboard FAB — Delivery / Event / Return / Payment.
// Customer is pre-set in selectedCustomerForTxnProvider before this opens,
// so DeliveryForm / EventForm auto-fill the customer field.
// ══════════════════════════════════════════════════════════════════════════════
class _CustomerQuickSheet extends ConsumerWidget {
  final bool isDark;
  const _CustomerQuickSheet({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coolC = AppColors.coolColor(isDark);
    final okC   = AppColors.successColor(isDark);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      _qBtn(
        icon: Icons.local_shipping_rounded,
        label: 'New Delivery',
        sublabel: 'Door-to-door jar delivery',
        color: coolC, isDark: isDark,
        onTap: () {
          Navigator.pop(context);
          showMrSheet(context, title: '🚚 New Delivery',
              builder: (_) => const DeliveryForm());
        },
      ),
      const SizedBox(height: 10),
      _qBtn(
        icon: Icons.celebration_rounded,
        label: 'New Event',
        sublabel: 'Bulk / one-off event order',
        color: AppColors.purple, isDark: isDark,
        onTap: () {
          Navigator.pop(context);
          showMrSheet(context, title: '🎉 New Event',
              builder: (_) => const EventForm());
        },
      ),
      const SizedBox(height: 10),
      _qBtn(
        icon: Icons.undo_rounded,
        label: 'Return Jars',
        sublabel: 'Collect jars back from customer',
        color: AppColors.inkMuted, isDark: isDark,
        onTap: () {
          Navigator.pop(context);
          showMrSheet(context, title: '📦 Return Jars',
              builder: (_) => const ReturnJarForm());
        },
      ),
      const SizedBox(height: 10),
      _qBtn(
        icon: Icons.payments_rounded,
        label: 'Record Payment',
        sublabel: 'Settle dues or add advance',
        color: okC, isDark: isDark,
        onTap: () {
          Navigator.pop(context);
          showMrSheet(context, title: '💰 Record Payment',
              builder: (_) => const PaymentForm());
        },
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _qBtn({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
              Text(sublabel, style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.inkMuted)),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ]),
        ),
      );
}
