import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../dashboard/data/dashboard_provider.dart';
import '../../../housekeeping/presentation/widgets/housekeeping_panel.dart';

class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashboardAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: const Color(0xFF1565C0),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Welcome, ${user?.fullName.split(' ').first ?? 'Manager'}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Manager Dashboard',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                          onPressed: () => context.push(AppRoutes.notifications),
                        ),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.profile),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            child: Text(
                              user?.fullName.substring(0, 1) ?? 'M',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                dashboardAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0))),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (stats) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Key Metrics
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          StatCard(
                            label: 'Guests In-House',
                            value: '${stats.guestsInhouse}',
                            icon: Icons.people_outline_rounded,
                            color: const Color(0xFF1565C0),
                            subtitle: '${stats.checkinsToday} arriving today',
                            onTap: () => context.push(AppRoutes.bookings),
                          ),
                          StatCard(
                            label: "Today's Revenue",
                            value: '₹${stats.revenueToday.toStringAsFixed(0)}',
                            icon: Icons.currency_rupee_rounded,
                            color: AppTheme.success,
                            onTap: () => context.push(AppRoutes.reports),
                          ),
                          StatCard(
                            label: 'Check-ins Today',
                            value: '${stats.checkinsToday}',
                            icon: Icons.login_rounded,
                            color: AppTheme.info,
                            onTap: () => context.push('/checkin'),
                          ),
                          StatCard(
                            label: 'Check-outs Today',
                            value: '${stats.checkoutsToday}',
                            icon: Icons.logout_rounded,
                            color: AppTheme.secondary,
                            onTap: () => context.push('/checkin'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Operations Section
                      const SectionHeader(title: 'Operations'),
                      const SizedBox(height: 12),
                      _ManagerActionGrid(),
                      const SizedBox(height: 20),

                      // Staff Overview Card
                      const SectionHeader(title: 'Staff Overview', action: 'View All'),
                      const SizedBox(height: 12),
                      _StaffOverviewCard(),
                      const SizedBox(height: 20),

                      // Housekeeping Status
                      const SizedBox(height: 20),
                      HousekeepingPanel(),
                      const SizedBox(height: 20),

                      // Alerts
                      if (stats.lowStockAlerts > 0)
                        _AlertTile(
                          icon: Icons.inventory_2_outlined,
                          message: '${stats.lowStockAlerts} inventory items low',
                          color: AppTheme.warning,
                          onTap: () => context.push(AppRoutes.inventory),
                        ),
                      if (stats.maintenanceOpen > 0)
                        _AlertTile(
                          icon: Icons.build_outlined,
                          message: '${stats.maintenanceOpen} maintenance tickets open',
                          color: AppTheme.error,
                          onTap: () => context.push(AppRoutes.maintenance),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ManagerBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createBooking),
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
        backgroundColor: const Color(0xFF1565C0),
      ),
    );
  }
}

// ── Manager Action Grid ────────────────────────────────────────────────────────

class _ManagerActionGrid extends StatelessWidget {
  final _items = const [
    _MgrAction('Bookings',   Icons.calendar_month_outlined,     '/bookings',    Color(0xFF1565C0)),
    _MgrAction('Check-in',   Icons.login_rounded,               '/checkin',     Color(0xFF00838F)),
    _MgrAction('Rooms',      Icons.bed_outlined,                '/rooms',       Color(0xFF2E7D32)),
    _MgrAction('Staff',      Icons.people_rounded,              '/staff',       Color(0xFF6A1B9A)),
    _MgrAction('Reports',    Icons.bar_chart_rounded,           '/reports',     Color(0xFF37474F)),
    _MgrAction('Inventory',  Icons.inventory_2_outlined,        '/inventory',   Color(0xFFE64A19)),
    _MgrAction('Food',       Icons.restaurant_menu_outlined,    '/food',        Color(0xFFFFB300)),
    _MgrAction('Activities', Icons.hiking_outlined,             '/activities',  Color(0xFF558B2F)),
    _MgrAction('Guests',     Icons.person_outline,              '/guests',      Color(0xFF00796B)),
  ];

  const _ManagerActionGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: _items.map((a) => _MgrActionTile(action: a)).toList(),
    );
  }
}

class _MgrAction {
  final String label;
  final IconData icon;
  final String route;
  final Color color;
  const _MgrAction(this.label, this.icon, this.route, this.color);
}

class _MgrActionTile extends StatelessWidget {
  final _MgrAction action;
  const _MgrActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(action.route),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Staff Overview Card ────────────────────────────────────────────────────────

class _StaffOverviewCard extends StatelessWidget {
  final _depts = const [
    {'label': 'Housekeeping', 'icon': Icons.cleaning_services_outlined, 'color': Color(0xFF2E7D32), 'route': '/staff'},
    {'label': 'Kitchen',      'icon': Icons.restaurant_menu_outlined,   'color': Color(0xFFE64A19), 'route': '/staff'},
    {'label': 'Activities',   'icon': Icons.hiking_outlined,            'color': Color(0xFF00838F), 'route': '/staff'},
    {'label': 'Shop',         'icon': Icons.storefront_outlined,        'color': Color(0xFF6A1B9A), 'route': '/staff'},
    {'label': 'Guides',       'icon': Icons.explore_outlined,           'color': Color(0xFF558B2F), 'route': '/staff'},
    {'label': 'Accounts',     'icon': Icons.account_balance_wallet_outlined, 'color': Color(0xFF00796B), 'route': '/staff'},
  ];

  const _StaffOverviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Departments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton(
                onPressed: () => context.push('/staff'),
                child: const Text('Full View', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _depts.map((d) => GestureDetector(
              onTap: () => context.push(d['route'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (d['color'] as Color).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (d['color'] as Color).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(d['icon'] as IconData, size: 14, color: d['color'] as Color),
                    const SizedBox(width: 6),
                    Text(d['label'] as String,
                        style: TextStyle(fontSize: 12, color: d['color'] as Color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Alert Tile ─────────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final VoidCallback onTap;
  const _AlertTile({required this.icon, required this.message, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Nav ─────────────────────────────────────────────────────────────────

class _ManagerBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home', '/dashboard/manager', const Color(0xFF1565C0)),
              _NavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Bookings', '/bookings', const Color(0xFF1565C0)),
              _NavItem(Icons.login_rounded, Icons.login_rounded, 'Check-in', '/checkin', const Color(0xFF1565C0)),
              _NavItem(Icons.bed_outlined, Icons.bed_rounded, 'Rooms', '/rooms', const Color(0xFF1565C0)),
              _NavItem(Icons.people_outlined, Icons.people_rounded, 'Staff', '/staff', const Color(0xFF1565C0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label, route;
  final Color activeColor;
  const _NavItem(this.icon, this.activeIcon, this.label, this.route, this.activeColor);

  @override
  Widget build(BuildContext context) {
    final isActive = GoRouterState.of(context).matchedLocation.startsWith(route);
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : AppTheme.textHint,
              size: 22,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? activeColor : AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
