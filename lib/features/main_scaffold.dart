import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/app_state.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'customers_screen.dart';
import 'inventory_screen.dart';
import 'load_unload_screen.dart';
import 'payments_screen.dart';
import 'expenses_screen.dart';
import 'smart_entry_screen.dart';
import 'reports_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'modern_app_logo.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ALIASES — keep the rest of the file using short names
// FIX: AppLogo, SessionChip, StaffGuard were referenced but never imported.
//      ModernAppLogo is the real class; we alias it here so all call-sites
//      compile without any further changes.
// ══════════════════════════════════════════════════════════════════════════════

/// Thin wrapper so call-sites can keep writing `AppLogo(height:…, onDark:…)`.
class AppLogo extends StatelessWidget {
  final double height;
  final bool onDark;
  const AppLogo({super.key, this.height = 60, this.onDark = false});

  @override
  Widget build(BuildContext context) => ModernAppLogo(
        height: height,
        onDark: onDark,
        animated: false,
        showGlow: false,
      );
}

/// Shows the currently-logged-in staff member's name as a small chip.
/// When no staff member is selected (owner mode) it renders nothing.
class SessionChip extends ConsumerWidget {
  const SessionChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionUserProvider);
    if (user == null) return const SizedBox(width: 8);
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        user.name.split(' ').first,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Guards a screen by checking if the current session user has [permission].
/// Owner (sessionUser == null) always passes through.
class StaffGuard extends ConsumerWidget {
  final String permission;
  final Widget child;
  const StaffGuard({super.key, required this.permission, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionUserProvider);
    // null = owner, unrestricted
    if (user == null || user.can(permission)) return child;
    return _NoAccessPlaceholder(permission: permission);
  }
}

class _NoAccessPlaceholder extends StatelessWidget {
  final String permission;
  const _NoAccessPlaceholder({required this.permission});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_rounded, size: 48, color: AppColors.inkMuted),
        const SizedBox(height: 12),
        Text('Access Restricted',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: AppColors.inkMuted)),
        const SizedBox(height: 4),
        Text('You need "$permission" permission.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCAFFOLD  — top app bar + bottom nav + drawer
// ══════════════════════════════════════════════════════════════════════════════

// Tab indices
const int kTabDashboard      = 0;
const int kTabTransactions   = 1;
const int kTabCustomers      = 2;
const int kTabInventory      = 3;
const int kTabPayments       = 4;
const int kTabReports        = 5;
const int kTabNotifications  = 6;
const int kTabSettings       = 7;
const int kTabLoadUnload     = 8;
const int kTabExpenses       = 9;
const int kTabSmartEntry     = 10;

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab     = ref.watch(tabProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final w       = MediaQuery.of(context).size.width;
    final isWide  = w >= 900;

    final screens = <Widget>[
      const StaffGuard(permission: 'dashboard',      child: DashboardScreen()),
      const StaffGuard(permission: 'transactions',   child: TransactionsScreen()),
      const StaffGuard(permission: 'customers',      child: CustomersScreen()),
      const StaffGuard(permission: 'inventory',      child: InventoryScreen()),
      const StaffGuard(permission: 'payments',       child: PaymentsScreen()),
      const StaffGuard(permission: 'reports',        child: ReportsScreen()),
      const StaffGuard(permission: 'notifications',  child: NotificationsScreen()),
      const StaffGuard(permission: 'settings',       child: SettingsScreen()),
      const StaffGuard(permission: 'load_unload',    child: LoadUnloadScreen()),
      const StaffGuard(permission: 'expenses',       child: ExpensesScreen()),
      const StaffGuard(permission: 'smart_entry',    child: SmartEntryScreen()),
    ];

    if (isWide) {
      return _WideLayout(screens: screens, tab: tab, isDark: isDark);
    }
    return _MobileLayout(screens: screens, tab: tab, isDark: isDark);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _MobileLayout extends ConsumerWidget {
  final List<Widget> screens;
  final int tab;
  final bool isDark;
  const _MobileLayout({required this.screens, required this.tab, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _MrAppBar(isDark: isDark),
      drawer: _BurgerDrawer(isDark: isDark, currentTab: tab),
      body: IndexedStack(index: tab, children: screens),
      bottomNavigationBar: _BottomNav(tab: tab, isDark: isDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDE / DESKTOP LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _WideLayout extends ConsumerWidget {
  final List<Widget> screens;
  final int tab;
  final bool isDark;
  const _WideLayout({required this.screens, required this.tab, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(children: [
        _Sidebar(tab: tab, isDark: isDark),
        Expanded(child: Column(children: [
          _MrAppBar(isDark: isDark, showBurger: false),
          Expanded(child: IndexedStack(index: tab, children: screens)),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP APP BAR — consistent on every screen
// ─────────────────────────────────────────────────────────────────────────────
class _MrAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isDark;
  final bool showBurger;
  const _MrAppBar({required this.isDark, this.showBurger = true});

  @override
  Size get preferredSize => const Size.fromHeight(100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final primary  = Theme.of(context).colorScheme.primary;
    final w        = MediaQuery.of(context).size.width;
    final compact  = w < 360;

    return Container(
      height: 100 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: primary.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // LEFT — burger menu
        if (showBurger)
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const SizedBox(
              width: 60, height: 100,
              child: Icon(Icons.menu_rounded, size: 28, color: Colors.white),
            ),
          )
        else
          const SizedBox(width: 16),

        // MIDDLE — MrWater logo
        Expanded(child: Center(
          child: AppLogo(
            height: compact ? 70.0 : 86.0,
            onDark: true,
          ),
        )),

        // RIGHT — session chip + profile icon
        const SessionChip(),
        _ProfileBtn(isDark: isDark, settings: settings, forceWhite: true),
      ]),
    );
  }
}

// Profile button
class _ProfileBtn extends ConsumerWidget {
  final bool isDark;
  final AppSettings settings;
  final bool forceWhite;
  const _ProfileBtn({required this.isDark, required this.settings, this.forceWhite = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns    = ref.watch(transactionsProvider);
    final notifs  = txns.where((t) => t.balance > 0).length;

    return GestureDetector(
      onTap: () => _showProfilePanel(context, ref, isDark),
      child: SizedBox(
        width: 56, height: 56,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, size: 20, color: Colors.white),
          ),
          if (notifs > 0)
            Positioned(top: 6, right: 6,
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                    color: AppColors.dangerColor(isDark), shape: BoxShape.circle),
                child: Center(child: Text('$notifs',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                        color: Colors.white))),
              )),
        ]),
      ),
    );
  }

  void _showProfilePanel(BuildContext context, WidgetRef ref, bool isDark) {
    showMrSheet(context, title: '👤 Admin Profile',
      builder: (_) => _ProfileSheet(settings: settings, isDark: isDark));
  }
}

class _ProfileSheet extends ConsumerWidget {
  final AppSettings settings;
  final bool isDark;
  const _ProfileSheet({required this.settings, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custs     = ref.watch(customersProvider);
    final txns      = ref.watch(transactionsProvider);
    final inv       = ref.watch(inventoryProvider);
    final totalDue  = custs.where((c) => c.balance < 0).fold(0.0, (s, c) => s + c.balance.abs());
    final todayTx   = txns.where((t) => t.date == DateFormat.yMd().format(DateTime.now())).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Column(children: [
        Container(width: 64, height: 64,
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
          child: Center(child: Text(
            settings.ownerName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase(),
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ))),
        const SizedBox(height: 10),
        Text(settings.ownerName, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
        Text(settings.businessName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
        if (settings.phone.isNotEmpty)
          Text(settings.phone, style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
      ])),
      const SizedBox(height: 20),

      Row(children: [
        _infoTile('Customers', '${custs.length}', AppColors.primaryColor(isDark), isDark),
        const SizedBox(width: 8),
        _infoTile('Today Txns', '$todayTx', AppColors.successColor(isDark), isDark),
        const SizedBox(width: 8),
        _infoTile('Dues', '₹${totalDue.toInt()}', AppColors.dangerColor(isDark), isDark),
      ]),
      const SizedBox(height: 16),

      _infoRow(Icons.store_rounded, 'Business', settings.businessName, isDark),
      _infoRow(Icons.location_on_rounded, 'Address', settings.address.isNotEmpty ? settings.address : '—', isDark),
      if (settings.gstin.isNotEmpty)
        _infoRow(Icons.numbers_rounded, 'GSTIN', settings.gstin, isDark),
      _infoRow(Icons.inventory_2_rounded, 'Cool Stock',
          '${inv.coolStock} / ${inv.coolTotal} jars', isDark),
      _infoRow(Icons.inventory_2_rounded, 'PET Stock',
          '${inv.petStock} / ${inv.petTotal} jars', isDark),

      const SizedBox(height: 16),
      GradientButton(
        label: '⚙️  Go to Settings',
        onTap: () {
          Navigator.pop(context);
          ref.read(tabProvider.notifier).state = kTabSettings;
        },
        height: 44,
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
          ref.read(sessionUserProvider.notifier).state = null;
          ref.read(pinUnlockedProvider.notifier).state = false;
        },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.switch_account_rounded, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 8),
          Text('Switch Role / Lock Screen',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
        ]),
      ),
    ]);
  }

  Widget _infoTile(String label, String val, Color c, bool isDark) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withValues(alpha: 0.15)),
          ),
          child: Column(children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted)),
            const SizedBox(height: 2),
            Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
          ]),
        ),
      );

  Widget _infoRow(IconData icon, String label, String val, bool isDark) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
          const Spacer(),
          Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
              color: isDark ? AppColors.inkDark : AppColors.ink)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BURGER DRAWER
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem {
  final int tab;
  final IconData icon;
  final String label;
  final String? permission;
  const _NavItem(this.tab, this.icon, this.label, [this.permission]);
}

const _navItems = <_NavItem>[
  _NavItem(kTabDashboard,     Icons.dashboard_rounded,              'Dashboard',     'dashboard'),
  _NavItem(kTabTransactions,  Icons.receipt_long_rounded,           'Transactions',  'transactions'),
  _NavItem(kTabCustomers,     Icons.people_rounded,                 'Customers',     'customers'),
  _NavItem(kTabInventory,     Icons.inventory_2_rounded,            'Inventory',     'inventory'),
  _NavItem(kTabLoadUnload,    Icons.move_to_inbox_rounded,          'Load / Unload', 'load_unload'),
  _NavItem(kTabPayments,      Icons.account_balance_wallet_rounded, 'Payments',      'payments'),
  _NavItem(kTabExpenses,      Icons.money_off_rounded,              'Expenses',      'expenses'),
  _NavItem(kTabSmartEntry,    Icons.document_scanner_rounded,       'Smart Entry',   'smart_entry'),
  _NavItem(kTabReports,       Icons.assessment_rounded,             'Reports',       'reports'),
  _NavItem(kTabNotifications, Icons.notifications_rounded,          'Notifications', 'notifications'),
  _NavItem(kTabSettings,      Icons.settings_rounded,               'Settings'),
];

class _BurgerDrawer extends ConsumerWidget {
  final bool isDark;
  final int currentTab;
  const _BurgerDrawer({required this.isDark, required this.currentTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings    = ref.watch(settingsProvider);
    final primary     = Theme.of(context).colorScheme.primary;
    final sessionUser = ref.watch(sessionUserProvider);
    final visibleNav  = _navItems.where((item) =>
        item.permission == null || sessionUser == null || sessionUser.can(item.permission!)).toList();

    return Drawer(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bg,
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              primary.withValues(alpha: 0.15),
              primary.withValues(alpha: 0.04),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
              child: Center(child: Text(
                settings.ownerName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase(),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppLogo(height: 60, onDark: isDark),
              const SizedBox(height: 2),
              Text(settings.ownerName, style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.inkMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),

        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12),
          children: visibleNav.map((item) {
            final active = currentTab == item.tab;
            return GestureDetector(
              onTap: () {
                ref.read(tabProvider.notifier).state = item.tab;
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: active
                      ? primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? primary.withValues(alpha: 0.3) : Colors.transparent,
                  ),
                ),
                child: Row(children: [
                  Icon(item.icon, size: 20,
                      color: active ? primary : AppColors.inkMuted),
                  const SizedBox(width: 14),
                  Text(item.label, style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? primary : Theme.of(context).colorScheme.onSurface)),
                  if (active) ...[
                    const Spacer(),
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: primary),
                    ),
                  ],
                ]),
              ),
            );
          }).toList(),
        )),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text('MrWater v2.0', style: GoogleFonts.jetBrainsMono(
              fontSize: 10, color: AppColors.inkMuted)),
        ),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends ConsumerWidget {
  final int tab;
  final bool isDark;
  const _BottomNav({required this.tab, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg      = isDark ? AppColors.cardDark : AppColors.card;
    final pb      = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 64 + pb,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(
            color: isDark ? AppColors.separatorDark : AppColors.separator)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: pb),
        child: Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => ref.read(tabProvider.notifier).state = kTabDashboard,
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.home_rounded,
                  size: 24,
                  color: tab == kTabDashboard ? primary : AppColors.inkMuted),
              const SizedBox(height: 2),
              Text('Home', style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: tab == kTabDashboard ? FontWeight.w700 : FontWeight.w500,
                  color: tab == kTabDashboard ? primary : AppColors.inkMuted)),
            ]),
          )),

          Expanded(child: GestureDetector(
            onTap: () => showMrSheet(context, title: '⚡ Quick Transaction',
                builder: (_) => _QuickSheet(isDark: isDark)),
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.40),
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            ]),
          )),

          Expanded(child: GestureDetector(
            onTap: () => ref.read(tabProvider.notifier).state = kTabNotifications,
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_rounded,
                  size: 24,
                  color: tab == kTabNotifications ? primary : AppColors.inkMuted),
              const SizedBox(height: 2),
              Text('Alerts', style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: tab == kTabNotifications ? FontWeight.w700 : FontWeight.w500,
                  color: tab == kTabNotifications ? primary : AppColors.inkMuted)),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _QuickSheet extends ConsumerWidget {
  final bool isDark;
  const _QuickSheet({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coolC = AppColors.coolColor(isDark);
    final okC   = AppColors.successColor(isDark);

    return Column(children: [
      _qBtn(icon: Icons.mic_rounded, label: 'Voice Assistant',
          sub: 'AI Command Center', color: AppColors.purple, isDark: isDark,
          onTap: () { Navigator.pop(context); }),
      const SizedBox(height: 10),

      Divider(height: 1,
          color: isDark ? AppColors.separatorDark : AppColors.separator),
      const SizedBox(height: 10),

      _qBtn(icon: Icons.local_shipping_rounded, label: 'New Delivery',
          sub: 'Standard daily drop', color: coolC, isDark: isDark,
          onTap: () {
            Navigator.pop(context);
            showMrSheet(context, title: '🚚 New Delivery', builder: (_) => const DeliveryForm());
          }),
      const SizedBox(height: 10),

      _qBtn(icon: Icons.celebration_rounded, label: 'New Event',
          sub: 'Bulk/party order', color: AppColors.purple, isDark: isDark,
          onTap: () {
            Navigator.pop(context);
            showMrSheet(context, title: '🎉 New Event', builder: (_) => const EventForm());
          }),
      const SizedBox(height: 10),

      _qBtn(icon: Icons.swap_horiz_rounded, label: 'Return Jars',
          sub: 'Collect back empty', color: AppColors.inkMuted, isDark: isDark,
          onTap: () {
            Navigator.pop(context);
            showMrSheet(context, title: '📦 Return Jars', builder: (_) => const ReturnJarForm());
          }),
      const SizedBox(height: 10),

      _qBtn(icon: Icons.payments_rounded, label: 'Record Payment',
          sub: 'Receive cash/UPI', color: okC, isDark: isDark,
          onTap: () {
            Navigator.pop(context);
            showMrSheet(context, title: '💰 Record Payment', builder: (_) => const PaymentForm());
          }),
      const SizedBox(height: 10),

      _qBtn(icon: Icons.money_off_rounded, label: 'Record Expense',
          sub: 'Petrol, repairs, etc', color: AppColors.dangerColor(isDark), isDark: isDark,
          onTap: () {
            Navigator.pop(context);
            showMrSheet(context, title: '💸 Record Expense', builder: (_) => const ExpenseForm());
          }),
    ]);
  }

  Widget _qBtn({required IconData icon, required String label,
      required String sub, required Color color, required bool isDark,
      required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.inter(fontSize: 14,
                  fontWeight: FontWeight.w700, color: color)),
              Text(sub, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color.withValues(alpha: 0.5)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
class _Sidebar extends ConsumerWidget {
  final int tab;
  final bool isDark;
  const _Sidebar({required this.tab, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary     = Theme.of(context).colorScheme.primary;
    final sessionUser = ref.watch(sessionUserProvider);
    final visibleNav  = _navItems.where((item) =>
        item.permission == null || sessionUser == null || sessionUser.can(item.permission!)).toList();

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        border: Border(right: BorderSide(
            color: isDark ? AppColors.separatorDark : AppColors.separator)),
      ),
      child: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppLogo(height: 58, onDark: isDark),
            ),
          ),
        ),
        Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
        const SizedBox(height: 8),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10),
          children: visibleNav.map((item) {
            final active = tab == item.tab;
            return GestureDetector(
              onTap: () => ref.read(tabProvider.notifier).state = item.tab,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: active ? primary.withValues(alpha: 0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(item.icon, size: 18,
                      color: active ? primary : AppColors.inkMuted),
                  const SizedBox(width: 10),
                  Text(item.label, style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? primary : Theme.of(context).colorScheme.onSurface)),
                ]),
              ),
            );
          }).toList(),
        )),
        Padding(
          padding: const EdgeInsets.all(12),
          child: GradientButton(label: '⚡ Quick Transaction',
              onTap: () => showMrSheet(context, title: '⚡ Quick Action',
                  builder: (_) => _QuickSheet(isDark: isDark)),
              height: 40),
        ),
      ])),
    );
  }
}
