import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/app_state.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/modern_sidebar.dart';
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
    
    // Enhanced responsive breakpoints
    final isDesktop = w >= 1200;
    final isTablet  = w >= 768 && w < 1200;

    final screens = <Widget>[
      const StaffGuard(permission: 'dashboard',      child: DashboardScreen()),
      const StaffGuard(permission: 'transactions',   child: TransactionsScreen()),
      const StaffGuard(permission: 'customers',      child: CustomersScreen()),
      const StaffGuard(permission: 'inventory',      child: InventoryScreen()),
      const StaffGuard(permission: 'payments',       child: PaymentsScreen()),
      const StaffGuard(permission: 'reports',        child: ReportsScreen()),
      const StaffGuard(permission: 'notifications',  child: NotificationsScreen()),
      const StaffGuard(permission: 'settings',       child: SettingsScreen()),
      const StaffGuard(permission: 'load_unload',          child: LoadUnloadScreen()),
      const StaffGuard(permission: 'expenses',       child: ExpensesScreen()),
      const StaffGuard(permission: 'smart_entry',    child: SmartEntryScreen()),
    ];

    if (isDesktop) {
      return _DesktopLayout(screens: screens, tab: tab, isDark: isDark);
    } else if (isTablet) {
      return _TabletLayout(screens: screens, tab: tab, isDark: isDark);
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
// DESKTOP LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopLayout extends ConsumerWidget {
  final List<Widget> screens;
  final int tab;
  final bool isDark;
  const _DesktopLayout({required this.screens, required this.tab, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(children: [
        ModernSidebar(tab: tab, isDark: isDark),
        Expanded(child: Column(children: [
          _MrAppBar(isDark: isDark, showBurger: false),
          Expanded(child: IndexedStack(index: tab, children: screens)),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _TabletLayout extends ConsumerWidget {
  final List<Widget> screens;
  final int tab;
  final bool isDark;
  const _TabletLayout({required this.screens, required this.tab, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(children: [
        // Collapsible modern sidebar for tablet
        SizedBox(
          width: 80,
          child: TabletModernSidebar(tab: tab, isDark: isDark),
        ),
        Expanded(child: Column(children: [
          _MrAppBar(isDark: isDark, showBurger: true),
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
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final w        = MediaQuery.of(context).size.width;
    final compact  = w < 360;

    return Container(
      height: 80 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.separatorDark : AppColors.separator,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06), 
            blurRadius: 1, 
            offset: const Offset(0, 1)
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // LEFT - burger menu
        if (showBurger)
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: SizedBox(
              width: 56, height: 56,
              child: Icon(Icons.menu_rounded, 
                  size: 24, 
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          )
        else
          const SizedBox(width: 16),

        // MIDDLE - Branded ModernAppLogo
        Expanded(
          child: ModernAppLogo(
            height: compact ? 36.0 : 42.0,
            fit: BoxFit.contain,
          ),
        ),

        // RIGHT - session chip + profile icon
        const SessionChip(),
        _ProfileBtn(isDark: isDark, settings: settings),
      ]),
    );
  }
}

// Profile button — shows admin info panel
class _ProfileBtn extends ConsumerWidget {
  final bool isDark;
  final AppSettings settings;
  const _ProfileBtn({required this.isDark, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns    = ref.watch(transactionsProvider);
    final notifs  = txns.where((t) => t.balance > 0).length; // pending dues count

    return GestureDetector(
      onTap: () => _showProfilePanel(context, ref, isDark),
      child: SizedBox(
        width: 56, height: 56,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(Icons.person_rounded, 
                size: 20, 
                color: Theme.of(context).colorScheme.primary),
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
      // Avatar + name
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

      // Quick stats
      Row(children: [
        _infoTile('Customers', '${custs.length}', AppColors.primaryColor(isDark), isDark),
        const SizedBox(width: 8),
        _infoTile('Today Txns', '$todayTx', AppColors.successColor(isDark), isDark),
        const SizedBox(width: 8),
        _infoTile('Dues', '₹${totalDue.toInt()}', AppColors.dangerColor(isDark), isDark),
      ]),
      const SizedBox(height: 16),

      // Business info
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
          // ── ROLE logout only — Firebase stays signed in ──────────────────
          // Firebase sign-out is ONLY available from the hidden admin portal.
          // In-app logout just clears the role session and returns to PIN.
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
  final String? permission; // null = always visible (e.g. Settings)
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
  _NavItem(kTabSettings,      Icons.settings_rounded,               'Settings'),     // always visible
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
        // Drawer header
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
              child: Center(child: Text(
                settings.ownerName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase(),
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              )),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.water_drop_rounded, size: 14, color: primary),
                const SizedBox(width: 4),
                Text('MrWater', style: GoogleFonts.syne(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.ink)),
              ]),
              const SizedBox(height: 2),
              Text(settings.ownerName, style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),

        // Nav items
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

        // Bottom version tag
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
// BOTTOM NAV — 3 items: Home | [+] Quick Transaction | Alerts
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
      height: 70 + pb,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(
            color: isDark ? AppColors.separatorDark : AppColors.separator, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08), 
            blurRadius: 16, 
            offset: const Offset(0, -2)
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: pb),
        child: Row(children: [
          // Home
          Expanded(child: GestureDetector(
            onTap: () => ref.read(tabProvider.notifier).state = kTabDashboard,
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tab == kTabDashboard 
                      ? primary.withValues(alpha: 0.1) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.home_rounded,
                    size: 22,
                    color: tab == kTabDashboard ? primary : AppColors.inkMuted),
              ),
              const SizedBox(height: 4),
              Text('Home', style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: tab == kTabDashboard ? FontWeight.w600 : FontWeight.w500,
                  color: tab == kTabDashboard ? primary : AppColors.inkMuted)),
            ]),
          )),

          // Centre + FAB
          Expanded(child: GestureDetector(
            onTap: () => showMrSheet(context, title: 'Quick Transaction',
                builder: (_) => _QuickSheet(isDark: isDark)),
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
              ),
            ]),
          )),

          // Alerts
          Expanded(child: GestureDetector(
            onTap: () => ref.read(tabProvider.notifier).state = kTabNotifications,
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tab == kTabNotifications 
                      ? primary.withValues(alpha: 0.1) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.notifications_rounded,
                    size: 22,
                    color: tab == kTabNotifications ? primary : AppColors.inkMuted),
              ),
              const SizedBox(height: 4),
              Text('Alerts', style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: tab == kTabNotifications ? FontWeight.w600 : FontWeight.w500,
                  color: tab == kTabNotifications ? primary : AppColors.inkMuted)),
            ]),
          )),
        ]),
      ),
    );
  }
}

// _QuickFab removed — + button is now embedded in _BottomNav

class _QuickSheet extends ConsumerWidget {
  final bool isDark;
  const _QuickSheet({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coolC = AppColors.coolColor(isDark);
    final okC   = AppColors.successColor(isDark);

    return Column(children: [
      // ── 🎙 Voice Assistant — fastest way to record anything ───────────────
      _qBtn(icon: Icons.mic_rounded, label: 'Voice Assistant',
          sub: 'AI Command Center', color: AppColors.purple, isDark: isDark,
          onTap: () {
            Navigator.pop(context);
            // Future: voice assist
          }),
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

// ── STAFF GUARD ──────────────────────────────────────────────────────────────
class StaffGuard extends ConsumerWidget {
  final String permission;
  final Widget child;
  const StaffGuard({super.key, required this.permission, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionUserProvider);
    // Owner (null) has all perms; staff must have the explicit permission string
    if (user == null || user.can(permission)) return child;
    return const _AccessDenied();
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock_person_rounded, size: 64, color: AppColors.inkSoft),
      const SizedBox(height: 16),
      Text('Access Denied', style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.inkMuted)),
      Text('You don\'t have permission for this screen.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
    ]));
}

// ── SESSION CHIP ─────────────────────────────────────────────────────────────
class SessionChip extends ConsumerWidget {
  const SessionChip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user   = ref.watch(sessionUserProvider);
    final label  = user?.name ?? 'Owner';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(user == null ? Icons.verified_user_rounded : Icons.person_rounded,
            size: 13, color: AppColors.inkMuted),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted)),
      ]),
    );
  }
}
