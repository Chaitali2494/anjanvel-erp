import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/dashboard_provider.dart';
import '../../../housekeeping/data/housekeeping_provider.dart';

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

                      // ── Housekeeping Status ──────────────────────────────
                      const SizedBox(height: AppTheme.spaceLG),
                      _HousekeepingPanel(),
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
    _Action('Attendance', Icons.fact_check_outlined, '/staff/attendance', Color(0xFF37474F)),
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

// ── Housekeeping Panel (shared by Owner & Manager) ─────────────────────────────

class _HousekeepingPanel extends ConsumerWidget {
  const _HousekeepingPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(housekeepingTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Housekeeping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(children: [
              TextButton(
                onPressed: () => context.push('/housekeeping'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _showAssignTask(context, ref),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Assign Task', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 8),
        tasksAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: Color(0xFF6A1B9A)),
          )),
          error: (_, __) => const SizedBox.shrink(),
          data: (tasks) {
            final pending  = tasks.where((t) => t['status'] == 'PENDING').length;
            final inProg   = tasks.where((t) => t['status'] == 'IN_PROGRESS').length;
            final done     = tasks.where((t) => t['status'] == 'COMPLETED').length;
            final urgent   = tasks.where((t) => t['priority'] == 'HIGH' && t['status'] != 'COMPLETED').length;
            final pending3 = tasks.where((t) => t['status'] != 'COMPLETED').take(3).toList();

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.15)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  // Stats row
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      _HKStat('Pending', '$pending', const Color(0xFFFFE082)),
                      _HKDiv(),
                      _HKStat('In Progress', '$inProg', const Color(0xFF90CAF9)),
                      _HKDiv(),
                      _HKStat('Done Today', '$done', const Color(0xFFA5D6A7)),
                      _HKDiv(),
                      _HKStat('Urgent', '$urgent', const Color(0xFFEF9A9A)),
                    ]),
                  ),

                  // Pending task cards
                  if (pending3.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Text('All rooms clean — no pending tasks!', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ]),
                    )
                  else
                    ...pending3.map((task) => _HKTaskRow(task: task, ref: ref)),

                  // Footer link
                  InkWell(
                    onTap: () => context.push('/housekeeping'),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Open Housekeeping Dashboard', style: TextStyle(color: Color(0xFF6A1B9A), fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF6A1B9A)),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAssignTask(BuildContext context, WidgetRef ref) {
    final roomCtrl     = TextEditingController();
    final assignCtrl   = TextEditingController();
    final notesCtrl    = TextEditingController();
    String taskType    = 'REGULAR_CLEAN';
    String priority    = 'NORMAL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF6A1B9A), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Assign Housekeeping Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ]),
                const SizedBox(height: 20),

                // Room
                const Text('Room Number *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: roomCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 101', prefixIcon: Icon(Icons.bed_outlined, size: 18), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),

                // Task Type
                const Text('Task Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: taskType,
                  decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.list_alt_rounded, size: 18)),
                  items: const [
                    DropdownMenuItem(value: 'REGULAR_CLEAN',  child: Text('Regular Clean')),
                    DropdownMenuItem(value: 'CHECKOUT_CLEAN', child: Text('Checkout Clean')),
                    DropdownMenuItem(value: 'DEEP_CLEAN',     child: Text('Deep Clean')),
                    DropdownMenuItem(value: 'LINEN_CHANGE',   child: Text('Linen Change')),
                    DropdownMenuItem(value: 'TURNDOWN',       child: Text('Turndown')),
                    DropdownMenuItem(value: 'INSPECTION',     child: Text('Inspection')),
                  ],
                  onChanged: (v) => setModal(() => taskType = v!),
                ),
                const SizedBox(height: 14),

                // Priority
                const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Row(children: [
                  for (final p in ['HIGH', 'NORMAL', 'LOW']) ...[
                    Expanded(child: GestureDetector(
                      onTap: () => setModal(() => priority = p),
                      child: Container(
                        margin: EdgeInsets.only(right: p != 'LOW' ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: priority == p
                              ? (p == 'HIGH' ? const Color(0xFFE53935) : p == 'NORMAL' ? const Color(0xFF1565C0) : Colors.grey)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: priority == p
                              ? (p == 'HIGH' ? const Color(0xFFE53935) : p == 'NORMAL' ? const Color(0xFF1565C0) : Colors.grey)
                              : Colors.grey.shade300),
                        ),
                        child: Text(p, textAlign: TextAlign.center,
                            style: TextStyle(
                              color: priority == p ? Colors.white : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold, fontSize: 13,
                            )),
                      ),
                    )),
                  ],
                ]),
                const SizedBox(height: 14),

                // Assigned To
                const Text('Assign To', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: assignCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Savita K.', prefixIcon: Icon(Icons.person_outline, size: 18), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),

                // Notes
                const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Special instructions...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (roomCtrl.text.trim().isEmpty) return;
                      try {
                        final client = ref.read(supabaseClientProvider);
                        await client.from('housekeeping_tasks').insert({
                          'room_number': roomCtrl.text.trim(),
                          'task_type':   taskType,
                          'priority':    priority,
                          'status':      'PENDING',
                          'assigned_to': assignCtrl.text.trim().isEmpty ? null : assignCtrl.text.trim(),
                          'notes':       notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          'created_at':  DateTime.now().toIso8601String(),
                          'updated_at':  DateTime.now().toIso8601String(),
                        });
                        ref.invalidate(housekeepingTasksProvider);
                      } catch (_) {}
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task assigned to housekeeping!'), backgroundColor: Color(0xFF6A1B9A)),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Assign Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

class _HKStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HKStat(this.label, this.value, this.color);
  @override Widget build(_) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9), textAlign: TextAlign.center),
  ]));
}

class _HKDiv extends StatelessWidget {
  @override Widget build(_) => Container(width: 1, height: 28, color: Colors.white24);
}

class _HKTaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final WidgetRef ref;
  const _HKTaskRow({required this.task, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status   = task['status'] as String? ?? 'PENDING';
    final type     = (task['task_type'] as String? ?? 'REGULAR_CLEAN').replaceAll('_', ' ');
    final room     = task['room_number'] as String? ?? '';
    final assigned = task['assigned_to'] as String? ?? 'Unassigned';
    final priority = task['priority'] as String? ?? 'NORMAL';

    final statusColor = status == 'IN_PROGRESS' ? const Color(0xFF1565C0) : const Color(0xFFFFB300);
    final priorityColor = priority == 'HIGH' ? const Color(0xFFE53935) : priority == 'LOW' ? Colors.grey : const Color(0xFF1565C0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(room, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6A1B9A)))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '').join(' '),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(assigned, style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(status.replaceAll('_', ' '), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Container(width: 7, height: 7, decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle)),
        ]),
      ]),
    );
  }
}

// ── Dashboard Skeleton ─────────────────────────────────────────────────────────

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
