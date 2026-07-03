import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_colors.dart';

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

// Modern sidebar with blue/violet gradient and smart features
class ModernSidebar extends ConsumerWidget {
  final int tab;
  final bool isDark;
  const ModernSidebar({super.key, required this.tab, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final sessionUser = ref.watch(sessionUserProvider);
    final visibleNav = _navItems.where((item) =>
        item.permission == null || sessionUser == null || sessionUser.can(item.permission!)).toList();

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF007AFF), // iOS Blue (primary)
                    Color(0xFF5AC8FA), // Light Blue (primaryLight)
                    Color(0xFF0A84FF), // Dark Blue (primaryDM)
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: _SidebarHeader(isDark: isDark),
            ),

            const Divider(height: 1, thickness: 1),
            
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: visibleNav.map((item) {
                    final active = tab == item.tab;
                    return _ModernNavItem(
                      item: item,
                      active: active,
                      primary: primary,
                      onTap: () => ref.read(tabProvider.notifier).state = item.tab,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Enhanced sidebar header with MrWater logo matching app theme
class _SidebarHeader extends StatelessWidget {
  final bool isDark;
  const _SidebarHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(
        children: [
          // Logo area placed directly on the sidebar gradient (no white inset)
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF007AFF), Color(0xFF5AC8FA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset('assets/images/mrwater_logomark.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 16),
              // Brand text with proper alignment
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MrWater',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'Pro',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: const Color(0xFF5AC8FA), // Light Blue
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status indicator with iOS blue theme
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759), // iOS Green
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF34C759).withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'System Active',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Modern navigation item with enhanced styling
class _ModernNavItem extends StatelessWidget {
  final NavItem item;
  final bool active;
  final Color primary;
  final VoidCallback onTap;

  const _ModernNavItem({
    required this.item,
    required this.active,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              // Glassmorphism effect for active state
              color: active 
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active 
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              // Subtle shadow for active state
              boxShadow: active ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Row(
              children: [
                // Icon with enhanced styling
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: active 
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: active 
                        ? primary
                        : AppColors.inkMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                          color: active 
                              ? primary
                              : Theme.of(context).colorScheme.onSurface,
                          height: 1.0,
                        ),
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Active indicator
                if (active)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.8),
                          Colors.white.withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Tablet version of modern sidebar (compact)
class TabletModernSidebar extends ConsumerWidget {
  final int tab;
  final bool isDark;
  const TabletModernSidebar({super.key, required this.tab, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleNav = _navItems.where((item) {
      final sessionUser = ref.watch(sessionUserProvider);
      return item.permission == null || sessionUser == null || sessionUser.can(item.permission!);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF007AFF),
                    Color(0xFF5AC8FA),
                    Color(0xFF0A84FF),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.water_drop_rounded,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'MrWater Pro',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: visibleNav.map((item) {
                    final active = tab == item.tab;
                    return _ModernNavItem(
                      item: item,
                      active: active,
                      primary: Theme.of(context).colorScheme.primary,
                      onTap: () => ref.read(tabProvider.notifier).state = item.tab,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Enhanced navigation item data structure
class NavItem {
  final int tab;
  final String label;
  final String? description;
  final IconData icon;
  final String? permission;

  const NavItem({
    required this.tab,
    required this.label,
    this.description,
    required this.icon,
    this.permission,
  });
}

// Navigation items with descriptions
const List<NavItem> _navItems = [
  NavItem(
    tab: kTabDashboard,
    label: 'Dashboard',
    description: 'Overview & stats',
    icon: Icons.dashboard_rounded,
  ),
  NavItem(
    tab: kTabTransactions,
    label: 'Transactions',
    description: 'All orders',
    icon: Icons.receipt_long_rounded,
    permission: 'transactions',
  ),
  NavItem(
    tab: kTabCustomers,
    label: 'Customers',
    description: 'Manage clients',
    icon: Icons.people_rounded,
    permission: 'customers',
  ),
  NavItem(
    tab: kTabInventory,
    label: 'Inventory',
    description: 'Stock levels',
    icon: Icons.inventory_2_rounded,
    permission: 'inventory',
  ),
  NavItem(
    tab: kTabPayments,
    label: 'Payments',
    description: 'Revenue tracking',
    icon: Icons.payments_rounded,
    permission: 'payments',
  ),
  NavItem(
    tab: kTabReports,
    label: 'Reports',
    description: 'Analytics',
    icon: Icons.analytics_rounded,
    permission: 'reports',
  ),
  NavItem(
    tab: kTabNotifications,
    label: 'Notifications',
    description: 'Alerts & updates',
    icon: Icons.notifications_rounded,
    permission: 'notifications',
  ),
  NavItem(
    tab: kTabSettings,
    label: 'Settings',
    description: 'Configuration',
    icon: Icons.settings_rounded,
    permission: 'settings',
  ),
  NavItem(
    tab: kTabLoadUnload,
    label: 'Load/Unload',
    description: 'Vehicle management',
    icon: Icons.local_shipping_rounded,
    permission: 'load_unload',
  ),
  NavItem(
    tab: kTabExpenses,
    label: 'Expenses',
    description: 'Daily costs',
    icon: Icons.money_off_rounded,
    permission: 'expenses',
  ),
  NavItem(
    tab: kTabSmartEntry,
    label: 'Smart Entry',
    description: 'OCR Scanning',
    icon: Icons.document_scanner_rounded,
    permission: 'smart_entry',
  ),
];
