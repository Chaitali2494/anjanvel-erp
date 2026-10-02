import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/dashboard_provider.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashboardAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppTheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good ${_getGreeting()}, ${user?.fullName.split(' ').first ?? 'Owner'}! 👋',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Anjanvel Resort',
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
                                backgroundImage: user?.avatarUrl != null
                                    ? NetworkImage(user!.avatarUrl!)
                                    : null,
                                child: user?.avatarUrl == null
                                    ? Text(
                                        user?.fullName.substring(0, 1) ?? 'O',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                dashboardAsync.when(
                  loading: () => const _DashboardSkeleton(),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (stats) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Today's Stats
                      _TodayStatsGrid(stats: stats),
                      const SizedBox(height: AppTheme.spaceLG),

                      // Revenue Chart
                      const SectionHeader(title: 'Revenue (This Week)'),
                      const SizedBox(height: AppTheme.spaceMD),
                      _RevenueChart(data: stats.weeklyRevenue),
                      const SizedBox(height: AppTheme.spaceLG),

                      // Quick Actions
                      const SectionHeader(title: 'Quick Actions'),
                      const SizedBox(height: AppTheme.spaceMD),
                      _QuickActionsGrid(),
                      const SizedBox(height: AppTheme.spaceLG),

                      // Room Status Overview
                      const SectionHeader(title: 'Room Status', action: 'View All'),
                      const SizedBox(height: AppTheme.spaceMD),
                      _RoomStatusCard(stats: stats),
                      const SizedBox(height: AppTheme.spaceLG),

                      // Today's Check-ins
                      SectionHeader(
                        title: "Today's Check-ins",
                        action: 'All Bookings',
                        onActionTap: () => context.push(AppRoutes.bookings),
                      ),
                      const SizedBox(height: AppTheme.spaceMD),
                      ...stats.todayCheckins.map((b) => _BookingTile(booking: b)),

                      // Low Stock Alerts
                      if (stats.lowStockAlerts > 0) ...[
                        const SizedBox(height: AppTheme.spaceLG),
                        _AlertBanner(
                          icon: Icons.inventory_2_outlined,
                          message: '${stats.lowStockAlerts} inventory items below minimum stock',
                          color: AppTheme.warning,
                          onTap: () => context.push(AppRoutes.inventory),
                        ),
                      ],

                      // Maintenance Alerts
                      if (stats.maintenanceOpen > 0) ...[
                        const SizedBox(height: AppTheme.spaceSM),
                        _AlertBanner(
                          icon: Icons.build_outlined,
                          message: '${stats.maintenanceOpen} maintenance tickets open',
                          color: AppTheme.error,
                          onTap: () => context.push(AppRoutes.maintenance),
                        ),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _OwnerBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createBooking),
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ── Today's Stats ──────────────────────────────────────────────────────────────

class _TodayStatsGrid extends StatelessWidget {
  final DashboardStats stats;
  const _TodayStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatCard(
          label: "Today's Revenue",
          value: '₹${stats.revenueToday.toStringAsFixed(0)}',
          icon: Icons.currency_rupee_rounded,
          color: AppTheme.success,
          subtitle: '+12%',
          onTap: () {},
        ),
        StatCard(
          label: 'Guests In-House',
          value: '${stats.guestsInhouse}',
          icon: Icons.people_outline_rounded,
          color: AppTheme.primary,
          subtitle: '${stats.checkinsToday} arriving',
          onTap: () {},
        ),
        StatCard(
          label: 'Check-ins Today',
          value: '${stats.checkinsToday}',
          icon: Icons.login_rounded,
          color: AppTheme.info,
          onTap: () {},
        ),
        StatCard(
          label: 'Check-outs Today',
          value: '${stats.checkoutsToday}',
          icon: Icons.logout_rounded,
          color: AppTheme.secondary,
          onTap: () {},
        ),
        StatCard(
          label: 'New Leads',
          value: '${stats.newLeads}',
          icon: Icons.person_add_outlined,
          color: AppTheme.accent,
          onTap: () {},
        ),
        StatCard(
          label: 'Pending Tasks',
          value: '${stats.hkPending}',
          icon: Icons.cleaning_services_outlined,
          color: AppTheme.warning,
          onTap: () {},
        ),
      ],
    );
  }
}

// ── Revenue Chart ───────────────────────────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  final List<double> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5000,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  return Text(days[v.toInt() % 7], style: const TextStyle(fontSize: 10, color: AppTheme.textHint));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                  .toList(),
              isCurved: true,
              color: AppTheme.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.primary.withOpacity(0.2), AppTheme.primary.withOpacity(0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ───────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final _actions = const [
    _Action('New Booking', Icons.add_circle_outline_rounded, '/bookings/create', AppTheme.primary),
    _Action('Check-in', Icons.login_rounded, '/checkin', AppTheme.info),
    _Action('Room Status', Icons.bed_outlined, '/rooms', AppTheme.secondary),
    _Action('Food Orders', Icons.restaurant_menu_outlined, '/food', AppTheme.warning),
    _Action('Activities', Icons.hiking_outlined, '/activities', AppTheme.success),
    _Action('Staff', Icons.people_rounded, '/staff', Color(0xFF1565C0)),
    _Action('Reports', Icons.bar_chart_rounded, '/reports', AppTheme.accent),
    _Action('Inventory', Icons.inventory_2_outlined, '/inventory', Color(0xFF00796B)),
    _Action('Leads', Icons.person_add_outlined, '/leads', Color(0xFF6A1B9A)),
  ];

  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: _actions.map((a) => _QuickActionTile(action: a)).toList(),
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final String route;
  final Color color;
  const _Action(this.label, this.icon, this.route, this.color);
}

class _QuickActionTile extends StatelessWidget {
  final _Action action;
  const _QuickActionTile({required this.action});

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

// ── Room Status Card ────────────────────────────────────────────────────────────

class _RoomStatusCard extends StatelessWidget {
  final DashboardStats stats;
  const _RoomStatusCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          _RoomStatusDot('Available', stats.roomsAvailable, AppTheme.statusAvailable),
          _RoomStatusDot('Occupied', stats.roomsOccupied, AppTheme.statusOccupied),
          _RoomStatusDot('Cleaning', stats.roomsCleaning, AppTheme.statusCleaning),
          _RoomStatusDot('Maintenance', stats.roomsMaintenance, AppTheme.statusMaintenance),
        ],
      ),
    );
  }
}

class _RoomStatusDot extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _RoomStatusDot(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$count', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Booking Tile ────────────────────────────────────────────────────────────────

class _BookingTile extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_outline, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['guest_name'] ?? 'Guest',
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${booking['booking_number']} • ${booking['total_guests']} guests',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusBadge(
            label: booking['status'] ?? 'CONFIRMED',
            color: booking['status'] == 'CHECKED_IN' ? AppTheme.success : AppTheme.info,
          ),
        ],
      ),
    );
  }
}

// ── Alert Banner ────────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final VoidCallback? onTap;

  const _AlertBanner({required this.icon, required this.message, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
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

// ── Bottom Nav ──────────────────────────────────────────────────────────────────

class _OwnerBottomNav extends StatelessWidget {
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
              _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home', '/dashboard/owner'),
              _NavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Bookings', '/bookings'),
              _NavItem(Icons.login_rounded, Icons.login_rounded, 'Check-in', '/checkin'),
              _NavItem(Icons.bed_outlined, Icons.bed_rounded, 'Rooms', '/rooms'),
              _NavItem(Icons.people_outlined, Icons.people_rounded, 'Staff', '/staff'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavItem(this.icon, this.activeIcon, this.label, this.route);

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
              color: isActive ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppTheme.primary : AppTheme.textHint,
              size: 22,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? AppTheme.primary : AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: List.generate(6, (_) => Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
          )),
        ),
      ],
    );
  }
}
